import { expect, type Locator } from '@playwright/test';
import { PNG } from 'pngjs';

// Flutter Web renders to a CanvasKit canvas, so a painted image leaves no DOM
// `<img>` for Playwright to assert against. To prove a thumbnail/preview shows a
// *real* car photo (T020) rather than the flat car placeholder, we screenshot a
// small region and inspect its pixels: a decoded JPEG has hundreds of distinct
// colours, while the placeholder is a near-flat grey fill with a single-hue
// (grey) icon. Counting distinct colours cleanly separates the two.

/** Count the number of distinct RGB values in a PNG screenshot buffer. */
export function distinctColorCount(buffer: Buffer): number {
  const png = PNG.sync.read(buffer);
  const seen = new Set<number>();
  const { data } = png;
  for (let i = 0; i < data.length; i += 4) {
    seen.add((data[i] << 16) | (data[i + 1] << 8) | data[i + 2]);
  }
  return seen.size;
}

/**
 * Assert that the left-hand thumbnail of a history tile actually paints a photo.
 *
 * Screenshots a small square well inside the 56 px thumbnail (which sits at the
 * left of the tile, vertically centred) and requires the rendered region to be
 * colour-rich — far more than the handful of greys a placeholder produces.
 */
export async function assertThumbnailPainted(
  tile: Locator,
  { minColors = 100 }: { minColors?: number } = {},
): Promise<number> {
  const box = await tile.boundingBox();
  if (!box) throw new Error('history tile has no bounding box');

  const clip = {
    x: box.x + 14,
    y: box.y + box.height / 2 - 12,
    width: 28,
    height: 24,
  };

  const buffer = await tile.page().screenshot({ clip });
  const colors = distinctColorCount(buffer);
  expect(
    colors,
    `expected the thumbnail to render a real car photo (got ${colors} distinct colours, ` +
      `a placeholder would have far fewer)`,
  ).toBeGreaterThanOrEqual(minColors);
  return colors;
}
