"""
helpers/_image_variants.py

Width-limited WebP renditions for GET /api/storage/<key>?w=<width>.

The web frontend's <Image> components ask for a width from a fixed ladder and
let the browser pick one from srcset, which is what next/image does on a Node
server.  Here the backend renders the variant with Pillow and keeps it on disk
next to the originals, so each (object, width) pair is encoded once.
"""
from __future__ import annotations

import io
import logging
import threading
from pathlib import Path

logger = logging.getLogger(__name__)

# The frontend's image loader only asks for these, so an arbitrary ?w= cannot
# make the server encode a new size per request.  Keep in step with
# deviceSizes / imageSizes in the web frontend's next.config.
VARIANT_WIDTHS = (320, 640, 960, 1280, 1920)
VARIANT_DIR_NAME = "_variants"
_WEBP_QUALITY = 80
# Anything larger than this is refused rather than decoded; well above any
# phone photo, well below what would exhaust the process.
_MAX_SOURCE_PIXELS = 50_000_000
# GIFs may be animated and SVG is not raster; both are served as uploaded.
_RESIZABLE_TYPES = frozenset({"image/jpeg", "image/png", "image/webp"})

_render_lock = threading.Lock()


def snap_width(raw: str) -> int | None:
    """Map a requested width onto the ladder: the smallest step that covers it."""
    try:
        requested = int(str(raw).strip())
    except (TypeError, ValueError):
        return None
    if requested <= 0:
        return None
    for width in VARIANT_WIDTHS:
        if width >= requested:
            return width
    return VARIANT_WIDTHS[-1]


def variant_path(root_dir: Path, object_key: str, width: int) -> Path:
    # Object keys are token_hex(2)/token_hex(16)<suffix>, so a top-level
    # "_variants" directory cannot collide with an original.
    return root_dir / VARIANT_DIR_NAME / str(width) / f"{object_key}.webp"


def delete_variants(root_dir: Path, object_key: str) -> None:
    for width in VARIANT_WIDTHS:
        path = variant_path(root_dir, object_key, width)
        try:
            path.unlink()
        except FileNotFoundError:
            continue
        except OSError:
            logger.warning("could not delete image variant %s", path, exc_info=True)


def render_variant(data: bytes, content_type: str, width: int) -> bytes | None:
    """Return WebP bytes no wider than `width`, or None to serve the original.

    None covers everything that should not be re-encoded: types outside
    _RESIZABLE_TYPES, images already narrower than the request, and anything
    Pillow cannot decode.
    """
    if str(content_type or "").lower() not in _RESIZABLE_TYPES:
        return None
    try:
        from PIL import Image, ImageOps
    except ImportError:
        logger.warning("Pillow is not installed; serving original images")
        return None

    try:
        with Image.open(io.BytesIO(data)) as image:
            if image.width * image.height > _MAX_SOURCE_PIXELS:
                return None
            if image.width <= width:
                return None
            image = ImageOps.exif_transpose(image)
            height = max(1, round(image.height * width / image.width))
            if image.mode not in ("RGB", "RGBA"):
                image = image.convert("RGBA" if "A" in image.getbands() else "RGB")
            resized = image.resize((width, height), Image.Resampling.LANCZOS)
            out = io.BytesIO()
            resized.save(out, format="WEBP", quality=_WEBP_QUALITY, method=4)
            return out.getvalue()
    except Exception:  # corrupt or hostile upload: fall back to the original
        logger.warning("could not render %spx image variant", width, exc_info=True)
        return None


def cached_variant(
    root_dir: Path | None,
    object_key: str,
    data: bytes,
    content_type: str,
    width: int,
) -> bytes | None:
    """render_variant with an on-disk cache when storage is local.

    `root_dir` is None for non-local storage, in which case the variant is
    rendered per request.
    """
    if root_dir is None:
        return render_variant(data, content_type, width)
    path = variant_path(root_dir, object_key, width)
    if path.is_file():
        return path.read_bytes()
    # One render at a time: a burst of first views of a large photo would
    # otherwise decode it once per request thread.
    with _render_lock:
        if path.is_file():
            return path.read_bytes()
        rendered = render_variant(data, content_type, width)
        if rendered is None:
            return None
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".webp.tmp")
        tmp.write_bytes(rendered)
        tmp.replace(path)
        return rendered
