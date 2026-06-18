import { test, expect } from '@playwright/test';
import {
  HOUR_MS,
  MINUTE_MS,
  SEED_CAR_IMAGE,
  SEED_CAR_IMAGE_ALT,
  seedHistory,
  type SeedEntry,
} from './helpers/seed-history';

// End-to-end product tour (T021) — one continuous take that walks the whole
// DriftID product for the PR/portfolio: two live identifications (an uploaded
// Toyota and a pasted Porsche URL), a tour of History (browse → reopen → back →
// delete one → clear all), and the theme switch (Light / Dark / System).
//
// This is additive: the focused `record-*` clips stay as-is, and the headless
// `check` gate is untouched. We pre-seed a small History (a BMW + an Audi) so
// the list is already populated when the tour reaches it; the two fresh
// identifications then stack on top.
//
// The Porsche URL beat resolves a locally bundled image (`ui/web/porsche.jpg` →
// `build/web/porsche.jpg`) served by the same static server hosting the app, so
// `/predict-url` downloads it server-side with no third-party network access.
// Playwright writes a WebM to test-results/**/video.webm (see playwright.config.ts).

const WEB_PORT = process.env.WEB_PORT ?? '8080';
const PORSCHE_URL = `http://localhost:${WEB_PORT}/porsche.jpg`;

// Older entries so History isn't empty when the tour gets there (US-09).
const seeded: SeedEntry[] = [
  {
    id: 'seed-audi',
    agoMs: 2 * HOUR_MS, // oldest → "2h ago"
    source: 'url',
    imageRef: SEED_CAR_IMAGE,
    predictions: [{ class: 'audi_a7-gen_2010_2014', confidence: 0.91 }],
  },
  {
    id: 'seed-bmw',
    agoMs: 30 * MINUTE_MS, // "30m ago"
    source: 'upload',
    imageRef: SEED_CAR_IMAGE_ALT,
    predictions: [{ class: 'bmw_m3-gen_2014_2018', confidence: 0.88 }],
  },
];

test('full product tour', async ({ page }) => {
  // One continuous take with deliberate holds between beats and two live
  // inference round-trips, so it runs well past the default per-test timeout.
  test.setTimeout(240_000);

  // 1) Setup — populate History, then load the app and turn on the
  // accessibility/semantics DOM Flutter Web only builds once enabled.
  await seedHistory(page, seeded);
  await page.goto('/');
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  // 2) Search → upload (Toyota). The whole image card is the picker (T014/T015):
  // tapping it opens the native file chooser, which Playwright intercepts.
  const imageCard = page.getByRole('button', { name: 'Add a car photo' });
  await imageCard.waitFor({ timeout: 15_000 });
  const [chooser] = await Promise.all([
    page.waitForEvent('filechooser'),
    imageCard.click(),
  ]);
  await chooser.setFiles('demos/fixtures/toyota.jpg');
  await page.waitForTimeout(1500); // let the picked photo preview in the card
  await page.getByRole('button', { name: 'Identify' }).click();

  // A successful identify auto-switches to the dedicated Result tab and shows
  // the full top-k there (T016, US-14). Hold the frame.
  await expect(page.getByText('Best match')).toBeVisible({ timeout: 60_000 });
  await page.waitForTimeout(2500);

  // 3) Search → URL (Porsche). Back on Search (now reset to its clean state),
  // paste the locally served Porsche URL, watch it preview in the card, then
  // Identify (US-02/US-13).
  await page.getByRole('tab', { name: 'Search' }).click();
  await expect(page.getByText('Tap to add a car photo')).toBeVisible({
    timeout: 15_000,
  });
  const urlField = page.getByRole('textbox', { name: 'Image URL' });
  await urlField.click();
  await urlField.fill(PORSCHE_URL);
  await page.waitForTimeout(2500); // let the pasted URL preview in the card
  await page.getByRole('button', { name: 'Identify' }).click();
  await expect(page.getByText('Best match')).toBeVisible({ timeout: 60_000 });
  await page.waitForTimeout(2500);

  // 4) History — browse. Both fresh identifications plus the seeded entries are
  // listed, most-recent-first (US-09). The two live results read "Just now".
  await page.getByRole('tab', { name: 'History' }).click();
  const bmw = page.getByRole('button', { name: /Bmw M3/ });
  const audi = page.getByRole('button', { name: /Audi A7/ });
  await expect(bmw).toBeVisible({ timeout: 15_000 });
  await expect(audi).toBeVisible();
  const freshTiles = page.getByRole('button', { name: /Just now/ });
  await expect(freshTiles).toHaveCount(2); // the Toyota + Porsche identifications
  await page.waitForTimeout(2000);

  // 5) Reopen → back. Tap the newest tile; the saved result re-opens on the
  // Result tab marked "saved" with no inference (US-10/US-14). Then go back.
  await freshTiles.first().click();
  await expect(page.getByText('Saved result').first()).toBeVisible({
    timeout: 15_000,
  });
  await expect(page.getByText('Best match')).toBeVisible();
  await page.waitForTimeout(2000);
  await page.getByRole('tab', { name: 'History' }).click();
  await expect(bmw).toBeVisible({ timeout: 15_000 });

  // 6) Delete one. The first per-tile Delete removes the topmost (newest) entry;
  // a confirmation shows and the others remain (US-11).
  await page.getByRole('button', { name: 'Delete' }).first().click();
  await expect(page.getByText('Removed from history')).toBeVisible({
    timeout: 15_000,
  });
  await expect(bmw).toBeVisible();
  await page.waitForTimeout(1500);

  // 7) Clear all → confirm → empty state (US-11).
  await page.getByRole('button', { name: 'Clear all' }).click();
  await expect(page.getByText('Clear all history?')).toBeVisible({
    timeout: 15_000,
  });
  await page.getByRole('button', { name: 'Clear', exact: true }).click();
  await expect(page.getByText('No identifications yet')).toBeVisible({
    timeout: 15_000,
  });
  await page.waitForTimeout(2000);

  // 8) Settings — theme. Step through Dark → Light → System so the re-theme is
  // obvious on video (US-12).
  await page.getByRole('tab', { name: 'Settings' }).click();
  const lightBtn = page.getByRole('button', { name: 'Light' });
  const darkBtn = page.getByRole('button', { name: 'Dark' });
  const systemBtn = page.getByRole('button', { name: 'System' });
  await expect(darkBtn).toBeVisible({ timeout: 15_000 });

  await darkBtn.click();
  await page.waitForTimeout(2000);
  await lightBtn.click();
  await page.waitForTimeout(2000);
  await systemBtn.click();
  await page.waitForTimeout(2000);
});
