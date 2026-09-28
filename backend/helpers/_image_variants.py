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
from collections import OrderedDict
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

# Renders running at once, across all images: each can hold a decoded
# 50 MP frame, so an unbounded burst of first views could exhaust memory.
_render_slots = threading.BoundedSemaphore(2)
# Per (object, width): concurrent first views of the same photo wait for
# one render instead of each decoding it; other photos proceed.
_key_locks: dict[tuple[str, int], threading.Lock] = {}
_key_locks_guard = threading.Lock()
# Non-local storage has no disk cache; keep recent variants in memory.
_MEMORY_CACHE_BYTES = 32 * 1024 * 1024
_memory_cache: OrderedDict[tuple[str, int], bytes] = OrderedDict()
_memory_cache_size = 0
_memory_cache_guard = threading.Lock()
# EXIF orientations 5-8 turn the picture a quarter, swapping width and height.
_QUARTER_TURN_ORIENTATIONS = frozenset({5, 6, 7, 8})


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
            # The width as displayed, after the EXIF rotation, so a portrait
            # photo stored sideways is never upscaled.
            orientation = image.getexif().get(0x0112)
            shown_width = image.height if orientation in _QUARTER_TURN_ORIENTATIONS else image.width
            if shown_width <= width:
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

    `root_dir` is None for non-local storage, in which case recent variants
    are kept in a small in-memory cache instead.
    """
    cache_key = (object_key, width)
    if root_dir is None:
        cached = _memory_get(cache_key)
        if cached is not None:
            return cached
        with _key_lock(cache_key):
            cached = _memory_get(cache_key)
            if cached is not None:
                return cached
            with _render_slots:
                rendered = render_variant(data, content_type, width)
            if rendered is not None:
                _memory_put(cache_key, rendered)
            return rendered

    path = variant_path(root_dir, object_key, width)
    if path.is_file():
        return path.read_bytes()
    with _key_lock(cache_key):
        if path.is_file():
            return path.read_bytes()
        with _render_slots:
            rendered = render_variant(data, content_type, width)
        if rendered is None:
            return None
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(f".webp.tmp-{threading.get_ident()}")
        tmp.write_bytes(rendered)
        tmp.replace(path)
        return rendered


def _key_lock(cache_key: tuple[str, int]) -> threading.Lock:
    # Locks are tiny and keys are bounded by uploads × 5 widths, so they are
    # kept rather than reference-counted.
    with _key_locks_guard:
        lock = _key_locks.get(cache_key)
        if lock is None:
            lock = _key_locks[cache_key] = threading.Lock()
        return lock


def _memory_get(cache_key: tuple[str, int]) -> bytes | None:
    with _memory_cache_guard:
        data = _memory_cache.get(cache_key)
        if data is not None:
            _memory_cache.move_to_end(cache_key)
        return data


def _memory_put(cache_key: tuple[str, int], data: bytes) -> None:
    global _memory_cache_size
    if len(data) > _MEMORY_CACHE_BYTES // 4:
        return
    with _memory_cache_guard:
        previous = _memory_cache.pop(cache_key, None)
        if previous is not None:
            _memory_cache_size -= len(previous)
        _memory_cache[cache_key] = data
        _memory_cache_size += len(data)
        while _memory_cache_size > _MEMORY_CACHE_BYTES:
            _, evicted = _memory_cache.popitem(last=False)
            _memory_cache_size -= len(evicted)


def forget_memory_variants(object_key: str) -> None:
    """Drop an object's in-memory variants (non-local storage deletes)."""
    global _memory_cache_size
    with _memory_cache_guard:
        for width in VARIANT_WIDTHS:
            evicted = _memory_cache.pop((object_key, width), None)
            if evicted is not None:
                _memory_cache_size -= len(evicted)
