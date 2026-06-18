# ============================================================================
# Single-container image for hosting DriftID on a Hugging Face Docker Space.
# One process (uvicorn/FastAPI) serves BOTH the Flutter Web UI and the inference
# API on port 7860 (the port HF Spaces expects).
#
#   stage 1 (flutter-build)  build the Flutter web bundle with a relative API
#                            base URL, so the UI calls /predict on its own origin
#   stage 2 (runtime)        slim CPU Python image: FastAPI + the web bundle +
#                            model artifacts; backbone pre-cached at build time
#
# Local test:
#   docker build -t driftid-hf .
#   docker run --rm -p 7860:7860 driftid-hf   # open http://localhost:7860
# ============================================================================

# ---------------------------------------------------------------------------
# stage 1: build the Flutter web bundle
# `stable` tracks the current Flutter stable (matches the dev container, which
# uses Flutter stable from git). pubspec's SDK lower bound is kept <= this
# image's Dart version so `pub get` resolves.
# ---------------------------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-build

WORKDIR /app/ui

# Resolve deps first (cached until pubspec changes), then copy the rest of the UI.
COPY ui/pubspec.yaml ui/pubspec.lock ./
RUN flutter pub get

COPY ui/ ./

# Empty API_BASE_URL => the client issues same-origin relative requests
# (/predict, /predict-url), which the runtime server below answers.
RUN flutter build web --release --dart-define=API_BASE_URL=

# ---------------------------------------------------------------------------
# stage 2: runtime — FastAPI serving the API + the built web bundle
# ---------------------------------------------------------------------------
FROM python:3.10-slim AS runtime

# libgomp1: OpenMP runtime PyTorch needs on CPU.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# HF Spaces run the container as a non-root user with id 1000.
RUN useradd -m -u 1000 user
USER user

ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

WORKDIR $HOME/app

# Python deps first so the layer caches until requirements change.
COPY --chown=user deploy/requirements.txt ./deploy/requirements.txt
RUN pip install --no-cache-dir --user -r deploy/requirements.txt

# App code + model artifacts. PYTHONPATH=app so `src...` imports resolve and
# Predictor's ROOT (server.py -> parents[2]) lands on $HOME/app.
ENV PYTHONPATH=$HOME/app
COPY --chown=user src/ ./src/
COPY --chown=user data/artifacts/ ./data/artifacts/

# Built Flutter bundle from stage 1; WEB_DIR tells server.py where to serve it.
ENV WEB_DIR=$HOME/app/web
COPY --chown=user --from=flutter-build /app/ui/build/web ./web

# Pre-download the DINOv3 backbone into the HF cache so the first request after
# boot doesn't wait on a multi-hundred-MB download. Non-fatal: falls back to a
# runtime download if the build host can't reach the hub.
ENV HF_HOME=$HOME/.cache/huggingface
RUN python -c "import timm; timm.create_model('vit_base_patch16_dinov3', pretrained=True, num_classes=0)" \
    || echo "[build] WARN: backbone pre-warm failed; will download on first request"

EXPOSE 7860
CMD ["uvicorn", "src.api.server:app", "--host", "0.0.0.0", "--port", "7860"]
