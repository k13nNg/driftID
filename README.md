---
title: DriftID
emoji: 🚗
colorFrom: purple
colorTo: pink
sdk: docker
app_port: 7860
pinned: false
---

<!-- The YAML block above is the Hugging Face Space config (Docker SDK) and MUST
     be the first thing in this file. `app_port` must match the port uvicorn binds
     in the Dockerfile. GitHub renders it as a small metadata table; HF consumes it. -->

# 🚗 DriftID

# 🚀 Overview

This project is an _end-to-end machine learning application_ that identifies the make and model of a car from an uploaded image.

Given a user-submitted image, the system extracts visual features using a pretrained vision backbone and classifies the car into a fine-grained category (e.g., Toyota Camry 2018, BMW X5 2021).

The goal is to demonstrate a practical computer vision pipeline combining deep feature extraction, similarity search/classification, and deployment-ready inference code.

# ⚡ Quickstart

**1. Open in the dev container**

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) in VS Code / Cursor
2. Clone the repo and open it in the editor
3. Run **Dev Containers: Reopen in Container** from the command palette (the first build takes a few minutes)

**2. Start the backend API** (terminal 1):

```bash
conda activate gpu-env
uvicorn src.api.server:app --host 0.0.0.0 --port 8000 --reload
```

Wait until it logs `Application startup complete` (the first start loads the DINOv3 backbone and takes a couple of minutes).

**3. Start the frontend UI** (terminal 2):

```bash
cd ui
flutter pub get          # first run only
flutter run -d web-server --web-port 8080
```

