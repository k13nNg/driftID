#!/usr/bin/env bash
# ===========================================================================
# push-to-hf.sh — deploy DriftID to a Hugging Face Docker Space.
#
# Why a mirror instead of `git push` of this repo: HF rejects files >10 MB
# without LFS, and this repo tracks training tensors/manifests (data/test,
# data/json, ...) that the SERVING image never needs. So we sync only the
# deployment files into a clean checkout of the Space repo and push that.
# The mirror lives at ./.hf-space (git-ignored) and is reused across runs.
#
# Usage:
#   deploy/push-to-hf.sh <space-git-url>
#   deploy/push-to-hf.sh https://huggingface.co/spaces/<user>/driftid
#
# Auth:
#   - If you ran `huggingface-cli login` (the HF CLI), git credentials are already
#     cached and the push below just works — no prompt.
#   - Otherwise git prompts: Username = <HF username>, Password = a WRITE token
#     (https://huggingface.co/settings/tokens). Or embed it in the URL:
#       deploy/push-to-hf.sh https://<user>:<hf_token>@huggingface.co/spaces/<user>/driftid
# ===========================================================================
set -euo pipefail

SPACE_URL="${1:?usage: deploy/push-to-hf.sh <space-git-url>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIRROR="${REPO_ROOT}/.hf-space"

command -v rsync >/dev/null 2>&1 || { echo "error: rsync is required" >&2; exit 1; }

# Clone the Space once; reuse it (and its remote/credentials) on later runs.
if [ ! -d "$MIRROR/.git" ]; then
  echo "==> cloning Space into .hf-space"
  git clone "$SPACE_URL" "$MIRROR"
else
  echo "==> reusing existing .hf-space clone"
  git -C "$MIRROR" remote set-url origin "$SPACE_URL"
fi

echo "==> syncing deployment files into the mirror"
# Wipe everything tracked except the .git dir, then re-copy from source so the
# mirror is an exact reflection of the current deployment set (no stale files).
find "$MIRROR" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

# Top-level files HF needs.
cp "$REPO_ROOT/Dockerfile"      "$MIRROR/"
cp "$REPO_ROOT/README.md"       "$MIRROR/"
cp "$REPO_ROOT/.dockerignore"   "$MIRROR/"

# Python serving code + the small model artifacts (NOT the training data).
mkdir -p "$MIRROR/deploy" "$MIRROR/data"
cp "$REPO_ROOT/deploy/requirements.txt" "$MIRROR/deploy/"
rsync -a --exclude '__pycache__/' --exclude '*.pyc' "$REPO_ROOT/src/" "$MIRROR/src/"
cp -R "$REPO_ROOT/data/artifacts" "$MIRROR/data/artifacts"

# Flutter UI SOURCE only — the image rebuilds the web bundle, so skip build
# outputs, dart tooling, and the Node/Playwright test scaffolding.
rsync -a \
  --exclude 'build/' \
  --exclude '.dart_tool/' \
  --exclude 'node_modules/' \
  --exclude 'test-results/' \
  --exclude 'playwright-report/' \
  --exclude 'blob-report/' \
  --exclude 'playwright/.cache/' \
  "$REPO_ROOT/ui/" "$MIRROR/ui/"

echo "==> committing + pushing"
cd "$MIRROR"
git add -A
if git diff --cached --quiet; then
  echo "nothing changed since the last deploy — skipping push"
  exit 0
fi
git commit -m "Deploy DriftID ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
# HF Spaces default branch is main.
git push origin HEAD:main

echo "==> done. Watch the build at the Space's 'Logs' tab."
