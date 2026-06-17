import { test, expect } from '@playwright/test';

// Stub navigation test (T005): tapping the History tab switches to the History
// section. The placeholder content is asserted here; richer history behaviour
// (list, reopen, clear) gets its own tests when T007–T009 land.
test('navigate to history tab', async ({ page }) => {
  await page.goto('/');

  // Flutter Web only builds the accessibility/semantics DOM (which exposes
  // Semantics labels to Playwright) once accessibility is enabled. Click the
  // hidden placeholder Flutter ships to turn it on.
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  const historyTab = page.getByRole('tab', { name: 'History' });
  await historyTab.waitFor({ timeout: 15_000 });
  await historyTab.click();

  // Placeholder body for this task (populated in T007).
  await expect(page.getByText('No history yet')).toBeVisible({ timeout: 15_000 });
  await page.waitForTimeout(1500);
});