Open [http://localhost:8080](http://localhost:8080), upload a car image, and view the top-k predictions.

> See [REST API](#-rest-api) and [Frontend (Flutter Web UI)](#-frontend-flutter-web-ui) below for more detail.

# 🛠️ Development Setup Guide

## Dev container

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) in VS Code / Cursor
2. Clone the repo and open it in the editor
3. Run **Dev Containers: Reopen in Container** from the command palette
4. The `gpu-env` conda environment is built into the container image from `.devcontainer/environment.yml` (PyTorch, faiss, etc. via conda-forge). `PYTHONPATH` points at the repo root.

The first build takes a few minutes while Docker downloads packages; later opens are fast.

Example inference:

```bash
python src/test.py
```

## Orchestrator mode (parallel tasks)

Besides the interactive dev container, the same image can run one isolated container **per `T###`
task** so multiple agents code in parallel. The host-side driver is `orchestrate.sh`:

```bash
./orchestrate.sh build-sprint S002 $(git rev-parse origin/main) --push   # per-sprint seed
./orchestrate.sh up T012        # provision + warm-start a task container
./orchestrate.sh down T012      # tear down after the PR merges
```

See **[docs/orchestrator.md](docs/orchestrator.md)** for the full guide — image layering, auth
setup, seed reset/snapshot tags, the per-task workflow, ports/persistence, CI, and troubleshooting.

## Local conda setup

1. Make sure [Miniconda](https://www.anaconda.com/docs/getting-started/miniconda/install/overview) is installed
2. Clone the repo
3. Navigate to the `root` folder of the repo
4. Run the following line of code to setup the virtual environment
   ```bash
   conda env --file env.yaml
   ```
5. Run the following line of code to activate the virtual environment
   ```bash
   conda activate gpu-env
   ```
6. You are now all setup for development! The file `test.py` in `src` contains an example of how to interact with the model

**Note:** The original dataset (`car-dataset-200`, which contains car images) is no longer needed at this stage of development, as all image features are extracted and stored in the `/train` and `/test` folders in `/data`

# 🌐 REST API

A FastAPI server (`src/api/server.py`) wraps the `Predictor` so a browser frontend can run inference over HTTP without importing Python or PyTorch. The model is loaded once at startup.

Start the server:

```bash
conda activate gpu-env
uvicorn src.api.server:app --host 0.0.0.0 --port 8000 --reload
```

Interactive API docs are available at [http://localhost:8000/docs](http://localhost:8000/docs).

> **Note:** The first startup takes a couple of minutes while the DINOv3 backbone loads. The server only accepts requests once it logs `Application startup complete`.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Liveness check → `{"status": "ok"}` |
| `POST` | `/predict?k=5` | Identify a car from an uploaded image (multipart form, field `file`) |
| `POST` | `/predict-url` | Identify a car from an image URL (JSON `{"url": ..., "k": 5}`) |

`k` sets how many predictions to return (default `5`, max `20`).

Image upload:

```bash
curl -X POST "http://localhost:8000/predict?k=5" \
  -F "file=@/path/to/car.jpg"
```

Image URL:

```bash
curl -X POST http://localhost:8000/predict-url \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/car.jpg", "k": 5}'
```

Both endpoints return the same shape:

```json
{
  "predictions": [
    {"class": "porsche_cayenne-gen_2017_2021", "confidence": 0.58},
    {"class": "landrover_rangeroversport-gen_2013_2021", "confidence": 0.27}
  ]
}
```

Errors are returned as JSON `{"detail": "..."}` (no stack traces): `400` for an invalid/unreadable image or unreachable URL, `500` for an unexpected inference failure. CORS is enabled for local frontend development.

# 🖥️ Frontend (Flutter Web UI)

The `ui/` folder contains a [Flutter](https://docs.flutter.dev/) Web app that provides an image-upload interface for running inference against the REST API. The dev container ships with the Flutter SDK and Chromium preconfigured (`CHROME_EXECUTABLE`).

The UI talks to the FastAPI backend, so **start the API first** (see [REST API](#-rest-api) above), then launch the UI in a separate terminal.

```bash
cd ui
flutter pub get                              # fetch dependencies (first run only)
flutter run -d web-server --web-port 8080    # serve at http://localhost:8080
```

Open [http://localhost:8080](http://localhost:8080) in a browser, upload a car image (or paste an image URL), and the app displays the top-k predictions with confidence scores.

The UI defaults to the backend at `http://localhost:8000`. To point it at a different host, override `API_BASE_URL` at build/run time:

```bash
flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8000
```

To produce a static release build (e.g. for hosting or the Playwright smoke tests):

```bash
flutter build web                                       # output in ui/build/web
python3 -m http.server 8080 --directory build/web       # serve the build
```

# ☁️ Deploy (Hugging Face Space)

The whole app — Flutter Web UI **and** FastAPI inference backend — runs in a single container on a
[Hugging Face Docker Space](https://huggingface.co/docs/hub/spaces-sdks-docker). The root
[`Dockerfile`](Dockerfile) builds the web bundle (with an empty `API_BASE_URL` so the UI calls the
API same-origin), then serves both from one `uvicorn` process on port `7860`.

Live Space: **https://huggingface.co/spaces/Garendaxe/driftid**

Deploy (or redeploy after changes):

```bash
deploy/push-to-hf.sh Garendaxe/driftid
```

The script stages only the files the image needs (serving code, model artifacts, UI source — not the
training data) and uploads them with `hf upload`, which stores binaries via Xet automatically (no
`git-lfs` required). Requires the Hugging Face CLI logged in once: `hf auth login`. HF rebuilds the
image on each push — watch progress on the Space's **Logs** tab.

To validate the image locally before pushing (HF Spaces run `linux/amd64`):

```bash
docker build --platform linux/amd64 -t driftid-hf .
docker run --rm -p 7860:7860 driftid-hf            # open http://localhost:7860
```

# 📊 Dataset

This project uses the Car Make, Model, and Generation dataset from Kaggle, which contains labeled images of vehicles across multiple manufacturers, models, and production years.

  - 📦 Dataset: Car Make, Model, and Generation
  - 🔗 Source: https://www.kaggle.com/datasets/riotulab/car-make-model-and-generation
  - 🚗 Content: 41,521 images of cars annotated with:
    - Make (e.g., Toyota, BMW, Audi)
    - Model (e.g., Camry, X5, A4)
    - Generation / Year variant (in some classes)

## 🧠 Dataset Usage
The dataset was used to train a supervised classification model on top of deep visual embeddings extracted from a pretrained vision backbone.

Each image was processed into:

  - A normalized input tensor for feature extraction
  - A corresponding label representing the car class (make + model combination)

## ⚙️ Preprocessing Steps

To ensure consistency and improve model performance, the following preprocessing steps were applied:

  - Resizing images to a fixed resolution (384x384 to be consistent with DINOv3's input dimension)
  - Normalization and augmentation using `timm` data configs

Further, the dataset was splitted into `training` set and `testing` set, with a ratio of 80% `training` set and 20% `testing` set
 
## 📌 Notes
  - The dataset is fine-grained, making classification challenging due to high visual similarity between car models.
  - Some classes have limited samples, introducing mild class imbalance.
  - The dataset structure makes it suitable for both:
    - Standard classification
    - Embedding-based retrieval approaches (e.g., FAISS)

# ✨ Key Features
  - 📷 Image upload interface for real-time inference
  - 🧠 Deep learning-based feature extractor ([DINOv3](https://arxiv.org/abs/2508.10104) Vision Transformer backbone)
  - 🔍 Classification over fine-grained car labels 
  - 🧩 Modular design (feature extractor + classifier separated)

# 🧠 System Architecture

At a high level, the system works as follows:
  1. Input image uploaded by user
  2. Preprocessing pipeline
  3. Feature extraction (DINOv3 Vision Transformer)
  4. Classification layer (Linear Classifier Neural Network trained on car embeddings
  5: Prediction output (Top-k predicted car makes/models + confidence scores)

<div align="center">
  <img width="500" height="721" alt="image" src="https://github.com/user-attachments/assets/8cb1f698-8551-4009-81c4-3673bfc3d4c2" />
</div>

# ⚙️ Model Details
  - **Backbone:** Vision Transformer (ViT) / DINOv3 pretrained model
  - **Embedding size:** `384` dimensional feature vector (For optimal training time)
  - **Classifier:** Linear layer trained on frozen embeddings (Following the strategy outlined in [this article](https://pub.towardsai.net/harness-dinov2-embeddings-for-accurate-image-classification-f102dfd35c51))
  - **Loss function:** Cross-entropy loss
  - **Training strategy:** Feature extraction + supervised fine-tuning on labeled car dataset

# 📚 Citations
  - https://pub.towardsai.net/harness-dinov2-embeddings-for-accurate-image-classification-f102dfd35c51
