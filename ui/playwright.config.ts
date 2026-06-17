import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './demos',
  use: {
    baseURL: 'http://localhost:8080',
    viewport: { width: 1280, height: 720 },
    video: { mode: 'on', size: { width: 1280, height: 720 } },
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
      command: 'uvicorn src.api.server:app --host 0.0.0.0 --port 8000',
      url: 'http://localhost:8000/health',
      cwd: '..',
      reuseExistingServer: true,
      timeout: 180_000,
    },
    // Flutter Web app. The debug `flutter run -d web-server` build does not
    // mount under headless Chromium (it stalls waiting for a debug
    // connection), so serve a static release build instead.
    {
      command: 'flutter build web && python3 -m http.server 8080 --directory build/web',
      url: 'http://localhost:8080',
      reuseExistingServer: true,
      timeout: 180_000,
    },
  ],
});
