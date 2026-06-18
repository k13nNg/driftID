import { test, expect } from '@playwright/test';

// Records the S003 theme switch (US-12): open Settings and step through
// Dark → Light → System on the segmented Theme control (T013), holding each
// frame so the WebM clearly shows the whole app re-theming. Playwright writes a
// WebM to test-results/**/video.webm (see playwright.config.ts).
test('switch color theme (dark / light / system)', async ({ page }) => {
  await page.goto('/');

  // Flutter Web renders to a canvas; its accessibility/semantics DOM (which
  // exposes Semantics labels / roles to Playwright) is only built once
  // accessibility is enabled. Click the hidden placeholder to turn it on.
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  // Open Settings (US-07 nav).
  const settingsTab = page.getByRole('tab', { name: 'Settings' });
  await settingsTab.waitFor({ timeout: 15_000 });
  await settingsTab.click();

  // The segmented Theme control from T013: Light / Dark / System.
  const lightBtn = page.getByRole('button', { name: 'Light' });
  const darkBtn = page.getByRole('button', { name: 'Dark' });
  const systemBtn = page.getByRole('button', { name: 'System' });
  await expect(darkBtn).toBeVisible({ timeout: 15_000 });
  await expect(lightBtn).toBeVisible();
  await expect(systemBtn).toBeVisible();

  // Dark — the whole app darkens instantly (T012 wiring). Hold the frame.
  await darkBtn.click();
  await page.waitForTimeout(2000);

  // Light — back to the bright palette.
  await lightBtn.click();
  await page.waitForTimeout(2000);

  // System — follow the OS appearance. Hold the final frame for the recording.
  await systemBtn.click();
  await page.waitForTimeout(2000);
});
