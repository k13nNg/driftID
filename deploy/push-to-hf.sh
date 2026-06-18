#!/usr/bin/env bash
# ===========================================================================
# push-to-hf.sh — deploy DriftID to a Hugging Face Docker Space.
#
# Uses the Hugging Face CLI (`hf upload`), NOT raw `git push`:
#   - HF requires binary files (the model weights) to be stored via Xet/LFS.
#     `hf upload` handles that automatically — no git-lfs install needed.
#   - We stage ONLY the files the serving image needs (this repo tracks large
#     training tensors/manifests that the Space must not carry).
#
# Usage:
#   deploy/push-to-hf.sh <space-url-or-user/space>
#   deploy/push-to-hf.sh https://huggingface.co/spaces/Garendaxe/driftid
#   deploy/push-to-hf.sh Garendaxe/driftid
#
# Auth: run `hf auth login` once (token from https://huggingface.co/settings/tokens).
# ===========================================================================
set -euo pipefail

ARG="${1:?usage: deploy/push-to-hf.sh <space-url-or-user/space>}"

# Normalize a URL or bare id down to "<user>/<space>".
REPO_ID="${ARG#https://huggingface.co/}"
REPO_ID="${REPO_ID#http://huggingface.co/}"
REPO_ID="${REPO_ID#spaces/}"
REPO_ID="${REPO_ID%/}"
case "$REPO_ID" in
  */*) ;;
  *) echo "error: could not parse '<user>/<space>' from '$ARG'" >&2; exit 1 ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${REPO_ROOT}/.hf-space"

command -v hf    >/dev/null 2>&1 || { echo "error: HF CLI not found — pip install -U huggingface_hub" >&2; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "error: rsync is required" >&2; exit 1; }
hf auth whoami   >/dev/null 2>&1 || { echo "error: not logged in — run: hf auth login" >&2; exit 1; }

echo "==> staging deployment files in .hf-space"
rm -rf "$STAGE"
mkdir -p "$STAGE/deploy" "$STAGE/data"

# Top-level files HF needs (README carries the Space YAML config).
cp "$REPO_ROOT/Dockerfile"    "$STAGE/"
cp "$REPO_ROOT/README.md"     "$STAGE/"
cp "$REPO_ROOT/.dockerignore" "$STAGE/"

# Python serving code + the small model artifacts (NOT the training data).
cp "$REPO_ROOT/deploy/requirements.txt" "$STAGE/deploy/"
rsync -a --exclude '__pycache__/' --exclude '*.pyc' "$REPO_ROOT/src/" "$STAGE/src/"
cp -R "$REPO_ROOT/data/artifacts" "$STAGE/data/artifacts"

# Flutter UI SOURCE only — the image rebuilds the web bundle, so skip build
# outputs, dart tooling, and the Node/Playwright test scaffolding + demo fixtures.
rsync -a \
  --exclude 'build/' \
  --exclude '.dart_tool/' \
  --exclude 'node_modules/' \
  --exclude 'demos/' \
  --exclude 'test-results/' \
  --exclude 'playwright-report/' \
  --exclude 'blob-report/' \
  --exclude 'playwright/.cache/' \
  "$REPO_ROOT/ui/" "$STAGE/ui/"

echo "==> uploading to space '$REPO_ID' (binaries via Xet; --delete syncs removals)"
# `--delete '*'` makes the upload a true mirror: files on the Space that aren't
# in the staged set are removed. Binaries are committed via Xet automatically.
hf upload "$REPO_ID" "$STAGE" . \
  --repo-type=space \
  --delete "*" \
  --commit-message "Deploy DriftID ($(date -u +%Y-%m-%dT%H:%M:%SZ))"

echo "==> done. Build + logs: https://huggingface.co/spaces/$REPO_ID  (Logs tab)"
