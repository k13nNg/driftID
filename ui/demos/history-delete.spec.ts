import { test, expect } from '@playwright/test';
import {
  HOUR_MS,
  MINUTE_MS,
  SEED_CAR_IMAGE,
  seedHistory,
  type SeedEntry,
} from './helpers/seed-history';

// US-11: a pre-seeded user deletes a single entry. The deleted one disappears,
// the other remains, and a "Removed from history" confirmation is shown. Newest
// is first, so the top per-tile delete control removes the BMW entry.
const entries: SeedEntry[] = [
  {
    id: 'seed-audi',
    agoMs: 2 * HOUR_MS, // older → second in the list
    source: 'url',
    imageRef: SEED_CAR_IMAGE,
    predictions: [{ class: 'audi_a7-gen_2010_2014', confidence: 0.91 }],
  },
  {
    id: 'seed-bmw',
    agoMs: 5 * MINUTE_MS, // newer → first in the list
    source: 'url',
    imageRef: SEED_CAR_IMAGE,
    predictions: [{ class: 'bmw_m3-gen_2014_2018', confidence: 0.88 }],
  },
];

test('delete a single history entry', async ({ page }) => {
  await seedHistory(page, entries);
  await page.goto('/');

  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  const historyTab = page.getByRole('tab', { name: 'History' });
  await historyTab.waitFor({ timeout: 15_000 });
  await historyTab.click();

  const bmw = page.getByRole('button', { name: /Bmw M3/ });
  const audi = page.getByRole('button', { name: /Audi A7/ });
  await expect(bmw).toBeVisible({ timeout: 15_000 });
  await expect(audi).toBeVisible();

  // The first delete control belongs to the topmost (newest) tile — BMW.
  await page.getByRole('button', { name: 'Delete' }).first().click();

  // Confirmation surfaced, BMW removed, Audi kept.
  await expect(page.getByText('Removed from history')).toBeVisible({
    timeout: 15_000,
  });
  await expect(bmw).toBeHidden();
  await expect(audi).toBeVisible();

  await page.waitForTimeout(1500); // hold the final frame for the recording
});
