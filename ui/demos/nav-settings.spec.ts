import { test, expect } from '@playwright/test';

// Navigation and theme control test (T013): tapping the Settings tab switches to the
// Settings section, and allows selecting Light, Dark, or System theme.
test('navigate to settings tab and switch themes', async ({ page }) => {
  await page.goto('/');

  // Enable Flutter Web semantics so Playwright can see labels (see other specs).
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  const settingsTab = page.getByRole('tab', { name: 'Settings' });
  await settingsTab.waitFor({ timeout: 15_000 });
  await settingsTab.click();

  // About section
  await expect(
    page.getByText('DriftID identifies a car\'s make and model from a photo.'),
  ).toBeVisible({ timeout: 15_000 });

  // Theme controls (T013)
  const lightBtn = page.getByRole('button', { name: 'Light' });
  const darkBtn = page.getByRole('button', { name: 'Dark' });
  const systemBtn = page.getByRole('button', { name: 'System' });

  await expect(lightBtn).toBeVisible({ timeout: 15_000 });
  await expect(darkBtn).toBeVisible({ timeout: 15_000 });
  await expect(systemBtn).toBeVisible({ timeout: 15_000 });

  // Tap Dark theme
  await darkBtn.click();
  await page.waitForTimeout(1000);

  // Tap Light theme
  await lightBtn.click();
  await page.waitForTimeout(1000);

  // Tap System theme
  await systemBtn.click();
  await page.waitForTimeout(1500);
});
