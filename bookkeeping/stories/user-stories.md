# User stories

Stories below cover product experience and inference UX. The ML pipeline (feature extraction, classifier, training) is considered done.

Format: **As a** [persona], **I want** [goal], **so that** [benefit].

Each story lives in its own `US-##-*.md` file. Sprints and tasks reference stories by ID (e.g. `US-01`) under **Maps to**.

---

## Inference & results

| Story | Persona | Introduced |
|-------|---------|------------|
| [US-01 — Upload a car image](US-01-upload-car-image.md) | Car enthusiast | S001 |
| [US-02 — Submit an image URL](US-02-submit-image-url.md) | Used-car shopper | S001 |
| [US-03 — View top-k predictions with confidence](US-03-view-top-k-predictions.md) | Car enthusiast | S001 |
| [US-04 — Run inference in real time](US-04-real-time-inference.md) | Car enthusiast | S001 |

## Application experience

| Story | Persona | Introduced |
|-------|---------|------------|
| [US-05 — Understand the app at a glance](US-05-app-at-a-glance.md) | Used-car shopper | S001 |
| [US-06 — Readable prediction labels](US-06-readable-prediction-labels.md) | Used-car shopper | S001 |
| [US-07 — Navigate via a bottom tab bar](US-07-bottom-tab-navigation.md) | Car enthusiast | S002 |

## History & revisiting

| Story | Persona | Introduced |
|-------|---------|------------|
| [US-08 — Auto-save recent identifications](US-08-auto-save-recent-predictions.md) | Used-car shopper | S002 |
| [US-09 — Browse past identifications](US-09-browse-prediction-history.md) | Used-car shopper | S002 |
| [US-10 — Reopen a past result in full](US-10-reopen-past-result.md) | Car enthusiast | S002 |
| [US-11 — Manage and clear history](US-11-manage-prediction-history.md) | Car enthusiast | S002 |

---

## Out of scope (for this backlog)

- Retraining, dataset splitting, or embedding index builds
- New model architectures or classifier experiments
- Production deployment (auth, rate limits, multi-tenant hosting)
- Demo / portfolio flows (sample images, guided walkthroughs)
