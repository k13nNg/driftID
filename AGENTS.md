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
bookkeeping/
  stories/          # product user stories and personas
  task_management/  # sprints (S###.md), tasks (T###.md), templates
ui/                 # Flutter Web frontend (when implemented)
```

## Task management

Work is planned in `bookkeeping/task_management/`:

| File | Purpose |
|------|---------|
| `S###.md` | **Sprint** — goal, task list, sprint-level acceptance criteria |
| `T###.md` | **Task** — implementation spec for one deliverable |
| `template-sprint.md` | Copy to create a new sprint |
| `template-task.md` | Copy to create a new task |

- User stories live in `bookkeeping/stories/user-stories.md` (`US-##`); sprints/tasks reference them under **Maps to**.
- Tasks may declare **Depends on** other tasks; respect ordering.
- Some acceptance criteria are **Human:** (reviewer sign-off) — do not mark done without explicit approval.
- When implementing work, follow the active task spec; update checkboxes only when criteria are actually met.

**Active sprint:** [S003 — Settings & focused Search](bookkeeping/task_management/S003.md) — settings store + theme modes (T012), theme control UI (T013), image selection card (T014), URL input + Search relayout (T015), Result tab + shared result surface (T016), live URL image preview + shared preview component (T018), demo recording + regression (T017).

**Previous sprint:** [S002 — Prediction history & navigation](bookkeeping/task_management/S002.md) (done) — bottom tab nav (T005), local history store + auto-save (T006), browse history (T007), reopen result (T008), manage/clear (T009), history demo recording (T010), pre-seeded history E2E (T011).

**Earlier:** [S001 — Setup Dependencies](bookkeeping/task_management/done/S001.md) (done) — dev container deps (T000), FastAPI (T001), Flutter Web scaffold + Playwright smoke (T002), DriftID UI + demo recordings (T003), UI cleanup (T004).

## Engineering guidelines

**Before implementing product or UX work**, read these in order:

1. **`bookkeeping/stories/user-stories.md`** — product intent and acceptance criteria (`US-##`). This is the source of truth for *what* users need.
2. **The relevant `S###.md`** — sprint goal, task breakdown, architecture, and sprint-level scope. Confirms *which slice* of the backlog is in flight and how tasks fit together.
3. **The relevant `T###.md`** — implementation spec for the task at hand: approach, files, run commands, and task acceptance criteria. This is the source of truth for *how* to build and *when* the task is done.

If the task lists **Depends on**, read those `T###.md` files too — do not skip prerequisite work.

While coding:

- Implement only what the task spec and mapped user stories require; do not pull in **Out of scope** items from the sprint or task.
- Verify each acceptance criterion in the task (and sprint, where applicable) before marking checkboxes or reporting the task complete.
- Leave **Human:** criteria unchecked until a reviewer explicitly approves.

If the user’s request does not map to an existing task, say so and ask whether to extend a task or add a new `T###.md` (from `template-task.md`) before building.


## UI requirements

**Scope:** "Simple and flat" is a **visual design** guideline only — it governs how the UI *looks* (styling, layout, chrome). It does **not** constrain code architecture, project/file structure, dependencies, or feature scope. Don't cite it to argue against extracting widgets, adding services/state management, splitting files, or building out functionality.

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
- New sprints/tasks: copy `template-sprint.md` / `template-task.md`, rename to `S###.md` / `T###.md`, link from the parent sprint’s task table
- Do not commit secrets, `.env`, or large binary artifacts
- Only create git commits when explicitly requested
