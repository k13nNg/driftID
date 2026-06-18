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

### 1. Serve the Flutter bundle from FastAPI
- [ ] Add static serving to the FastAPI app so the built web bundle is served at `/` with a SPA
      fallback to `index.html`, **without shadowing** `/health`, `/predict`, `/predict-url`.
      - Mount a catch-all `StaticFiles(directory=WEB_DIR, html=True)` **after** the API routes, or add
        an explicit fallback route; resolve `WEB_DIR` from an env var (default `/app/web`) so local dev
        still works.
      - Make it a **no-op when the bundle is absent** (local API-only runs shouldn't crash).
- [ ] Keep `host=0.0.0.0`; allow the port to come from `PORT`/`API_PORT` (default 7860 in the image).

### 2. Runtime dependency manifest
- [ ] Add `deploy/requirements.txt` (or repo-root) pinning the inference subset:
      `torch` (CPU wheel), `timm==1.0.27`, `fastapi`, `uvicorn[standard]`, `python-multipart`,
      `pillow`, `requests`, `pydantic`.

### 3. Single multi-stage Dockerfile (repo root `Dockerfile`)
- [ ] **Stage 1 (flutter-build)**: from a Flutter stable image; `COPY ui/`; `flutter pub get`;
      `flutter build web --release --dart-define=API_BASE_URL=`.
- [ ] **Stage 2 (runtime)**: from `python:3.10-slim`; install requirements; `COPY src/ data/artifacts/`;
      `COPY --from=flutter-build` the web bundle to `/app/web`; set `PYTHONPATH=/app`.
- [ ] Create a non-root user (HF runs as UID 1000); set `HF_HOME`/caches to a writable, owned dir.
- [ ] Pre-warm: `python -c "import timm; timm.create_model('vit_base_patch16_dinov3', pretrained=True, num_classes=0)"`
      (non-fatal if it fails → falls back to runtime download).
- [ ] `EXPOSE 7860`; `CMD ["uvicorn", "src.api.server:app", "--host", "0.0.0.0", "--port", "7860"]`.

### 4. HF Space metadata
- [ ] Add the HF front-matter block to a README the Space reads (title, emoji, `colorFrom/To`,
      `sdk: docker`, `app_port: 7860`, `pinned: false`). Decide whether to reuse the repo `README.md`
      or ship a Space-specific one.

### 5. Build-context hygiene
- [ ] Extend `.dockerignore` so the Space build context excludes `bookkeeping/`, `data/json/`,
      `data/train/`, `data/test/`, `ui/test-results/`, `ui/node_modules/`, demos, etc. — but **keep**
      `data/artifacts/`, `src/`, `ui/` source. (Shared with the devcontainer build — verify it doesn't
      break that.)

### 6. Local verification before pushing
- [ ] `docker build -t driftid-hf .` then `docker run -p 7860:7860 driftid-hf`; open
      `http://localhost:7860`, confirm UI loads, `/health` is ok, and a `/predict` upload + a
      `/predict-url` both return predictions.

### 7. Deploy to the Space
- [ ] Create the Space (Docker SDK) on HF.
- [ ] Add the Space as a git remote and push (or use `huggingface_hub` upload). Watch the build logs;
      confirm the running Space serves UI + predictions.

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
