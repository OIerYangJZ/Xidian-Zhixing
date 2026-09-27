/**
 * Responsive sources for images served by GET /api/storage/<key>.
 *
 * The backend renders WebP variants at fixed widths (keep VARIANT_WIDTHS in
 * step with backend/helpers/_image_variants.py) and snaps any other ?w= up to
 * the next one.  Anything that is not an /api/storage URL — bundled assets in
 * public/, blob: previews of files still being picked — is left alone.
 */
export const VARIANT_WIDTHS = [320, 640, 960, 1280, 1920] as const;

function isStorageUrl(src: string): boolean {
  return src.startsWith('/api/storage/');
}

/** `src` at (at least) `width` pixels wide. */
export function sizedSrc(src: string | null | undefined, width: number): string {
  if (!src) return '';
  if (!isStorageUrl(src)) return src;
  const separator = src.includes('?') ? '&' : '?';
  return `${src}${separator}w=${width}`;
}

/**
 * Props to spread on an <img>: a srcset over the variant ladder plus `sizes`,
 * so the browser downloads the smallest variant that fills the box.
 */
export function responsiveImage(
  src: string | null | undefined,
  sizes: string,
): { src: string; srcSet?: string; sizes?: string } {
  if (!src) return { src: '' };
  if (!isStorageUrl(src)) return { src };
  return {
    src: sizedSrc(src, 960),
    srcSet: VARIANT_WIDTHS.map((width) => `${sizedSrc(src, width)} ${width}w`).join(', '),
    sizes,
  };
}

/** Avatars render small everywhere; one 2x-density variant covers them. */
export function avatarSrc(src: string | null | undefined): string {
  return sizedSrc(src, 320);
}
