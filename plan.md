# Plan — Host DriftID on Hugging Face (single container)

Serve the whole app — Flutter Web frontend **and** FastAPI inference backend — from **one
container** on a Hugging Face **Docker Space**, listening on the HF-required port `7860`.

## Goal

A public HF Space where a visitor opens the URL, sees the DriftID UI, uploads (or links) a car
image, and gets top-k predictions — all served by a single process, same origin, no separate API
host.

## Why one container works here

- The Flutter client (`ui/lib/services/api_client.dart`) builds request URLs as `"$baseUrl/predict"`.
  With `--dart-define=API_BASE_URL=` (empty) the calls become **relative** (`/predict`,
  `/predict-url`), so they hit whatever host served the page.
- So if FastAPI serves the built Flutter bundle as static files at `/` **and** keeps its API routes,
  the browser talks to a single origin — no CORS, no second service, no reverse proxy.

## Current-state facts (grounding)

- **API** (`src/api/server.py`): `GET /health`, `POST /predict` (multipart `file`), `POST /predict-url`
  (JSON `{url, k}`). `Predictor` is constructed once at startup via the lifespan hook.
- **Inference deps only**: `torch`, `timm`, `pillow`, `requests`, `fastapi`, `uvicorn`,
  `python-multipart`, `pydantic`. **Not needed at runtime**: `faiss`, `numpy`(directly),
  `scikit-learn`, `scipy` — those are training-only (`src/main.py`).
- **Model assets in git**: `data/artifacts/linear_classifier.pt` (~592 KB) + `data/artifacts/classes.json`.
- **Backbone**: `vit_base_patch16_dinov3` is downloaded from the HF Hub by `timm` at `Predictor`
  init (the slow part of cold start).
- **Port**: `server.py` binds `API_PORT` (default 8000). HF Spaces expects the app on `7860`.
- **Frontend**: Flutter Web (`ui/`), no server-side routing; nav is an in-memory `IndexedStack`.

## Target architecture

```
                    ┌────────────────────────── one container (port 7860) ──────────────────────────┐
browser ──HTTP──▶   │  uvicorn → FastAPI                                                             │
                    │    GET  /                  → ui/build/web/index.html (Flutter)                 │
                    │    GET  /<assets...>       → StaticFiles(ui/build/web)                          │
                    │    GET  /health            → API                                               │
                    │    POST /predict           → API (Predictor)                                   │
                    │    POST /predict-url        → API (Predictor)                                  │
                    │    *  (SPA fallback)        → index.html                                        │
                    └────────────────────────────────────────────────────────────────────────────────┘
```

Single multi-stage `Dockerfile` at repo root:

```
stage 1  flutter-build   (flutter SDK image)
           flutter pub get
           flutter build web --release --dart-define=API_BASE_URL=
           → /ui/build/web

stage 2  runtime         (python:3.10-slim)
           pip install CPU torch + timm + fastapi + uvicorn + python-multipart + pillow + requests + pydantic
           COPY src/  data/artifacts/  (from repo)
           COPY --from=flutter-build  ui/build/web → /app/web
           pre-cache DINOv3 backbone into $HF_HOME (bake the download)
           CMD uvicorn on 0.0.0.0:7860
```

## Decisions (proposed)

- **Same-origin static serving** over a second container/proxy — simplest "one container" answer.
- **CPU-only torch** (`--index-url https://download.pytorch.org/whl/cpu`) — HF free tier is CPU; keeps
  the image small.
