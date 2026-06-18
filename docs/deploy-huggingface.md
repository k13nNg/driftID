# Deploy DriftID to Hugging Face Spaces (single container)

DriftID ships as **one Docker image** that serves both the Flutter web UI and the
FastAPI inference API from the same origin on port `7860`. This is the format a
[Hugging Face **Docker** Space](https://huggingface.co/docs/hub/spaces-sdks-docker)
expects, so deploying is "push the repo, let the Space build the `Dockerfile`".

## How the single container works

```
┌────────────────────── one container (port 7860) ──────────────────────┐
│  uvicorn → src.api.server:app                                          │
│    • POST /predict, POST /predict-url, GET /health   (FastAPI routes)  │
│    • GET  /*  → static Flutter web bundle (StaticFiles mount at "/")   │
└────────────────────────────────────────────────────────────────────────┘
```

- The Flutter app is built with `--dart-define=API_BASE_URL=` (empty), so the
  frontend calls the API with **relative** URLs (`/predict`) against the same
  origin — no second port, no CORS.
- `src/api/server.py` mounts the built bundle (`STATIC_DIR`, default
  `ui/build/web`) at `/` only when that directory exists. Locally (split dev
  setup, no build) the mount is skipped, so `flutter run` on :8080 still works.
- The DINOv3 backbone is pre-downloaded during the image build; the classifier
  head (`data/artifacts/linear_classifier.pt`) and labels (`classes.json`) are
  copied from the repo.

## Build / run locally first

```bash
docker build -t driftid .
docker run --rm -p 7860:7860 driftid
# open http://localhost:7860
```

The first build is slow (Flutter web build + CPU PyTorch + backbone download).

## Deploy

### Option A — create the Space in the browser, then push (recommended)

1. Create a Space: https://huggingface.co/new-space
   - **SDK:** Docker → *Blank*
   - **Hardware:** CPU basic is enough (inference is CPU-only).
2. Add the Space as a git remote and push. A Space is a normal git repo:

   ```bash
   # one-time: a write token from https://huggingface.co/settings/tokens
   git remote add space https://<hf-username>:<hf-token>@huggingface.co/spaces/<hf-username>/driftID
   git push space HEAD:main
   ```

   The Space builds the root `Dockerfile` automatically and boots on port `7860`.

### Option B — Hugging Face CLI

```bash
pip install -U "huggingface_hub[cli]"
huggingface-cli login
huggingface-cli repo create driftID --type space --space_sdk docker
git remote add space https://huggingface.co/spaces/<hf-username>/driftID
git push space HEAD:main
```

> The `README.md` YAML frontmatter (`sdk: docker`, `app_port: 7860`) tells the
> Space how to build and which port to expose. Keep it at the very top of the file.

## Notes & gotchas

- **Large files:** the Docker build context is trimmed by `.dockerignore`
  (no `data/json`, `ui/build`, `ui/node_modules`, etc.). The runtime artifacts
  (`linear_classifier.pt`, `classes.json`) are small and committed — no Git LFS
  needed.
- **Cold start:** the model loads on first request via FastAPI's lifespan; the
  backbone is baked into the image so this is download-free but still takes a few
  seconds on CPU.
- **Port:** Spaces route to `app_port` (7860). The `Dockerfile` `CMD` binds
  uvicorn to `7860`; `src.api.server` also honors `$PORT`/`$API_PORT` when run
  directly.
- **Private repo:** if this repo is private, use a token in the push URL (Option
  A) or `huggingface-cli login` (Option B).
