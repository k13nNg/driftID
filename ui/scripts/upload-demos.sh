#!/usr/bin/env bash
# ===========================================================================
# upload-demos.sh — publish Playwright demo recordings as GitHub release assets
# and print a markdown block of their URLs for the PR body.
#
# Why a release (not a comment attachment): GitHub's inline video player only
# accepts files uploaded through the web composer (the github.com/user-attachments
# CDN), and that endpoint has NO public API — `gh` can't reach it. `gh release
# upload`, by contrast, IS scriptable and gives a stable, repo-owned URL. The
# link is not an embedded player, but the file plays in-browser when opened.
#
# Pipeline:
#   1. Collect the `record` run's recordings (test-results/**/video.webm).
#   2. Convert each to .mp4 with ffmpeg when available; otherwise keep .webm
#      (ffmpeg may be absent in older container images — see .devcontainer/Dockerfile).
#   3. Ensure a per-task PRERELEASE exists (tag `demos-T###`).
#   4. Upload the assets with --clobber (idempotent: re-running replaces them).
#   5. Print a markdown block of asset URLs to paste into the PR.
#
# Usage (from inside a task/dev container, after the record run):
#   cd ui
#   npx playwright test --project=record
#   ./scripts/upload-demos.sh
#
# Env overrides (defaults shown):
#   TASK_ID=<from $TASK_ID or the current branch's T###>
#   RESULTS_DIR=test-results     where Playwright wrote video.webm
#   RELEASE_TAG=demos-<TASK_ID>  the release the assets land on
#   DRY_RUN=0                    set to 1 to transcode + print URLs but NOT
#                                create the release or upload (no repo mutation)
# ===========================================================================
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
log() { echo "[upload-demos] $*" >&2; }

command -v gh >/dev/null 2>&1 || die "'gh' not found on PATH"
gh auth status >/dev/null 2>&1 || [ -n "${GH_TOKEN:-}" ] \
  || die "gh is not authenticated and GH_TOKEN is unset"

# Run from the ui/ dir regardless of where we're invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$UI_DIR"

RESULTS_DIR="${RESULTS_DIR:-test-results}"
[ -d "$RESULTS_DIR" ] || die "no '$RESULTS_DIR' dir — run 'npx playwright test --project=record' first"

# --- resolve the task id -> release tag ------------------------------------
task="${TASK_ID:-}"
if [ -z "$task" ]; then
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  task="$(printf '%s' "$branch" | grep -oE 'T[0-9]{3}' | head -1 || true)"
fi
[ -n "$task" ] || die "could not determine task id — set TASK_ID=T### (no \$TASK_ID env and no T### in branch '${branch:-}')"
tag="${RELEASE_TAG:-demos-$task}"

nwo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
[ -n "$nwo" ] || die "could not resolve owner/repo via gh"

# --- gather + transcode the recordings -------------------------------------
# Only true demo recordings are named video.webm; Playwright trace artifacts
# under .playwright-artifacts-* are page@<hash>.webm and are intentionally skipped.
mapfile -t videos < <(find "$RESULTS_DIR" -type f -name 'video.webm' | sort)
[ "${#videos[@]}" -gt 0 ] || die "no recordings found under '$RESULTS_DIR' (did the record project run with video on?)"

have_ffmpeg=0
if command -v ffmpeg >/dev/null 2>&1; then
  have_ffmpeg=1
else
  log "WARN: ffmpeg not found — uploading .webm as-is (Safari can't play VP8 webm)."
  log "      Rebuild the dev image to bake ffmpeg in (.devcontainer/Dockerfile)."
fi

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
assets=()
labels=()

for webm in "${videos[@]}"; do
  # The parent folder is the Playwright test slug, e.g.
  # record-demo-upload-and-predict-demo -> a stable, descriptive name.
  slug="$(basename "$(dirname "$webm")")"
  base="${task}-${slug}"
  if [ "$have_ffmpeg" -eq 1 ]; then
    out="$stage/$base.mp4"
    # H.264 + yuv420p + faststart => plays in every browser and on GitHub when opened.
    ffmpeg -y -loglevel error -i "$webm" \
      -c:v libx264 -pix_fmt yuv420p -movflags +faststart -an "$out" \
      || die "ffmpeg failed converting $webm"
  else
    out="$stage/$base.webm"
    cp "$webm" "$out"
  fi
  assets+=("$out")
  # Human label: drop a leading "record " and turn hyphens into spaces.
  label="$(printf '%s' "$slug" | sed -E 's/^record-//; s/-/ /g')"
  labels+=("$label")
  log "prepared $(basename "$out")  (from $slug)"
done

# --- ensure the release, then upload ---------------------------------------
if [ "${DRY_RUN:-0}" = "1" ]; then
  log "DRY_RUN=1 — skipping release create/upload (would publish ${#assets[@]} asset(s) to '$tag')"
else
  if ! gh release view "$tag" >/dev/null 2>&1; then
    log "creating prerelease '$tag'"
    gh release create "$tag" \
      --prerelease \
      --title "Demo recordings — $task" \
      --notes "Automated Playwright demo recordings for $task. Managed by ui/scripts/upload-demos.sh."
  fi
  log "uploading ${#assets[@]} asset(s) to $tag"
  gh release upload "$tag" "${assets[@]}" --clobber
fi

# --- emit the markdown block for the PR body -------------------------------
echo
echo "### Demo recordings"
for i in "${!assets[@]}"; do
  name="$(basename "${assets[$i]}")"
  url="https://github.com/$nwo/releases/download/$tag/$name"
  echo "- [${labels[$i]}]($url)"
done
