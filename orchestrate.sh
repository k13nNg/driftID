#!/usr/bin/env bash
# ===========================================================================
# orchestrate.sh — host-side driver for parallel, container-per-task DriftID
# development (run mode B in plan.md).
#
# Runs on the HOST (Docker Desktop), not inside the dev container. Each T###
# task gets its own container from driftid-sprint:S### with:
#   * NO host source mount  — source lives on a per-task named volume
#   * NO published ports     — reach the app via "Attach to Running Container"
#   * GH_TOKEN injected at runtime for private fetch/push
#
# Usage:
#   ./orchestrate.sh up    <T###>            start a task container
#   ./orchestrate.sh down  <T###> [--force]  stop+remove container and volume
#   ./orchestrate.sh ls                      list task containers
#   ./orchestrate.sh attach <T###>           open a shell (and print attach hint)
#   ./orchestrate.sh logs  <T###>            follow warm-start logs
#   ./orchestrate.sh build-dev    [--push]   build (item 1) the dev image
#   ./orchestrate.sh build-sprint <S###> <commit-sha> [--push] [--no-cache]   build the sprint seed
#       BOTH the sprint name and the commit/ref are required (no default). The ref
#       is resolved to a SHA and the image is tagged BOTH :S### (moving) and
#       :S###-<sha> (immutable snapshot). Re-run to reset a seed; --no-cache forces
#       a full reclone+rebuild.
#
# Config (env overrides; defaults shown):
#   REGISTRY=ghcr.io  IMAGE_OWNER=raywang999  SPRINT=S002
#   REPO_URL=https://github.com/k13nNg/driftID.git
#   IMAGE=driftid-sprint:$SPRINT          image used by `up`
#   API_PORT=8000  WEB_PORT=8080          constant in-container ports
#   GH_TOKEN=<token>                      else falls back to `gh auth token`
# ===========================================================================
set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io}"
# GHCR namespace to push to. Must be a GitHub account you can write packages to
# (NOT a Docker Hub handle). CI (.github/workflows/images.yml) derives its own
# from the repo owner instead.
IMAGE_OWNER="${IMAGE_OWNER:-raywang999}"
SPRINT="${SPRINT:-S002}"
REPO_URL="${REPO_URL:-https://github.com/k13nNg/driftID.git}"
IMAGE="${IMAGE:-driftid-sprint:${SPRINT}}"
API_PORT="${API_PORT:-8000}"
WEB_PORT="${WEB_PORT:-8080}"
WORK_IN_CONTAINER="/workspaces/driftID"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${SCRIPT_DIR}/.devcontainer/Dockerfile"
CONTEXT="${SCRIPT_DIR}"

die()  { echo "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found on PATH"; }

# Normalize T5 / t005 / 5 -> T005
norm_task() {
  local t="${1:-}"; [ -n "$t" ] || die "missing <T###>"
  t="${t#[Tt]}"
  [[ "$t" =~ ^[0-9]+$ ]] || die "invalid task id '$1' (expected like T005)"
  printf 'T%03d' "$((10#$t))"
}
cname() { echo "driftid-$1"; }   # container name == volume name
vname() { echo "driftid-$1"; }

resolve_token() {
  if [ -n "${GH_TOKEN:-}" ]; then echo "$GH_TOKEN"; return 0; fi
  need gh
  gh auth token 2>/dev/null || die "no GH_TOKEN set and 'gh auth token' failed; export GH_TOKEN"
}

container_exists() { docker ps -a --format '{{.Names}}' | grep -qx "$1"; }
container_running() { docker ps --format '{{.Names}}' | grep -qx "$1"; }

# Cursor's "Attach to Running Container" decides which folder to open from a
# host-side per-container "attached configuration file" (anysphere.remote-containers'
# nameConfigs/<container>.json). WORKDIR and the image's devcontainer.metadata label
# do NOT drive this; without the file the attach lands in the container home
# (/home/vscode). We write/remove that file on up/down so attach opens the repo.
attach_config_file() {
  local container="$1" base
  case "$(uname -s)" in
    Darwin) base="$HOME/Library/Application Support/Cursor/User/globalStorage" ;;
    *)      base="${XDG_CONFIG_HOME:-$HOME/.config}/Cursor/User/globalStorage" ;;
  esac
  # Container names here are [A-Za-z0-9-] only, so encodeURIComponent is identity.
  echo "$base/anysphere.remote-containers/nameConfigs/${container}.json"
}

