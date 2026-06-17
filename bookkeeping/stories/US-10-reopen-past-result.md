# US-10 — Reopen a past result in full

**Persona:** Car enthusiast  
**Theme:** History & revisiting  
**Introduced:** S002

**As a** car enthusiast, **I want** to reopen a past identification and see its full top-k results, **so that** I can revisit the alternatives without running inference again.

**Acceptance criteria:**
- [ ] Selecting a history entry shows the same full result view as a fresh identification (image preview + top-k list)
- [ ] Reopening a saved result does not call the API again
- [ ] The view clearly indicates it is a saved/past result rather than a new run
