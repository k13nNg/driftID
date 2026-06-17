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

The same dev container image runs two ways:

| Mode | How it's launched | Source | Use |
|------|-------------------|--------|-----|
| **Interactive** | _Reopen in Container_ (above) | host workspace **bind-mounted** at `/workspaces/driftID` | hands-on solo work |
| **Orchestrator** | `./orchestrate.sh up <T###>` (host) | per-task **named volume**, no host mount | running several `T###` tasks in parallel |

The image is layered so the expensive toolchain stays cached:

```
base  (conda env, Flutter SDK, Playwright, Chromium)   ← rebuild only on dep changes
 └─ dev  (+ gh CLI, warm npm/Playwright caches)         ← target used by the dev container
     └─ sprint-base  (bakes a PINNED commit at /opt/seed/driftID + warm builds)  ← rebuilt per sprint
```

`base`/`dev` stay **code-free**; only `sprint-base` bakes a seed, and only as a warm
start — a worker always `git fetch && switch main && pull` on top at runtime. Auth
(`GH_TOKEN`) is injected at runtime, never baked into a layer.

**Build the images** (run on the host):

```bash
./orchestrate.sh build-dev                       # base/dev toolchain image
./orchestrate.sh build-sprint S002 <commit-sha>  # per-sprint warm seed, pinned to a commit
```

`build-sprint` takes **two required args** — the sprint name and an explicit commit (or
branch/tag) — so a seed is always pinned to a known commit, never an implicit `main`. To pin the
current tip of main, resolve it yourself: `./orchestrate.sh build-sprint S002 $(git rev-parse origin/main)`.

Both accept `--push` to publish to GHCR (`ghcr.io/<owner>/driftid-{dev,sprint}`).
Override `REGISTRY` / `IMAGE_OWNER` / `REPO_URL` via env if needed.

**Resetting / re-pinning a seed.** The ref is resolved to a concrete SHA and the image is tagged
**twice**: a moving `:S###` (latest seed for that sprint) and an immutable `:S###-<sha>` snapshot.
To refresh a seed, re-run `build-sprint S### <newcommit>` — because it pins to the resolved SHA,
the clone + warm-build layers correctly bust and reseed. Old snapshots stay pinnable under their
`:S###-<sha>` tag, so nothing is silently lost; pass `--no-cache` to force a full reclone. `up`
always launches from the moving `:S###` tag.

**Auth prerequisites:**

- **Private clone** (both builds): `gh auth login` so `gh auth token` resolves a token with
  `repo` scope (the orchestrator injects it as a BuildKit secret — it is *not* baked into the image).
- **`--push` to GHCR**: log Docker into GHCR specifically — plain `docker login` only touches
  Docker Hub. `IMAGE_OWNER` must be your **GitHub** account (not a Docker Hub handle), and the
  token needs `write:packages`:

  ```bash
  gh auth login --hostname github.com --git-protocol https --scopes write:packages
  gh auth token | docker login ghcr.io -u <your-github-username> --password-stdin
  ```

  New GHCR packages default to **private**; make them public or grant access in the package
  settings if another account or CI needs to pull them.

**Run a task container:**

```bash
./orchestrate.sh up T006        # start a container off driftid-sprint:S###
./orchestrate.sh logs T006      # follow the warm-start (seed → fetch → build)
./orchestrate.sh ls             # list task containers
./orchestrate.sh attach T006    # open a shell (or use Attach to Running Container)
./orchestrate.sh down T006      # stop+remove; guards unpushed/uncommitted work
```

Containers publish **no ports** — each is network-isolated, so in-container ports stay
constant (`API_PORT=8000`, `WEB_PORT=8080`). Reach the app/API by attaching with
**Dev Containers: Attach to Running Container**, which forwards the ports for you.

Persistence is `git push`: the named volume is the safety net, and `down` refuses to
destroy a volume with unpushed commits unless you pass `--force`. Once attached, run the
`implement-task` skill for the `T###` to do the work and open the PR.

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
