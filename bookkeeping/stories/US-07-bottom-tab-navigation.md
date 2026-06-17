# US-07 — Navigate via a bottom tab bar

**Persona:** Car enthusiast  
**Theme:** Application experience  
**Introduced:** S002

**As a** car enthusiast, **I want** a persistent bottom tab bar with the app's main sections, **so that** I can move between identifying a car, my history, and settings without hunting for links.

**Acceptance criteria:**
- [ ] A bottom navigation bar is visible across the main sections with tabs for Search, History, and Settings
- [ ] The active tab is clearly indicated; tapping a tab switches sections without a full page reload
- [ ] The Search tab is the default landing section and hosts the upload/URL identify flow
- [ ] The History tab opens the saved identifications view (US-09)
- [ ] Tabs are labeled and reachable by Playwright (stable `Key` / `Semantics`), consistent with the simple, flat UI guidelines
