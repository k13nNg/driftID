import { test, expect } from '@playwright/test';

test('increment counter three times', async ({ page }) => {
  await page.goto('/');

  // Flutter Web renders to a canvas; the accessibility/semantics DOM tree
  // (which exposes widgets and their Semantics labels to Playwright) is only
  // built once accessibility is enabled. Flutter ships a hidden 1px
  // placeholder for this — dispatch a click on it to turn semantics on.
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  // The FAB carries Semantics(label: 'Increment counter') and a button role.
  const increment = page.getByRole('button', { name: 'Increment counter' });
  await increment.waitFor({ timeout: 15_000 });
  await increment.click();
  await increment.click();
  await increment.click();

  await expect(page.getByText('3', { exact: true })).toBeVisible();
  await page.waitForTimeout(1000); // hold final frame for the recording
});
