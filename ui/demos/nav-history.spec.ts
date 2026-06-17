import { test, expect } from '@playwright/test';

// Navigation test: tapping the History tab switches to the History section.
// With a fresh browser context (no saved history) the empty-state guidance
// from T007 is shown; the populated list + reopen flow is recorded in T010.
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

  // Empty-state guidance shown when there are no saved identifications (T007).
  await expect(page.getByText('No identifications yet')).toBeVisible({ timeout: 15_000 });
  await page.waitForTimeout(1500);
});
