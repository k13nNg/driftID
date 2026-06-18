import { test, expect } from '@playwright/test';
import {
  HOUR_MS,
  MINUTE_MS,
  SEED_CAR_IMAGE,
  SEED_CAR_IMAGE_ALT,
  seedHistory,
  type SeedEntry,
} from './helpers/seed-history';

// Records the seeded History experience (T020, US-09/US-10): a pre-populated
// user opens History to a list where every entry shows a real car thumbnail —
// no blank/broken placeholders — then reopens one into the shared Result view,
// which also paints the real image. This is the clip that proves the default
// test data renders real cars throughout. Playwright writes a WebM to
// test-results/**/video.webm (see playwright.config.ts).
const entries: SeedEntry[] = [
  {
    id: 'seed-toyota',
    agoMs: 0, // newest → "Just now"
    source: 'url',
    imageRef: SEED_CAR_IMAGE_ALT,
    predictions: [
      { class: 'toyota_supra-gen_2019_2024', confidence: 0.97 },
      { class: 'toyota_gr86-gen_2021_2024', confidence: 0.02 },
    ],
  },
  {
    id: 'seed-bmw',
    agoMs: 5 * MINUTE_MS, // upload / data-URL bytes branch
    source: 'upload',
    imageRef: SEED_CAR_IMAGE,
    predictions: [
      { class: 'bmw_m3-gen_2014_2018', confidence: 0.88 },
      { class: 'bmw_m4-gen_2014_2020', confidence: 0.09 },
    ],
  },
  {
    id: 'seed-audi',
    agoMs: 2 * HOUR_MS, // URL branch
    source: 'url',
    imageRef: SEED_CAR_IMAGE,
    predictions: [
      { class: 'audi_a7-gen_2010_2014', confidence: 0.91 },
      { class: 'audi_a6-gen_2011_2015', confidence: 0.06 },
    ],
  },
];

test('browse seeded history with real car thumbnails', async ({ page }) => {
  await seedHistory(page, entries);
  await page.goto('/');

  // Flutter Web only builds the accessibility/semantics DOM once enabled.
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  // Open History — the pre-seeded list (US-09).
  const historyTab = page.getByRole('tab', { name: 'History' });
  await historyTab.waitFor({ timeout: 15_000 });
  await historyTab.click();

  // Every entry renders with a real car thumbnail; hold the populated list.
  const toyota = page.getByRole('button', { name: /Toyota Supra/ });
  const bmw = page.getByRole('button', { name: /Bmw M3/ });
  const audi = page.getByRole('button', { name: /Audi A7/ });
  await expect(toyota).toBeVisible({ timeout: 15_000 });
  await expect(bmw).toBeVisible();
  await expect(audi).toBeVisible();
  await page.waitForTimeout(2500);

  // Reopen a saved result (US-10) — the Result view shows the real image too.
  await audi.click();
  await expect(page.getByText('Saved result').first()).toBeVisible({
    timeout: 15_000,
  });
  await expect(page.getByText('Best match')).toBeVisible();
  await expect(page.getByText('Preview unavailable')).toBeHidden();
  await page.waitForTimeout(2500); // hold the final frame for the recording
});
