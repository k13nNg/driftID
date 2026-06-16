# User stories

Stories below cover product experience and inference UX. The ML pipeline (feature extraction, classifier, training) is considered done.

Format: **As a** [persona], **I want** [goal], **so that** [benefit].

---

## Inference & results

### US-01 — Upload a car image

**As a** car enthusiast, **I want** to upload a car image from my device, **so that** I can identify the make and model without using the command line.

**Acceptance criteria:**
- [ ] UI accepts common image formats (e.g. JPEG, PNG, WebP)
- [ ] User sees a preview of the uploaded image before or after inference
- [ ] Invalid or non-image files show a clear error message

---

### US-02 — Submit an image URL

**As a** used-car shopper, **I want** to paste an image URL from a listing, **so that** I can check a car without downloading the photo first.

**Acceptance criteria:**
- [ ] UI accepts a valid HTTP(S) image URL
- [ ] Broken, blocked, or non-image URLs surface a helpful error (not a stack trace)
- [ ] Results match what `Predictor.predict_top_k` returns for the same URL

---

### US-03 — View top-k predictions with confidence

**As a** car enthusiast, **I want** to see the top several make/model predictions with confidence scores, **so that** I can judge how sure the system is and pick among similar models.

**Acceptance criteria:**
- [ ] At least top-5 predictions are shown, ordered by confidence
- [ ] Each row shows human-readable make/model (from `classes.json`) and a confidence value
- [ ] Highest-confidence prediction is visually emphasized

---

### US-04 — Run inference in real time

**As a** car enthusiast, **I want** inference to run shortly after I submit an image, **so that** the app feels responsive and I get answers quickly.

**Acceptance criteria:**
- [ ] Loading state is shown while the model runs
- [ ] Typical single-image inference completes without a full page reload
- [ ] Failures (model load, CUDA/CPU, bad input) show a user-facing message

---

## Application experience

### US-05 — Understand the app at a glance

**As a** used-car shopper, **I want** a short explanation of what DriftID does on the main screen, **so that** I know what to upload and what to expect.

**Acceptance criteria:**
- [ ] One-line summary matches README intent (identify car make/model from an image)

---

### US-06 — Readable prediction labels

**As a** used-car shopper, **I want** prediction labels formatted clearly (make, model, year/generation when present), **so that** I can compare them to a listing title.

**Acceptance criteria:**
- [ ] Class strings are displayed as-is or parsed into consistent make / model / variant fields
- [ ] Confidence is shown in an easy-to-scan format (e.g. percentage)

---

## Out of scope (for this backlog)

- Retraining, dataset splitting, or embedding index builds
- New model architectures or classifier experiments
- Production deployment (auth, rate limits, multi-tenant hosting)
- Demo / portfolio flows (sample images, guided walkthroughs)
