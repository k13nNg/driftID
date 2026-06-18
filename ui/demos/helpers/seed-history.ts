import type { Page } from '@playwright/test';
import { SAMPLE_CAR_DATA_URL, SAMPLE_CAR_DATA_URL_ALT } from '../fixtures/seed-cars';

// Re-exported so specs can pull the seed images and helpers from one place.
export { SAMPLE_CAR_DATA_URL, SAMPLE_CAR_DATA_URL_ALT };

// Pre-seed browser-local history for the T011 specs so the History flows
// (browse / reopen / delete / clear) run from a populated user state without
// driving inference or touching the backend.
//
// Storage format (verified against a genuine save, T011):
//   - key:   'driftid.history.v1'  (no `flutter.` prefix — the new
//            `SharedPreferencesAsync` web backend writes the raw key)
//   - value: json.encode(<HistoryEntry[] JSON string>) — i.e. the array is
//            JSON-stringified, then that string is JSON-encoded *again* by
//            shared_preferences. So localStorage holds a double-encoded string.
//
// Seeding MUST happen via addInitScript (before navigation) because the app
// calls HistoryStore.load() in initState; a post-load setItem would be missed
// until a reload.

/** The exact localStorage key HistoryStore persists to on web. */
export const HISTORY_STORAGE_KEY = 'driftid.history.v1';

/** A single top-k result, matching the persisted `Prediction` shape. */
export type SeedPrediction = {
  class: string;
  confidence: number;
};

/**
 * A history entry to seed. `agoMs` is how long before page load the
 * identification ran; the real ISO-8601 `createdAt` is computed *in the
 * browser* so the relative-time label and timezone match the app's own clock.
 */
export type SeedEntry = {
  id: string;
  agoMs: number;
  source: 'url' | 'upload';
  imageRef: string;
  predictions: SeedPrediction[];
};

/**
 * Default offline-safe car image for seeded entries (T020). Both the
 * `source: 'url'` branch (rendered via `Image.network`) and the
 * `source: 'upload'` branch (decoded to bytes via `Image.memory`) resolve a
 * `data:` URL without touching the network, so every seeded thumbnail/result
 * paints a real car instead of the old blank placeholders.
 */
export const SEED_CAR_IMAGE = SAMPLE_CAR_DATA_URL;

/** A second car image (mirror) so a seeded list isn't all identical thumbnails. */
export const SEED_CAR_IMAGE_ALT = SAMPLE_CAR_DATA_URL_ALT;

/**
 * Inject `entries` into localStorage in the real shared_preferences format so
 * HistoryStore.load() hydrates them at startup. Call before `page.goto(...)`.
 */
export async function seedHistory(page: Page, entries: SeedEntry[]): Promise<void> {
  await page.addInitScript(
    (data: { key: string; entries: SeedEntry[] }) => {
      const pad = (n: number, len = 2) => String(n).padStart(len, '0');
      // Local-naive ISO (no Z/offset), matching Dart's DateTime.toIso8601String()
      // for a local DateTime — DateTime.tryParse then reads it back as local.
      const toLocalIso = (d: Date) =>
        `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T` +
        `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}.` +
        `${pad(d.getMilliseconds(), 3)}`;

      const now = Date.now();
      const records = data.entries.map((e) => ({
        id: e.id,
        createdAt: toLocalIso(new Date(now - e.agoMs)),
        source: e.source,
        imageRef: e.imageRef,
        predictions: e.predictions.map((p) => ({
          class: p.class,
          confidence: p.confidence,
        })),
      }));

      // Double-encode: the array → JSON string → json.encode wrapper.
      const stored = JSON.stringify(JSON.stringify(records));
      window.localStorage.setItem(data.key, stored);
    },
    { key: HISTORY_STORAGE_KEY, entries },
  );
}

/** Common relative-time offsets for readable, distinct fixtures. */
export const MINUTE_MS = 60 * 1000;
export const HOUR_MS = 60 * MINUTE_MS;
