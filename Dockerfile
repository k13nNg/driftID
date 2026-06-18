# syntax=docker/dockerfile:1
# ============================================================================
# Single-container deploy for Hugging Face Spaces (Docker SDK).
#
# One image serves BOTH the Flutter web UI and the FastAPI inference API from
# the same origin on port 7860:
#   stage 1 (webbuild)  builds the Flutter web app with a relative API base URL
#   stage 2 (runtime)   CPU-only PyTorch + FastAPI, serving the built web + API
#
# Build/run locally:
#   docker build -t driftid .
#   docker run --rm -p 7860:7860 driftid   # open http://localhost:7860
# ============================================================================

# ---------------------------------------------------------------------------
# stage 1: build the Flutter web bundle
# API_BASE_URL is intentionally EMPTY so the frontend calls the API with
# relative URLs (/predict, /predict-url) against whatever origin serves it.
# ---------------------------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS webbuild

WORKDIR /app/ui

# Cache deps separately from source.
COPY ui/pubspec.yaml ui/pubspec.lock ./
RUN flutter pub get

COPY ui/ ./
RUN flutter build web --release --dart-define=API_BASE_URL=

# ---------------------------------------------------------------------------
# stage 2: Python runtime
# ---------------------------------------------------------------------------
FROM python:3.10-slim AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app \
    STATIC_DIR=/app/ui/build/web \
    HF_HOME=/home/user/.cache/huggingface \
    PORT=7860

# Runtime libs needed by Pillow / torch.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Hugging Face Spaces runs containers as uid 1000 — create that user so caches
# and any runtime writes land in a writable home.
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR /app

# CPU-only PyTorch (no CUDA) keeps the image small, then the rest of the deps.
COPY --chown=user requirements.txt ./
RUN pip install --no-cache-dir --user \
        --index-url https://download.pytorch.org/whl/cpu \
        torch==2.5.1 torchvision==0.20.1 \
    && pip install --no-cache-dir --user -r requirements.txt

# Pre-download the DINOv3 backbone into the image so the first request after a
# cold boot doesn't pay the download cost. The classifier head + labels are
# copied below from the repo (they're small and version-controlled).
RUN python -c "import timm; timm.create_model('vit_base_patch16_dinov3', pretrained=True, num_classes=0)"

# Application code + the small, committed model artifacts + the built web UI.
COPY --chown=user src/ ./src/
COPY --chown=user data/artifacts/ ./data/artifacts/
COPY --from=webbuild --chown=user /app/ui/build/web ./ui/build/web

EXPOSE 7860

CMD ["uvicorn", "src.api.server:app", "--host", "0.0.0.0", "--port", "7860"]
