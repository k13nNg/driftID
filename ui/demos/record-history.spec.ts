import { test, expect } from '@playwright/test';

// Records the history flow against the S003 redesign (US-07–US-10, US-14):
// identify a car (picked via the single image card), land on the dedicated
// Result tab, switch to History where the result was auto-saved, and reopen the
// saved entry — which re-publishes it into the same Result tab marked "saved",
// with no second inference call. Playwright writes a WebM to
// test-results/**/video.webm (see playwright.config.ts).
test('save and reopen from history', async ({ page }) => {
  await page.goto('/');

  // Flutter Web renders to a canvas; its accessibility/semantics DOM (which
  // exposes Semantics labels / roles to Playwright) is only built once
  // accessibility is enabled. Click the hidden placeholder to turn it on.
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  // 1) Identify a car. Search is the default landing section (US-07); the whole
  // image card is the picker (T014/T015).
  const imageCard = page.getByRole('button', { name: 'Add a car photo' });
  await imageCard.waitFor({ timeout: 15_000 });
  const [chooser] = await Promise.all([
    page.waitForEvent('filechooser'),
    imageCard.click(),
  ]);
  await chooser.setFiles('demos/fixtures/sample-car.jpg');
  await page.getByRole('button', { name: 'Identify' }).click();

  // The app auto-switches to the Result tab and shows the full top-k (T016).
  await expect(page.getByText('Best match')).toBeVisible({ timeout: 60_000 });
  await page.waitForTimeout(1500); // let the result settle on screen

  // 2) Switch to History — the identification was auto-saved (US-08/US-09).
  const historyTab = page.getByRole('tab', { name: 'History' });
  await historyTab.waitFor({ timeout: 15_000 });
  await historyTab.click();

  // The just-saved entry surfaces as a tile whose Semantics label combines the
  // make/model with its relative time ("Just now" right after identifying).
  const savedTile = page.getByRole('button', { name: /Just now/ }).first();
  await expect(savedTile).toBeVisible({ timeout: 15_000 });
  await page.waitForTimeout(1500);

  // 3) Reopen the saved result (US-10/US-14) — reconstructed from storage and
  // shown on the Result tab marked "saved", with no API call.
  await savedTile.click();
  await expect(page.getByText('Saved result').first()).toBeVisible({
    timeout: 15_000,
  });
  await expect(page.getByText('Best match')).toBeVisible();

  await page.waitForTimeout(2500); // hold the final frame for the recording
});