write_attach_config() {
  local container="$1" f; f="$(attach_config_file "$container")"
  mkdir -p "$(dirname "$f")" 2>/dev/null || { echo "  note: could not create attach config dir; attach may open container home" >&2; return 0; }
  printf '{\n  "workspaceFolder": "%s"\n}\n' "$WORK_IN_CONTAINER" > "$f" 2>/dev/null \
    && echo "  wrote attach config: opens $WORK_IN_CONTAINER on 'Attach to Running Container'" \
    || echo "  note: could not write attach config ($f); attach may open container home" >&2
}

remove_attach_config() {
  local container="$1" f; f="$(attach_config_file "$container")"
  rm -f "$f" 2>/dev/null || true
}

# --- commands --------------------------------------------------------------

cmd_up() {
  need docker
  local task c v tok
  task="$(norm_task "${1:-}")"; c="$(cname "$task")"; v="$(vname "$task")"
  container_exists "$c" && die "$c already exists — use 'down $task' first, or 'attach $task'"
  tok="$(resolve_token)"

  docker volume create "$v" >/dev/null
  docker run -d --name "$c" \
    -v "$v:$WORK_IN_CONTAINER" \
    -e GH_TOKEN="$tok" \
    -e TASK_ID="$task" \
    -e REPO_URL="$REPO_URL" \
    -e API_PORT="$API_PORT" \
    -e WEB_PORT="$WEB_PORT" \
    "$IMAGE" >/dev/null

  write_attach_config "$c"

  echo "started $c  (image=$IMAGE  volume=$v)"
  echo "  warm-start log : ./orchestrate.sh logs $task"
  echo "  attach (Cursor): Cmd+Shift+P -> Dev Containers: Attach to Running Container -> $c"
  echo "  attach (shell) : ./orchestrate.sh attach $task"
}

cmd_down() {
  need docker
  local task force=0
  task="$(norm_task "${1:-}")"; shift || true
  [ "${1:-}" = "--force" ] && force=1
  local c v; c="$(cname "$task")"; v="$(vname "$task")"
  container_exists "$c" || die "$c does not exist"

  if [ "$force" -ne 1 ] && container_running "$c"; then
    local dirty unpushed
    dirty="$(docker exec "$c" git -C "$WORK_IN_CONTAINER" status --porcelain 2>/dev/null || true)"
    # commits on any local branch not present on any remote == unpushed work
    unpushed="$(docker exec "$c" git -C "$WORK_IN_CONTAINER" log --branches --not --remotes --oneline 2>/dev/null || true)"
    if [ -n "$dirty" ] || [ -n "$unpushed" ]; then
      echo "refusing to destroy $task — unsynced work in the volume:" >&2
      [ -n "$dirty" ]    && { echo "  uncommitted changes:" >&2; echo "$dirty"    | sed 's/^/    /' >&2; }
      [ -n "$unpushed" ] && { echo "  unpushed commits:"    >&2; echo "$unpushed" | sed 's/^/    /' >&2; }
      echo "push your work (git push), or re-run: ./orchestrate.sh down $task --force" >&2
      exit 1
    fi
  fi

  docker rm -f "$c" >/dev/null 2>&1 || true
  docker volume rm "$v" >/dev/null 2>&1 || true
  remove_attach_config "$c"
  echo "removed container $c and volume $v"
}

cmd_ls() {
  need docker
  echo "in-container ports are constant: API=$API_PORT WEB=$WEB_PORT (reach via Attach to Running Container)"
  docker ps -a --filter 'name=driftid-T' \
    --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
}

cmd_attach() {
  need docker
  local task c; task="$(norm_task "${1:-}")"; c="$(cname "$task")"
  container_running "$c" || die "$c is not running (try './orchestrate.sh up $task')"
  echo "Cursor/VS Code: Attach to Running Container -> $c"
  echo "opening a shell (Ctrl-D to exit) ..."
  exec docker exec -it "$c" bash -l
}

cmd_logs() {
  need docker
  local task c; task="$(norm_task "${1:-}")"; c="$(cname "$task")"
  container_exists "$c" || die "$c does not exist"
  exec docker logs -f "$c"
}

cmd_build_dev() {
  need docker; need git
  local push=0; [ "${1:-}" = "--push" ] && push=1
  local sha; sha="$(git -C "$CONTEXT" rev-parse --short HEAD)"
  local reg="$REGISTRY/$IMAGE_OWNER/driftid-dev"
  docker build --target dev -t driftid-dev:latest -f "$DOCKERFILE" "$CONTEXT"
  docker tag driftid-dev:latest "$reg:latest"
  docker tag driftid-dev:latest "$reg:$sha"
  echo "built driftid-dev:latest -> $reg:{latest,$sha}"
  if [ "$push" -eq 1 ]; then
    docker push "$reg:latest" && docker push "$reg:$sha"
  else
    echo "push with: docker push $reg:latest && docker push $reg:$sha"
  fi
}

