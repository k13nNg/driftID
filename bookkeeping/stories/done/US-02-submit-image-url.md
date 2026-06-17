# US-02 — Submit an image URL

**Persona:** Used-car shopper  
**Theme:** Inference & results  
**Introduced:** S001

**As a** used-car shopper, **I want** to paste an image URL from a listing, **so that** I can check a car without downloading the photo first.

**Acceptance criteria:**
- [ ] UI accepts a valid HTTP(S) image URL
- [ ] Broken, blocked, or non-image URLs surface a helpful error (not a stack trace)
- [ ] Results match what `Predictor.predict_top_k` returns for the same URL
