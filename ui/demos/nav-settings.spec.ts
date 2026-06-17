import { test, expect } from '@playwright/test';

// Stub navigation test (T005): tapping the Settings tab switches to the
// Settings section. Settings is a placeholder this sprint, so this only checks
// the section opens; a real settings feature set gets its own tests later.
test('navigate to settings tab', async ({ page }) => {
  await page.goto('/');

  // Enable Flutter Web semantics so Playwright can see labels (see other specs).
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  const settingsTab = page.getByRole('tab', { name: 'Settings' });
  await settingsTab.waitFor({ timeout: 15_000 });
  await settingsTab.click();

  // Minimal placeholder body for this task.
  await expect(
    page.getByText('DriftID identifies a car\'s make and model from a photo.'),
  ).toBeVisible({ timeout: 15_000 });
  await page.waitForTimeout(1500);
});
