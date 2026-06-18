import { test, expect } from '@playwright/test';

// Records the DriftID happy path against the S003 redesign: pick a car photo via
// the single image card (the old "Upload image" button is gone), run inference,
// and see the full top-k on the dedicated Result tab — the result is no longer
// shown inline on Search. After identifying, Search resets to a clean state.
// Playwright writes a WebM to test-results/**/video.webm (see playwright.config.ts).
test('upload and predict demo', async ({ page }) => {
  await page.goto('/');

  // Flutter Web renders to a canvas; the accessibility/semantics DOM (which
  // exposes Semantics labels to Playwright) is only built once accessibility is
  // enabled. Flutter ships a hidden placeholder for this — dispatch a click on
  // it to turn semantics on.
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  // Pick the sample car image. The whole image card is the picker now
  // (T014/T015): tapping it opens the native file chooser, which Playwright
  // intercepts via the filechooser event.
  const imageCard = page.getByRole('button', { name: 'Add a car photo' });
  await imageCard.waitFor({ timeout: 15_000 });
  const [chooser] = await Promise.all([
    page.waitForEvent('filechooser'),
    imageCard.click(),
  ]);
  await chooser.setFiles('demos/fixtures/sample-car.jpg');

  // Run inference.
  await page.getByRole('button', { name: 'Identify' }).click();

  // A successful identify auto-switches to the dedicated Result tab and shows
  // the full top-k there (T016, US-14) — not inline on Search. Hold the frame.
  await expect(page.getByText('Best match')).toBeVisible({ timeout: 60_000 });
  await page.waitForTimeout(2500);

  // Back on Search the screen has reset to its clean/empty state (US-13): the
  // image card prompts for a new photo again.
  await page.getByRole('tab', { name: 'Search' }).click();
  await expect(page.getByText('Tap to add a car photo')).toBeVisible({
    timeout: 15_000,
  });
  await page.waitForTimeout(1500);
});