- **Slim runtime image** with a hand-written `requirements.txt` (inference subset), *not* the full
  conda `environment.yml` (which drags in faiss/sklearn/scipy we don't need to serve).
- **Bake the backbone** at build time so the first request isn't a multi-hundred-MB download.
- **New root `Dockerfile`** dedicated to the Space (the existing `.devcontainer/Dockerfile` stays the
  dev/orchestrator image — untouched).
- **Deploy via HF git remote**: push this repo (trimmed by `.dockerignore`) to the Space; HF builds the
  root `Dockerfile`.

## Action items

### 1. Serve the Flutter bundle from FastAPI — DONE
- [x] `src/api/server.py` mounts `StaticFiles(WEB_DIR, html=True)` at `/` **after** the API routes, so
      `/health`, `/predict`, `/predict-url` still win and `/` serves the Flutter `index.html`.
- [x] `WEB_DIR` comes from env (default `ROOT/ui/build/web`); the mount is a **no-op when absent**, so
      local API-only runs are unaffected.

### 2. Runtime dependency manifest — DONE
- [x] `deploy/requirements.txt`: CPU `torch`/`torchvision` (`+cpu` from the PyTorch CPU index),
      `timm==1.0.27`, `fastapi`, `uvicorn[standard]`, `python-multipart`, `pillow`, `requests`,
      `pydantic`. Deliberately excludes faiss/sklearn/scipy (training-only).

### 3. Single multi-stage Dockerfile (repo root `Dockerfile`) — DONE
- [x] **Stage 1 (flutter-build)**: `ghcr.io/cirruslabs/flutter:stable`; `flutter pub get` →
      `flutter build web --release --dart-define=API_BASE_URL=`.
- [x] **Stage 2 (runtime)**: `python:3.10-slim` + `libgomp1`; non-root `user` (UID 1000); pip install
      requirements; `COPY src/ data/artifacts/` + the web bundle to `$HOME/app/web`; `PYTHONPATH=$HOME/app`.
- [x] `HF_HOME` set to a writable owned dir; backbone pre-warm baked (non-fatal on failure).
- [x] `EXPOSE 7860`; `CMD uvicorn src.api.server:app --host 0.0.0.0 --port 7860`.

### 4. HF Space metadata — DONE
- [x] YAML front-matter added to repo-root `README.md` (`sdk: docker`, `app_port: 7860`, title/emoji/
      colors). Reused the existing README (HF shows it as the Space card).

### 5. Build-context hygiene — DONE
- [x] `.dockerignore` excludes `bookkeeping/`, `docs/`, `data/json|train|test`, `features`,
      `ui/build|node_modules|test-results|...`, demos — keeps `data/artifacts/`, `src/`, `ui/` source.

### 6. Deploy tooling — DONE
- [x] `deploy/push-to-hf.sh` syncs only the deployment files into a clean mirror of the Space repo
      (`./.hf-space`, git-ignored) and pushes — avoids HF's >10 MB/LFS limits and this repo's large
      training tensors. (See **Deploy** below.)

### 7. Local verification before pushing — DONE
- [x] Built `--platform linux/amd64` (matches HF) and ran on `:7860`: `/health` ok, `/` serves the
      Flutter UI, `flutter_bootstrap.js` returns 200, and `POST /predict` on the sample image returns
      predictions (audi_a7, 0.99). Fixes found en route: torch `+cpu` pin (2.2.2+cpu for amd64),
      Flutter `:stable` + pubspec SDK lower bound `^3.12.0`, and `numpy<2` (torch 2.2.2 vs NumPy 2).

### 8. Deploy to the Space — TODO (user action)
- [ ] Run `deploy/push-to-hf.sh <space-git-url>`; authenticate with HF username + WRITE token.
- [ ] Watch the Space **Logs** tab for the build; confirm it serves UI + predictions.

## Deploy (Option B — plain git push, via the mirror script)

```bash
# from the repo root, with your Space already created (Docker SDK):
deploy/push-to-hf.sh https://huggingface.co/spaces/<user>/driftid
# git prompts: Username = <HF username>, Password = a HF WRITE token
```

The script clones the Space to `./.hf-space` (reused on later runs), copies in `Dockerfile`,
`README.md`, `.dockerignore`, `deploy/requirements.txt`, `src/`, `data/artifacts/`, and the `ui/`
source (no build outputs), then commits and pushes to `main`. HF rebuilds the image on each push.

## Risks / open questions

- [ ] **DINOv3 license/gating**: confirm `vit_base_patch16_dinov3` pulls without HF auth in the Space
      build. If it's gated, we must add an `HF_TOKEN` Space secret and accept the model license.
- [ ] **Cold start / RAM**: ViT-B on CPU in the free tier (2 vCPU / 16 GB) — verify inference latency is
      acceptable for a demo; the lifespan load means the first request after boot waits for model init.
- [ ] **Image size**: CPU torch + timm + baked backbone — confirm it stays within Space build limits.
- [ ] **Repo privacy**: pushing to a *public* Space publishes the pushed files. Confirm what we want
      public, or make the Space private.
- [ ] **README ownership**: reuse `README.md` (add front-matter) vs. a dedicated Space README — pick one.

## Out of scope (for now)
- GPU inference / paid HF hardware.
- Persisting prediction history server-side (it's browser-local in the UI today).
- Retraining or shipping the training pipeline (`faiss`, dataloaders) into the serving image.
- Any change to the dev/orchestrator image (`.devcontainer/Dockerfile`, `orchestrate.sh`).
