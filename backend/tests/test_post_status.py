"""A post's 状态: optional, set and changed by its author only."""
from __future__ import annotations

from http import HTTPStatus
from typing import Any

import pytest

from tests.test_social import _call, world  # noqa: F401  (fixture)


def _create(handler_module: Any, db: dict[str, Any], **body: Any) -> Any:
    return _call(handler_module.handle_create_post, db, body={"title": "t", "content": "正文", **body})


def test_status_is_optional_when_posting(world: dict[str, Any]) -> None:
    from handlers import _post_handler

    db = world["db"]
    assert _create(_post_handler, db).payload()["data"]["status"] == "none"
    assert _create(_post_handler, db, status="").payload()["data"]["status"] == "none"
    assert _create(_post_handler, db, status="resolved").payload()["data"]["status"] == "resolved"
    # The old alias still works.
    assert _create(_post_handler, db, status="open").payload()["data"]["status"] == "ongoing"
    assert _create(_post_handler, db, status="done").status_code == HTTPStatus.BAD_REQUEST


@pytest.mark.parametrize("path", [("none", "ongoing"), ("ongoing", "resolved"), ("resolved", "ongoing"),
                                  ("ongoing", "closed"), ("closed", "none")])
def test_the_author_moves_between_any_statuses(world: dict[str, Any], path: tuple[str, str]) -> None:
    from handlers import _post_handler

    db = world["db"]
    post = next(p for p in db["posts"] if p["id"] == "p3")
    post["status"] = path[0]
    data = _call(_post_handler.handle_update_post, db, "p3", body={"status": path[1]}).payload()["data"]
    assert data["status"] == path[1]


def test_only_the_author_changes_the_status(world: dict[str, Any]) -> None:
    from handlers import _post_handler

    # p1 is bob's; alice is signed in.
    handler = _call(_post_handler.handle_update_post, world["db"], "p1", body={"status": "resolved"})
    assert handler.status_code == HTTPStatus.FORBIDDEN
    assert _call(_post_handler.handle_update_post, world["db"], "p3", body={"status": "nope"}).status_code == HTTPStatus.BAD_REQUEST
