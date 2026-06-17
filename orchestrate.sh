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
#   ./orchestrate.sh build-sprint <S###> [ref] [--push]   build the sprint seed
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

cmd_build_sprint() {
  need docker; need git
  local sprint="${1:-}"; [ -n "$sprint" ] || die "usage: build-sprint <S###> [ref] [--push]"
  shift
  local ref="main" push=0
  for a in "$@"; do
    case "$a" in
      --push) push=1 ;;
      *) ref="$a" ;;
    esac
  done
  GH_TOKEN="$(resolve_token)"; export GH_TOKEN
  local local_tag="driftid-sprint:$sprint"
  local reg="$REGISTRY/$IMAGE_OWNER/driftid-sprint:$sprint"
  DOCKER_BUILDKIT=1 docker build \
    --target sprint-base \
    --build-arg SPRINT_REF="$ref" \
    --build-arg REPO_URL="$REPO_URL" \
    --secret id=gh_token,env=GH_TOKEN \
    -t "$local_tag" \
    -f "$DOCKERFILE" "$CONTEXT"
  docker tag "$local_tag" "$reg"
  echo "built $local_tag (ref=$ref) -> $reg"
  if [ "$push" -eq 1 ]; then
    docker push "$reg"
  else
    echo "push with: docker push $reg"
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
