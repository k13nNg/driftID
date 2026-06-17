# US-14 — See results in a dedicated view

**Persona:** Car enthusiast  
**Theme:** Inference & results  
**Introduced:** S003

**As a** car enthusiast, **I want** my identification result to open in its own dedicated view rather than crowding the Search screen, **so that** I can focus on the prediction and keep Search clean for the next photo.

**Acceptance criteria:**
- [ ] A Result tab is always present in the bottom navigation; before any identification it shows a clear empty state ("no result yet")
- [ ] A successful identification automatically switches to the Result tab and shows the full image preview + top-k list (US-03)
- [ ] Reopening a past identification from History opens it in the same Result view, clearly marked as a saved result, and makes **no** API call (US-10 carries over)
- [ ] Returning to Search after viewing a result shows a clean, empty state ready for a new identification (US-13)
- [ ] The Result tab and its content are labeled and reachable by Playwright (stable `Key` / `Semantics`)
