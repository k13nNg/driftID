import { test, expect } from '@playwright/test';
import {
  HOUR_MS,
  MINUTE_MS,
  REMOTE_IMAGE_REF,
  TINY_PNG_DATA_URL,
  seedHistory,
  type SeedEntry,
} from './helpers/seed-history';

// US-09: a pre-seeded user opens History and sees their past identifications as
// a populated list — most-recent-first, each with make/model, confidence, and a
// relative timestamp. No inference runs; entries come straight from storage.
//
// Seeded out of chronological order on purpose to prove HistoryStore sorts the
// list (newest first) regardless of stored order. One entry is an upload
// (data-URL) so that branch is exercised alongside the remote-URL ones.
const entries: SeedEntry[] = [
  {
    id: 'seed-audi',
    agoMs: 2 * HOUR_MS, // oldest → "2h ago"
    source: 'url',
    imageRef: REMOTE_IMAGE_REF,
    predictions: [
      { class: 'audi_a7-gen_2010_2014', confidence: 0.91 },
      { class: 'audi_a6-gen_2011_2015', confidence: 0.06 },
    ],
  },
  {
    id: 'seed-toyota',
    agoMs: 0, // newest → "Just now"
    source: 'url',
    imageRef: REMOTE_IMAGE_REF,
    predictions: [
      { class: 'toyota_supra-gen_2019_2024', confidence: 0.97 },
      { class: 'toyota_gr86-gen_2021_2024', confidence: 0.02 },
    ],
  },
  {
    id: 'seed-bmw',
    agoMs: 5 * MINUTE_MS, // middle → "5m ago" (upload/data-URL branch)
    source: 'upload',
    imageRef: TINY_PNG_DATA_URL,
    predictions: [
      { class: 'bmw_m3-gen_2014_2018', confidence: 0.88 },
      { class: 'bmw_m4-gen_2014_2020', confidence: 0.09 },
    ],
  },
];

test('browse a populated history list', async ({ page }) => {
  await seedHistory(page, entries);
  await page.goto('/');

  // Flutter Web only builds the accessibility/semantics DOM once enabled.
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  const historyTab = page.getByRole('tab', { name: 'History' });
  await historyTab.waitFor({ timeout: 15_000 });
  await historyTab.click();

  // Each seeded entry renders as a tappable tile (make/model in the label).
  // Flutter folds the tile's content into the button's accessible name, so
  // make/model, relative time, and confidence are all asserted there.
  const toyota = page.getByRole('button', { name: /Toyota Supra/ });
  const bmw = page.getByRole('button', { name: /Bmw M3/ });
  const audi = page.getByRole('button', { name: /Audi A7/ });
  await expect(toyota).toBeVisible({ timeout: 15_000 });
  await expect(bmw).toBeVisible();
  await expect(audi).toBeVisible();

  // Relative timestamps derived from createdAt (US-09).
  await expect(toyota).toHaveAccessibleName(/Just now/);
  await expect(bmw).toHaveAccessibleName(/5m ago/);
  await expect(audi).toHaveAccessibleName(/2h ago/);

  // Top-prediction confidence shown per entry.
  await expect(toyota).toHaveAccessibleName(/97\.0%/);
  await expect(bmw).toHaveAccessibleName(/88\.0%/);
  await expect(audi).toHaveAccessibleName(/91\.0%/);

  // Most-recent-first ordering: Toyota (now) above BMW (5m) above Audi (2h),
  // even though they were seeded in a different order.
  const yToyota = (await toyota.boundingBox())!.y;
  const yBmw = (await bmw.boundingBox())!.y;
  const yAudi = (await audi.boundingBox())!.y;
  expect(yToyota).toBeLessThan(yBmw);
  expect(yBmw).toBeLessThan(yAudi);

  await page.waitForTimeout(1500); // hold the final frame for the recording
});
