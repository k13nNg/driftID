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
cd "$WORK"
git remote set-url origin "$REPO_URL"
log "fetching origin"
git fetch --prune origin
git switch main 2>/dev/null || git checkout -B main origin/main
git pull --ff-only origin main || log "WARN: could not fast-forward main (local commits?); leaving as-is"

# --- 3. cheap incremental warm build ---------------------------------------
if [ -f ui/pubspec.yaml ]; then
  ( cd ui && flutter pub get ) || log "WARN: flutter pub get failed"
fi

# --- 4. ready; hand off to the agent ---------------------------------------
log "ready on branch $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"
log "in-container ports: API=${API_PORT:-8000} WEB=${WEB_PORT:-8080} (reach via Attach to Running Container)"
if [ -n "${TASK_ID:-}" ]; then
  log "attach to this container and run the implement-task skill for ${TASK_ID}."
else
  log "no TASK_ID set; attach and run implement-task <T###> when ready."
fi

# Keep PID 1 alive so the container stays up for attach/exec.
exec sleep infinity
