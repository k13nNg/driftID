# US-13 — A focused, uncluttered Search screen

**Persona:** Used-car shopper  
**Theme:** Application experience  
**Introduced:** S003

**As a** used-car shopper, **I want** the Search screen to be a calm, focused place with one clear way to add an image and one to paste a URL, **so that** I'm not distracted by extra chrome and always know what to do next.

**Acceptance criteria:**
- [ ] Image selection is a single clickable card that is both the picker and the preview — there is no separate "Upload image" button
- [ ] The image card keeps a fixed footprint whether empty or filled (selecting an image does not resize it), with an option to expand/inspect the chosen image
- [ ] A distinct URL input component sits below the card, separated by a divider; the `Identify` action remains the single primary action
- [ ] The screen does not show a result inline — after identifying, Search returns to a clean, empty state (result is shown elsewhere, US-14)
- [ ] Layout stays simple and flat per `AGENTS.md`; all inputs are labeled and reachable by Playwright (stable `Key` / `Semantics`)
