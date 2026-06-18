#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Orchestrator-mode warm-start entrypoint (run mode B from plan.md).
#
# Runs as the container's PID 1 when a per-task container is launched from
# driftid-sprint:S###. It turns the baked SEED (/opt/seed/driftID) into a live
# workspace on the per-task named volume (/workspaces/driftID), brings it up to
# date with main, does a cheap incremental warm build, then keeps the container
# alive so an agent can "Attach to Running Container" and run implement-task.
#
# The baked seed is NEVER authoritative: we always fetch + switch main + pull on
# top of it. Auth (GH_TOKEN) is injected at runtime, never baked.
# ---------------------------------------------------------------------------
set -euo pipefail

SEED="${SEED:-/opt/seed/driftID}"
WORK="${WORK:-/workspaces/driftID}"
REPO_URL="${REPO_URL:-https://github.com/k13nNg/driftID.git}"

log() { echo "[warm-start] $*"; }

# --- git auth + identity (runtime only) ------------------------------------
git config --global --add safe.directory "$WORK" || true
git config --global user.name "${GIT_USER_NAME:-DriftID Worker}"
git config --global user.email "${GIT_USER_EMAIL:-driftid-worker@users.noreply.github.com}"

if [ -n "${GH_TOKEN:-}" ]; then
  # Use the token over HTTPS for both fetch and push (origin's SSH fetch URL is
  # not reachable from the container). Stored in a 0600 credential file, not in
  # any remote URL, so it never gets committed or baked.
  git config --global credential.helper store
  printf 'https://x-access-token:%s@github.com\n' "$GH_TOKEN" > "$HOME/.git-credentials"
  chmod 600 "$HOME/.git-credentials"
else
  log "WARN: GH_TOKEN not set; private fetch/push will fail."
fi

# --- 1. seed the volume if it's empty --------------------------------------
if [ ! -d "$WORK/.git" ]; then
  log "volume empty; seeding $WORK from $SEED (object reuse via --reference)"
  git clone --reference "$SEED" "$REPO_URL" "$WORK"
  # Copy warm, untracked build dirs the seed already produced so the first
  # build in the worker is incremental rather than cold.
  for d in ui/.dart_tool ui/build; do
    if [ -d "$SEED/$d" ] && [ ! -d "$WORK/$d" ]; then
      log "copying warm $d"
      mkdir -p "$WORK/$(dirname "$d")"
      cp -a "$SEED/$d" "$WORK/$d"
    fi
  done
else
  log "volume already initialized; skipping seed"
fi

# --- 2. bring the workspace up to date with main ---------------------------
# Delegated to a standalone start script so the "cd + fast-forward main" step
# is explicit and reusable (e.g. re-run by hand after attaching).
WORK="$WORK" REPO_URL="$REPO_URL" /usr/local/bin/update-workspace.sh

cd "$WORK"
log "ready on branch $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"
log "in-container ports: API=${API_PORT:-8000} WEB=${WEB_PORT:-8080} (reach via Attach to Running Container)"

# --- 3. dispatch the implement-task agent, or park for manual attach --------
# `up` sets DISPATCH_AGENT=1 and injects CURSOR_API_KEY; `up_classic` leaves it
# unset so the container just parks for a human to attach and drive the skill.
dispatch_agent() {
  [ "${DISPATCH_AGENT:-0}" = "1" ] || { log "classic mode: no agent dispatched."; return 1; }
  if ! command -v cursor-agent >/dev/null 2>&1; then
    log "WARN: DISPATCH_AGENT=1 but cursor-agent not found; parking for manual attach."; return 1
  fi
  if [ -z "${CURSOR_API_KEY:-}" ]; then
    log "WARN: DISPATCH_AGENT=1 but CURSOR_API_KEY not set; parking for manual attach."; return 1
  fi
  if [ -z "${TASK_ID:-}" ]; then
    log "WARN: DISPATCH_AGENT=1 but TASK_ID not set; parking for manual attach."; return 1
  fi

  local prompt
  prompt="Run the implement-task skill to implement ${TASK_ID} end-to-end: read the \
context (user stories -> sprint -> task + deps), branch off main, implement only what \
the task requires, run the task's verification commands, tick the acceptance criteria, \
move the task to done/, then commit, push, and open a pull request. Do not merge."

  local -a model_args=()
  [ -n "${AGENT_MODEL:-}" ] && model_args=(--model "$AGENT_MODEL")

  log "dispatching implement-task agent for ${TASK_ID} (model=${AGENT_MODEL:-CLI default})"
  # Headless: -p print mode, --force to apply edits/run commands, --trust to
  # skip the workspace-trust prompt. Backgrounded so the container parks for
  # attach while the agent works; its output streams to `docker logs`.
  cursor-agent -p --force --trust --workspace "$WORK" "${model_args[@]}" "$prompt" &
  log "agent dispatched (PID $!); follow it with: docker logs -f <container>"
  return 0
}

dispatch_agent || log "attach and run the implement-task skill for ${TASK_ID:-<T###>} when ready."

# Keep PID 1 alive so the container stays up for attach/exec.
exec sleep infinity
