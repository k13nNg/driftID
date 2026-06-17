import { defineConfig } from '@playwright/test';

// Ports are env-driven so each orchestrator container (and local runs) can use
// an isolated block without editing config. Defaults match the docs: API on
// 8000, Flutter Web on 8080.
const API_PORT = process.env.API_PORT ?? '8000';
const WEB_PORT = process.env.WEB_PORT ?? '8080';

export default defineConfig({
  testDir: './demos',
  use: {
    baseURL: `http://localhost:${WEB_PORT}`,
    // iPhone 14 / 13 logical resolution: 390 × 844 — keeps the recorded demo
    // phone-shaped. Dimensions are set directly (rather than spreading
    // devices['iPhone 14']) to keep the existing Chromium + CanvasKit setup.
    viewport: { width: 390, height: 844 },
    video: { mode: 'on', size: { width: 390, height: 844 } },
    // Flutter Web's CanvasKit engine throws "Incorrect locale information
    // provided" under headless Chromium unless a locale is supplied.
    locale: 'en-US',
    // Slow each action down so the recorded demo is easy to follow. Override
    // per run with e.g. SLOWMO=0 npx playwright test.
    launchOptions: {
      slowMo: Number(process.env.SLOWMO ?? 500),
    },
  },
  webServer: [
    // FastAPI inference backend (T001). Started from the repo root.
    {
      command: `uvicorn src.api.server:app --host 0.0.0.0 --port ${API_PORT}`,
      url: `http://localhost:${API_PORT}/health`,
      cwd: '..',
      reuseExistingServer: true,
      timeout: 180_000,
    },
    // Flutter Web app. The debug `flutter run -d web-server` build does not
    // mount under headless Chromium (it stalls waiting for a debug
    // connection), so serve a static release build instead. The build is
    // pinned to the backend's API_PORT so the bundled client hits the right
    // host:port.
    {
      command: `flutter build web --dart-define=API_BASE_URL=http://localhost:${API_PORT} && python3 -m http.server ${WEB_PORT} --directory build/web`,
      url: `http://localhost:${WEB_PORT}`,
      reuseExistingServer: true,
      timeout: 180_000,
    },
  ],
});
