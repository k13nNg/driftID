import { test, expect } from '@playwright/test';

// Records the DriftID happy path: upload a car photo, run inference, and show
// the top-k predictions. Playwright writes a WebM to test-results/**/video.webm
// once the test context closes (see playwright.config.ts).
test('upload and predict demo', async ({ page }) => {
  await page.goto('/');

  // Flutter Web renders to a canvas; the accessibility/semantics DOM tree
  // (which exposes Semantics labels to Playwright) is only built once
  // accessibility is enabled. Flutter ships a hidden placeholder for this —
  // dispatch a click on it to turn semantics on.
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  // Pick the sample car image. file_picker opens a native file chooser on the
  // web, which Playwright intercepts via the filechooser event.
  const upload = page.getByRole('button', { name: 'Upload image' });
  await upload.waitFor({ timeout: 15_000 });
  const [chooser] = await Promise.all([
    page.waitForEvent('filechooser'),
    upload.click(),
  ]);
  await chooser.setFiles('demos/fixtures/sample-car.jpg');

  // Run inference.
  await page.getByRole('button', { name: 'Identify' }).click();

  // Wait for the top result to appear, then hold the frame for the recording.
  await expect(page.getByText('Best match')).toBeVisible({ timeout: 60_000 });
  await page.waitForTimeout(2500);
});
