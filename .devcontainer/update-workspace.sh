#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# update-workspace.sh — bring the per-task workspace up to date with main.
#
# Runs on every container start (invoked by orchestrator-entrypoint.sh, after
# the volume has been seeded). It `cd`s into the workspace and fast-forwards
# `main` so a freshly-started container always reflects the latest upstream
# before any work (or agent dispatch) begins. Safe to run repeatedly.
#
# Seeding an empty volume is the entrypoint's job; this script assumes a repo
# already exists at $WORK.
# ---------------------------------------------------------------------------
set -euo pipefail

WORK="${WORK:-/workspaces/driftID}"
REPO_URL="${REPO_URL:-https://github.com/k13nNg/driftID.git}"

log() { echo "[update-workspace] $*"; }

if [ ! -d "$WORK/.git" ]; then
  log "WARN: no git repo at $WORK; nothing to update"
  exit 0
fi

cd "$WORK"
git remote set-url origin "$REPO_URL"
log "fetching origin"
git fetch --prune origin
git switch main 2>/dev/null || git checkout -B main origin/main
git pull --ff-only origin main || log "WARN: could not fast-forward main (local commits?); leaving as-is"

# Cheap incremental warm build so the first agent/editor action is fast.
if [ -f ui/pubspec.yaml ]; then
  ( cd ui && flutter pub get ) || log "WARN: flutter pub get failed"
fi

log "up to date on $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"
