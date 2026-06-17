# US-03 — View top-k predictions with confidence

**Persona:** Car enthusiast  
**Theme:** Inference & results  
**Introduced:** S001

**As a** car enthusiast, **I want** to see the top several make/model predictions with confidence scores, **so that** I can judge how sure the system is and pick among similar models.

**Acceptance criteria:**
- [ ] At least top-5 predictions are shown, ordered by confidence
- [ ] Each row shows human-readable make/model (from `classes.json`) and a confidence value
- [ ] Highest-confidence prediction is visually emphasized
