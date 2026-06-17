import { test, expect } from '@playwright/test';
import { REMOTE_IMAGE_REF, seedHistory, type SeedEntry } from './helpers/seed-history';

// US-10: reopening a saved identification shows the full top-k result view again
// — reconstructed entirely from storage, with NO inference call. We seed one
// entry, guard every request, reopen it, assert the complete result is shown,
// and finally assert the backend was never hit.
const entry: SeedEntry = {
  id: 'seed-reopen',
  agoMs: 0,
  source: 'url',
  imageRef: REMOTE_IMAGE_REF,
  predictions: [
    { class: 'audi_a7-gen_2010_2014', confidence: 0.91 },
    { class: 'audi_a6-gen_2011_2015', confidence: 0.06 },
    { class: 'audi_a8-gen_2013_2017', confidence: 0.03 },
  ],
};

test('reopen a saved result without inference', async ({ page }) => {
  // Fail-safe: record any inference request. The endpoints are POST /predict
  // and POST /predict-url (see ui/lib/services/api_client.dart).
  const inferenceCalls: string[] = [];
  page.on('request', (req) => {
    if (/\/predict(\b|-url|\?)/.test(req.url())) {
      inferenceCalls.push(req.url());
    }
  });

  await seedHistory(page, [entry]);
  await page.goto('/');

  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30_000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');

  const historyTab = page.getByRole('tab', { name: 'History' });
  await historyTab.waitFor({ timeout: 15_000 });
  await historyTab.click();

  // Reopen the seeded entry from the list.
  const tile = page.getByRole('button', { name: /Audi A7/ });
  await expect(tile).toBeVisible({ timeout: 15_000 });
  await tile.click();

  // Full saved-result view: the "Saved result" screen with the best match and
  // the rest of the top-k (US-10) — all from storage.
  await expect(
    page.getByRole('heading', { name: 'Saved result' }),
  ).toBeVisible({ timeout: 15_000 });
  await expect(page.getByText('Best match')).toBeVisible();
  await expect(page.getByText(/Audi A7/)).toBeVisible();
  await expect(page.getByText(/Audi A6/)).toBeVisible(); // a lower-ranked row
  await expect(page.getByText('91.0%')).toBeVisible();

  await page.waitForTimeout(1500); // let any (forbidden) request fire before asserting

  // The crux of US-10: no inference was triggered by reopening.
  expect(inferenceCalls, `unexpected inference calls: ${inferenceCalls.join(', ')}`)
    .toEqual([]);
});
