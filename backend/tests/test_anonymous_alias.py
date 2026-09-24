"""随机 anonymous nicknames come from one server-side word list."""
from __future__ import annotations

from http import HTTPStatus

from tests.test_logic_regressions import FakeJsonHandler, _user


def test_alias_fits_the_limit_and_varies():
    from handlers import _post_handler

    aliases = {_post_handler.random_anonymous_alias({"sensitiveWords": []}) for _ in range(200)}
    assert len(aliases) > 50, "successive 随机 taps should differ"
    assert all(0 < len(alias) <= 24 for alias in aliases)


def test_alias_avoids_sensitive_words():
    from handlers import _post_handler

    db = {"sensitiveWords": ["鹿", "风", "猫"]}
    for _ in range(100):
        alias = _post_handler.random_anonymous_alias(db)
        assert not any(word in alias for word in db["sensitiveWords"])


def test_alias_falls_back_when_every_candidate_is_blocked():
    from handlers import _post_handler

    assert _post_handler.random_anonymous_alias({"sensitiveWords": ["的"]}) == "匿名同学"


def test_endpoint_requires_sign_in_and_returns_an_alias(monkeypatch):
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    handler = FakeJsonHandler()  # no Authorization header
    _post_handler.handle_get_random_anonymous_alias(handler, db)
    assert handler.status_code == HTTPStatus.UNAUTHORIZED

    me = _user("me", "2500300@stu.xidian.edu.cn")
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: me)
    handler = FakeJsonHandler()
    _post_handler.handle_get_random_anonymous_alias(handler, db)
    assert handler.status_code == HTTPStatus.OK
    assert handler.payload()["data"]["alias"]