# Resolve a ref (branch/tag/sha; default 'main' = latest) to a concrete commit
# SHA. Pinning the build to a SHA is what makes a re-seed actually take effect:
# a moving ref like 'main' has a stable cache key, so Docker would reuse the
# stale cached seed even after main advances. A hex ref is used verbatim.
resolve_sha() {
  local ref="$1" sha=""
  if [[ "$ref" =~ ^[0-9a-fA-F]{7,40}$ ]]; then echo "$ref"; return 0; fi
  git -C "$CONTEXT" fetch --quiet --tags origin 2>/dev/null || true
  sha="$(git -C "$CONTEXT" rev-parse --verify --quiet "origin/$ref^{commit}" 2>/dev/null \
       || git -C "$CONTEXT" rev-parse --verify --quiet "$ref^{commit}" 2>/dev/null || true)"
  if [ -z "$sha" ] && [ -n "${GH_TOKEN:-}" ]; then
    # fallback: ask the remote directly (covers refs not in the local clone)
    sha="$(git ls-remote "https://x-access-token:${GH_TOKEN}@${REPO_URL#https://}" "$ref" 2>/dev/null | awk 'NR==1{print $1}')"
  fi
  [ -n "$sha" ] || die "could not resolve ref '$ref' on $REPO_URL"
  echo "$sha"
}

cmd_build_sprint() {
  need docker; need git
  local sprint="${1:-}" ref="${2:-}"
  [ -n "$sprint" ] || die "usage: build-sprint <S###> <commit-sha> [--push] [--no-cache]"
  # Both args are required and explicit — no default ref. The 2nd arg must be a
  # commit/ref, not a flag, so a forgotten SHA fails loudly instead of silently
  # baking some implicit 'main'.
  case "$ref" in
    ""|--*) die "build-sprint requires an explicit <commit-sha> (or branch/tag) as the 2nd arg" ;;
  esac
  shift 2
  local push=0 nocache=""
  for a in "$@"; do
    case "$a" in
      --push) push=1 ;;
      --no-cache) nocache="--no-cache" ;;
      *) die "unexpected argument '$a' (usage: build-sprint <S###> <commit-sha> [--push] [--no-cache])" ;;
    esac
  done
  GH_TOKEN="$(resolve_token)"; export GH_TOKEN

  local sha short
  sha="$(resolve_sha "$ref")"; short="${sha:0:12}"

  # Moving tag (latest seed for the sprint) + immutable snapshot tag. Rebuilding
  # the sprint moves :S### to the new seed but leaves any :S###-<sha> snapshots
  # intact, so an old seed is never silently lost.
  local sprint_tag="driftid-sprint:$sprint"
  local pin_tag="driftid-sprint:${sprint}-${short}"
  local reg="$REGISTRY/$IMAGE_OWNER"

  DOCKER_BUILDKIT=1 docker build $nocache \
    --target sprint-base \
    --build-arg SPRINT_REF="$sha" \
    --build-arg REPO_URL="$REPO_URL" \
    --secret id=gh_token,env=GH_TOKEN \
    -t "$sprint_tag" \
    -t "$pin_tag" \
    -f "$DOCKERFILE" "$CONTEXT"
  docker tag "$sprint_tag" "$reg/$sprint_tag"
  docker tag "$pin_tag" "$reg/$pin_tag"
  echo "built $sprint_tag + $pin_tag  (ref=$ref @ $short)"
  if [ "$push" -eq 1 ]; then
    docker push "$reg/$sprint_tag" && docker push "$reg/$pin_tag"
  else
    echo "push with: docker push $reg/$sprint_tag && docker push $reg/$pin_tag"
  fi
}

usage() {
  # Print the leading comment header (everything after the shebang up to the
  # first non-comment line), stripping the leading "# ".
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "${BASH_SOURCE[0]}"
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    up)            cmd_up "$@" ;;
    down)          cmd_down "$@" ;;
    ls|list)       cmd_ls "$@" ;;
    attach)        cmd_attach "$@" ;;
    logs)          cmd_logs "$@" ;;
    build-dev)     cmd_build_dev "$@" ;;
    build-sprint)  cmd_build_sprint "$@" ;;
    ""|-h|--help|help) usage ;;
    *) die "unknown command '$sub' (run with --help)" ;;
  esac
}

main "$@"
