import { test, expect } from '@playwright/test';
import {
  HOUR_MS,
  MINUTE_MS,
  SEED_CAR_IMAGE,
  seedHistory,
  type SeedEntry,
} from './helpers/seed-history';

// US-11: clear-all is confirmed. Cancelling keeps every entry; confirming wipes
// them and drops back to the T007 empty state. Pre-seeded so no inference runs.
const entries: SeedEntry[] = [
  {
    id: 'seed-audi',
    agoMs: 2 * HOUR_MS,
    source: 'url',
    imageRef: SEED_CAR_IMAGE,
    predictions: [{ class: 'audi_a7-gen_2010_2014', confidence: 0.91 }],
  },
  {
    id: 'seed-bmw',
    agoMs: 5 * MINUTE_MS,
    source: 'url',
    imageRef: SEED_CAR_IMAGE,
    predictions: [{ class: 'bmw_m3-gen_2014_2018', confidence: 0.88 }],
  },
];

test('clear all history (cancel then confirm)', async ({ page }) => {
  await seedHistory(page, entries);
  await page.goto('/');

  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  const historyTab = page.getByRole('tab', { name: 'History' });
  await historyTab.waitFor({ timeout: 15_000 });
  await historyTab.click();

  const audi = page.getByRole('button', { name: /Audi A7/ });
  const bmw = page.getByRole('button', { name: /Bmw M3/ });
  await expect(audi).toBeVisible({ timeout: 15_000 });
  await expect(bmw).toBeVisible();

  const clearAll = page.getByRole('button', { name: 'Clear all' });

  // 1) Cancel keeps everything.
  await clearAll.click();
  await expect(page.getByText('Clear all history?')).toBeVisible({
    timeout: 15_000,
  });
  await page.getByRole('button', { name: 'Cancel', exact: true }).click();
  await expect(audi).toBeVisible();
  await expect(bmw).toBeVisible();

  // 2) Confirm wipes everything → empty state (T007).
  await clearAll.click();
  await expect(page.getByText('Clear all history?')).toBeVisible({
    timeout: 15_000,
  });
  await page.getByRole('button', { name: 'Clear', exact: true }).click();

  await expect(page.getByText('No identifications yet')).toBeVisible({
    timeout: 15_000,
  });
  await expect(audi).toBeHidden();
  await expect(bmw).toBeHidden();

  await page.waitForTimeout(1500); // hold the final frame for the recording
});
