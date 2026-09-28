"""GET /api/storage/<key>?w=<width> serves cached, resized WebP renditions."""
from __future__ import annotations

import io
from http import HTTPStatus
from pathlib import Path
from typing import Any

import pytest

from tests.test_logic_regressions import FakeJsonHandler

PIL = pytest.importorskip("PIL")
from PIL import Image  # noqa: E402


def _image_bytes(width: int, height: int, fmt: str = "JPEG") -> bytes:
    out = io.BytesIO()
    Image.new("RGB", (width, height), (200, 80, 40)).save(out, format=fmt)
    return out.getvalue()


def _decoded(data: bytes) -> Image.Image:
    return Image.open(io.BytesIO(data))


@pytest.mark.parametrize(
    ("raw", "expected"),
    [("1", 320), ("320", 320), ("321", 640), ("1280", 1280), ("99999", 1920),
     ("0", None), ("-5", None), ("abc", None), ("", None)],
)
def test_snap_width_rounds_up_to_the_ladder(raw: str, expected: int | None) -> None:
    from helpers._image_variants import snap_width

    assert snap_width(raw) == expected


def test_render_shrinks_to_the_width_and_keeps_the_aspect() -> None:
    from helpers._image_variants import render_variant

    rendered = render_variant(_image_bytes(2000, 1000), "image/jpeg", 640)
    assert rendered is not None
    image = _decoded(rendered)
    assert image.format == "WEBP"
    assert image.size == (640, 320)


@pytest.mark.parametrize(
    ("data", "content_type"),
    [
        (_image_bytes(500, 500), "image/jpeg"),  # already narrower: serve as-is
        (_image_bytes(2000, 1000, "GIF"), "image/gif"),  # may be animated
        (b"<svg/>", "image/svg+xml"),
        (b"not an image", "image/png"),
    ],
)
def test_render_leaves_what_it_should_not_touch(data: bytes, content_type: str) -> None:
    from helpers._image_variants import render_variant

    assert render_variant(data, content_type, 640) is None


def test_cached_variant_encodes_once(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    from helpers import _image_variants

    calls: list[int] = []
    real = _image_variants.render_variant

    def counting(*args: Any) -> Any:
        calls.append(1)
        return real(*args)

    monkeypatch.setattr(_image_variants, "render_variant", counting)
    source = _image_bytes(2000, 1000)
    first = _image_variants.cached_variant(tmp_path, "ab12/key.jpg", source, "image/jpeg", 640)
    second = _image_variants.cached_variant(tmp_path, "ab12/key.jpg", source, "image/jpeg", 640)
    assert first == second and first is not None
    assert len(calls) == 1
    assert (tmp_path / "_variants" / "640" / "ab12" / "key.jpg.webp").is_file()


def test_deleting_an_object_deletes_its_variants(tmp_path: Path) -> None:
    from helpers._image_variants import cached_variant
    from object_storage import LocalObjectStorage

    storage = LocalObjectStorage(root_dir=tmp_path)
    stored = storage.put_bytes(data=_image_bytes(2000, 1000), file_name="a.jpg", content_type="image/jpeg")
    for width in (320, 640):
        assert cached_variant(tmp_path, stored.key, _image_bytes(2000, 1000), "image/jpeg", width)
    storage.delete(stored.key)
    assert list((tmp_path / "_variants").rglob("*.webp")) == []


def test_storage_get_serves_the_variant_after_the_visibility_check(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    import _globals
    from handlers import _static_handler
    from object_storage import LocalObjectStorage

    storage = LocalObjectStorage(root_dir=tmp_path)
    monkeypatch.setattr(_globals, "OBJECT_STORAGE", storage)
    monkeypatch.setattr(_static_handler, "auth_user_helper", lambda _h, _db: (None, None))
    visible = storage.put_bytes(data=_image_bytes(2000, 1000), file_name="a.jpg", content_type="image/jpeg")
    pending = storage.put_bytes(data=_image_bytes(2000, 1000), file_name="b.jpg", content_type="image/jpeg")
    db = {
        "mediaUploads": [
            {"objectKey": visible.key, "status": "approved"},
            {"objectKey": pending.key, "status": "pending"},
        ],
        "posts": [],
        "users": [],
    }

    handler = FakeJsonHandler()
    assert _static_handler.handle_storage_get(handler, f"/api/storage/{visible.key}", db, {"w": ["600"]})
    assert handler.status_code == HTTPStatus.OK
    assert ("Content-Type", "image/webp") in handler.response_headers
    assert _decoded(handler.wfile.getvalue()).size == (640, 320)

    # Without ?w the original is untouched.
    handler = FakeJsonHandler()
    assert _static_handler.handle_storage_get(handler, f"/api/storage/{visible.key}", db)
    assert ("Content-Type", "image/jpeg") in handler.response_headers

    # A width does not get around moderation.
    handler = FakeJsonHandler()
    assert not _static_handler.handle_storage_get(handler, f"/api/storage/{pending.key}", db, {"w": ["640"]})
    assert not (tmp_path / "_variants" / "640" / f"{pending.key}.webp").exists()


def test_a_sideways_photo_is_not_upscaled() -> None:
    from helpers._image_variants import render_variant

    # Stored 2000×1000, shown 1000×2000 (EXIF orientation 6).
    image = Image.new("RGB", (2000, 1000), (200, 80, 40))
    exif = image.getexif()
    exif[0x0112] = 6
    out = io.BytesIO()
    image.save(out, format="JPEG", exif=exif.tobytes())
    assert render_variant(out.getvalue(), "image/jpeg", 1280) is None
    rendered = render_variant(out.getvalue(), "image/jpeg", 640)
    assert rendered is not None and _decoded(rendered).size == (640, 1280)


def test_non_local_storage_keeps_variants_in_memory(monkeypatch: pytest.MonkeyPatch) -> None:
    from helpers import _image_variants

    calls: list[int] = []
    real = _image_variants.render_variant
    monkeypatch.setattr(_image_variants, "render_variant", lambda *a: calls.append(1) or real(*a))
    source = _image_bytes(2000, 1000)
    first = _image_variants.cached_variant(None, "s3/key.jpg", source, "image/jpeg", 640)
    assert _image_variants.cached_variant(None, "s3/key.jpg", source, "image/jpeg", 640) == first
    assert len(calls) == 1
    _image_variants.forget_memory_variants("s3/key.jpg")
    _image_variants.cached_variant(None, "s3/key.jpg", source, "image/jpeg", 640)
    assert len(calls) == 2
