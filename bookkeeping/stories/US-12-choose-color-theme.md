# US-12 — Choose a color theme

**Persona:** Car enthusiast  
**Theme:** Application experience  
**Introduced:** S003

**As a** car enthusiast, **I want** to pick whether DriftID uses a light, dark, or system-matched color theme, **so that** the app is comfortable to look at in my environment and remembers my choice.

**Acceptance criteria:**
- [ ] Settings offers a color preference with three choices: Light, Dark, and System (follow OS)
- [ ] Selecting an option applies the theme immediately across every section (Search, History, Result, Settings) with no reload
- [ ] "System" follows the operating system / browser appearance and tracks changes to it
- [ ] The chosen preference is persisted locally and restored on reload and in a new browser session
- [ ] Both light and dark themes keep the DriftID palette legible and readable (US-06 carries over); the control is labeled and reachable by Playwright (stable `Key` / `Semantics`)
