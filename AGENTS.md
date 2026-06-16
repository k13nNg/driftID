# DriftID — agent instructions

Guidance for AI assistants working in this repository.

## Project

End-to-end car make/model identification from images. A pretrained DINOv3 ViT backbone extracts 384-d embeddings; a linear classifier predicts fine-grained car classes. Inference entry point: `Predictor` in `src/model/predictor.py`.

## Environment

- Conda env: `gpu-env` (see `.devcontainer/environment.yml` or `env.yml`)
- `PYTHONPATH` is the repo root — imports use `from src...`
- Example: `python src/test.py`

## Layout

```
src/
  model/          # Predictor, feature extractor, linear classifier
  dataset_processing/  # data prep (mostly done)
  train/          # training scripts (mostly done)
  eval/           # evaluation utilities
data/
  artifacts/      # classes.json, model weights
  json/           # train/test dataset manifests
bookkeeping/stories/  # product user stories and backlog
```

## Current focus

The ML pipeline is considered **done**. Prioritize product and inference UX per `bookkeeping/stories/user-stories.md`:

- Image upload and URL input
- Top-k predictions with confidence
- Loading states and user-facing errors (no stack traces in UI)
- Clear make/model labels from `data/artifacts/classes.json`

**Out of scope unless asked:** retraining, new architectures, dataset splitting, production deployment (auth, rate limits).

## UI requirements

- **Simple and flat** — minimal visual chrome; no gradients, glass effects, heavy shadows, or decorative animation
- Prefer clean layout, solid colors, clear typography, and straightforward controls over polish-heavy or marketing-style design
- One primary action per screen area; avoid nested modals, sidebars, or dashboards unless necessary

## Conventions

- Match existing Python style in `src/` (Path-based roots, `timm` transforms, device auto-detection)
- Keep feature extraction and classification modular — do not merge layers unnecessarily
- Input images: 384×384, normalized via `timm` data config (see `get_transform` in `predictor.py`)
- Artifacts and class labels live under `data/` — do not hardcode paths outside `ROOT`-style resolution

## When making changes

- Prefer small, focused diffs
- Reuse `Predictor.predict_top_k` for inference behavior; UI should mirror its output
- Do not commit secrets, `.env`, or large binary artifacts
- Only create git commits when explicitly requested

