"""Reposts, post/comment edits, @-mentions and the activity feed."""
from __future__ import annotations

from http import HTTPStatus
from pathlib import Path
from typing import Any

import pytest

from tests.test_logic_regressions import FakeJsonHandler, _user

NOTIFY_ALL = {
    "notifyComment": True, "notifyReply": True, "notifyLike": True,
    "notifyFavorite": True, "notifyReportResult": True, "notifySystem": True,
}


def _person(user_id: str, number: str, nickname: str) -> dict[str, Any]:
    return {**_user(user_id, f"{number}@stu.xidian.edu.cn"), **NOTIFY_ALL, "nickname": nickname, "alias": nickname}


def _post(post_id: str, author_id: str, **extra: Any) -> dict[str, Any]:
    return {
        "id": post_id,
        "authorId": author_id,
        "authorAlias": author_id,
        "title": f"标题{post_id}",
        "content": "正文",
        "tags": [],
        "deleted": False,
        "reviewStatus": "approved",
        "visibility": "public",
        "isAnonymous": False,
        "createdAt": f"2026-09-2{post_id[-1]}T00:00:00+00:00",
        "updatedAt": "2026-09-20T00:00:00+00:00",
        **extra,
    }


@pytest.fixture
def world(monkeypatch: pytest.MonkeyPatch) -> dict[str, Any]:
    from handlers import _post_handler, _social_handler
    from services._db_service import default_db

    db = default_db()
    alice = _person("alice", "2500500", "阿丽")
    bob = _person("bob", "2500501", "小波")
    carol = _person("carol", "2500502", "卡萝")
    db["users"].extend([alice, bob, carol])
    db["posts"] = [
        _post("p1", "bob"),
        _post("p2", "bob", isAnonymous=True, authorAlias="匿名猫"),
        _post("p3", "alice"),
        _post("p4", "bob", visibility="private"),
        _post("p5", "carol", reviewStatus="rejected"),
    ]
    db["comments"] = [
        {"id": "cm1", "postId": "p3", "userId": "bob", "authorAlias": "小波", "content": "原评论",
         "deleted": False, "reviewStatus": "approved", "createdAt": "2026-09-24T00:00:00+00:00"},
    ]
    viewer = {"current": alice}
    for module in (_post_handler, _social_handler):
        monkeypatch.setattr(module, "auth_user_helper", lambda _h, _db: (viewer["current"], "token"))
        monkeypatch.setattr(module, "save_db", lambda _db: None)
    return {"db": db, "as": lambda user: viewer.update(current=user), "alice": alice, "bob": bob, "carol": carol}


def _call(fn: Any, *args: Any, body: dict[str, Any] | None = None, query: dict[str, list[str]] | None = None) -> FakeJsonHandler:
    handler = FakeJsonHandler()
    handler.headers["Content-Length"] = "0"
    if body is not None:
        handler._cached_json_body = body  # type: ignore[attr-defined]
    if query is not None:
        fn(handler, *args, query)
    else:
        fn(handler, *args)
    return handler


def _notifications(db: dict[str, Any], user_id: str, kind: str) -> list[dict[str, Any]]:
    return [n for n in db["notifications"] if n["userId"] == user_id and n["type"] == kind]


# ---------------------------------------------------------------- reposts


def test_repost_toggles_counts_and_notifies_once(world: dict[str, Any]) -> None:
    from handlers import _social_handler
    from services import serialize_post

    db = world["db"]
    handler = _call(_social_handler.handle_toggle_repost, db, "p1", body={"reposted": True})
    assert handler.payload()["data"] == {"reposted": True, "repostCount": 1}
    # Asking again is idempotent: no second row, no second notification.
    _call(_social_handler.handle_toggle_repost, db, "p1", body={"reposted": True})
    assert len(db["reposts"]) == 1
    assert len(_notifications(db, "bob", "repost")) == 1
    post = next(p for p in db["posts"] if p["id"] == "p1")
    assert serialize_post(db, post, viewer_user_id="alice")["reposted"] is True
    assert serialize_post(db, post, viewer_user_id="carol")["repostCount"] == 1

    handler = _call(_social_handler.handle_toggle_repost, db, "p1", body={"reposted": False})
    assert handler.payload()["data"] == {"reposted": False, "repostCount": 0}
    assert db["reposts"] == []


def test_repost_refuses_what_it_would_expose(world: dict[str, Any]) -> None:
    from handlers import _social_handler

    db = world["db"]
    world["as"](world["bob"])
    # Reposting one's own anonymous post would put a name on it.
    handler = _call(_social_handler.handle_toggle_repost, db, "p2", body={})
    assert handler.status_code == HTTPStatus.BAD_REQUEST
    handler = _call(_social_handler.handle_toggle_repost, db, "p4", body={})
    assert handler.status_code == HTTPStatus.BAD_REQUEST
    world["as"](world["alice"])
    # Someone else's private post and a rejected post are simply not there.
    assert _call(_social_handler.handle_toggle_repost, db, "p4", body={}).status_code == HTTPStatus.NOT_FOUND
    assert _call(_social_handler.handle_toggle_repost, db, "p5", body={}).status_code == HTTPStatus.NOT_FOUND
    assert db["reposts"] == []


def test_timeline_merges_reposts_and_hides_anonymous_authorship(world: dict[str, Any]) -> None:
    from handlers import _social_handler

    db = world["db"]
    db["reposts"] = [
        {"userId": "bob", "postId": "p3", "createdAt": "2026-09-29T00:00:00+00:00"},
        # A stray row for bob's own anonymous post must never surface.
        {"userId": "bob", "postId": "p2", "createdAt": "2026-09-28T00:00:00+00:00"},
    ]
    handler = _call(_social_handler.handle_get_timeline, db, "bob", query={"page": ["1"], "limit": ["10"]})
    items = handler.payload()["data"]["items"]
    assert [(item["id"], bool(item["repostedBy"])) for item in items] == [("p3", True), ("p1", False)]
    assert items[0]["repostedBy"]["nickname"] == "小波"

    # The author sees their own anonymous post; the stray repost stays hidden.
    world["as"](world["bob"])
    items = _call(_social_handler.handle_get_timeline, db, "bob", query={}).payload()["data"]["items"]
    assert [item["eventKey"] for item in items] == ["repost:bob:p3", "post:p4", "post:p2", "post:p1"]


def test_reposts_and_like_times_survive_a_save(tmp_path: Path) -> None:
    from services._db_service import default_db
    from sql_repository import SqliteTreeholeRepository

    repo = SqliteTreeholeRepository(tmp_path / "social.db")
    repo.initialize(default_db)
    db = repo.load_state()
    db["users"].extend([_person("alice", "2500500", "阿丽"), _person("bob", "2500501", "小波")])
    db["posts"] = [_post("p1", "bob", mentions=[{"userId": "alice", "nickname": "阿丽"}], editedAt="2026-09-27T01:00:00+00:00")]
    db["reposts"] = [{"userId": "alice", "postId": "p1", "createdAt": "2026-09-27T02:00:00+00:00"}]
    db["likes"] = [{"userId": "alice", "postId": "p1", "createdAt": "2026-09-01T00:00:00+00:00"}]
    db["favorites"] = [{"userId": "alice", "postId": "p1", "createdAt": "2026-09-02T00:00:00+00:00"}]
    repo.save_state(db)

    again = repo.load_state()
    assert again["reposts"] == db["reposts"]
    assert again["likes"][0]["createdAt"] == "2026-09-01T00:00:00+00:00"
    assert again["favorites"][0]["createdAt"] == "2026-09-02T00:00:00+00:00"
    post = again["posts"][0]
    assert post["mentions"] == [{"userId": "alice", "nickname": "阿丽"}]
    assert post["editedAt"] == "2026-09-27T01:00:00+00:00"

    # Undoing a repost has to reach the database, not just the dict.
    again["reposts"] = []
    repo.save_state(again)
    assert repo.load_state()["reposts"] == []


# ---------------------------------------------------------------- editing


def test_author_edits_title_and_text(world: dict[str, Any]) -> None:
    from handlers import _post_handler

    db = world["db"]
    handler = _call(_post_handler.handle_update_post, db, "p3", body={"title": "新标题", "content": "改过的正文 #新话题"})
    data = handler.payload()["data"]
    assert (data["title"], data["content"]) == ("新标题", "改过的正文 #新话题")
    assert data["editedAt"] and "新话题" in data["tags"]
    # Status updates keep working and do not count as an edit.
    before = data["editedAt"]
    data = _call(_post_handler.handle_update_post, db, "p3", body={"status": "resolved"}).payload()["data"]
    assert data["status"] == "resolved" and data["editedAt"] == before


def test_only_the_author_edits(world: dict[str, Any]) -> None:
    from handlers import _post_handler

    handler = _call(_post_handler.handle_update_post, world["db"], "p1", body={"content": "我来改"})
    assert handler.status_code == HTTPStatus.FORBIDDEN
    handler = _call(_post_handler.handle_update_comment, world["db"], "cm1", body={"content": "我来改"})
    assert handler.status_code == HTTPStatus.FORBIDDEN


def test_editing_removes_dropped_images(world: dict[str, Any], monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _post_handler

    db = world["db"]
    db["mediaUploads"] = [
        {"id": "up1", "objectKey": "aa/1.png", "uploaderId": "alice", "postId": "p3", "status": "approved", "url": "/api/storage/aa/1.png"},
        {"id": "up2", "objectKey": "aa/2.png", "uploaderId": "alice", "postId": "p3", "status": "approved", "url": "/api/storage/aa/2.png"},
        {"id": "up3", "objectKey": "aa/3.png", "uploaderId": "alice", "postId": "", "status": "approved", "url": "/api/storage/aa/3.png"},
    ]
    deleted: list[list[str]] = []
    monkeypatch.setattr(_post_handler, "delete_objects_with_backups", lambda _s, keys: deleted.append(keys) or [])
    data = _call(_post_handler.handle_update_post, db, "p3", body={"imageUploadIds": ["up2", "up3"]}).payload()["data"]
    assert data["uploadedImageIds"] == ["up2", "up3"]
    assert deleted == [["aa/1.png"]]
    assert next(u for u in db["mediaUploads"] if u["id"] == "up1")["deleted"] is True


def test_a_risky_edit_goes_back_to_review(world: dict[str, Any], monkeypatch: pytest.MonkeyPatch) -> None:
    from handlers import _post_handler

    monkeypatch.setattr(_post_handler, "assess_text_risk", lambda *_a, **_k: (True, False, ["疑似导流"]))
    data = _call(_post_handler.handle_update_post, world["db"], "p3", body={"content": "加我联系"}).payload()["data"]
    assert data["reviewStatus"] == "pending"


def test_comment_edit(world: dict[str, Any]) -> None:
    from handlers import _post_handler

    world["as"](world["bob"])
    data = _call(_post_handler.handle_update_comment, world["db"], "cm1", body={"content": "改过的评论"}).payload()["data"]
    assert data["content"] == "改过的评论" and data["editedAt"]


# ---------------------------------------------------------------- mentions


def test_mentions_need_the_name_in_the_text(world: dict[str, Any]) -> None:
    from handlers._social_handler import resolve_mentions

    db = world["db"]
    found = resolve_mentions(db, "alice", "你好 @小波", ["bob", "carol", "alice", "nobody"])
    # carol is not named in the text, alice is the author, nobody does not exist.
    assert found == [{"userId": "bob", "nickname": "小波"}]
    db["userBlocks"] = [{"blockerUserId": "bob", "blockedUserId": "alice"}]
    assert resolve_mentions(db, "alice", "你好 @小波", ["bob"]) == []


def test_anonymous_mentions_do_not_name_the_author(world: dict[str, Any]) -> None:
    from handlers._social_handler import notify_mentions

    db = world["db"]
    notify_mentions(
        db, [{"userId": "bob", "nickname": "小波"}], author=world["alice"], anonymous=True,
        actor_alias="匿名猫", snippet="@小波 看这里", post_id="p3",
    )
    [row] = _notifications(db, "bob", "mention")
    assert row["actorId"] == "" and row["actorAlias"] == "匿名猫"


def test_an_edit_only_notifies_newly_mentioned(world: dict[str, Any]) -> None:
    from handlers import _post_handler

    db = world["db"]
    _call(_post_handler.handle_update_post, db, "p3", body={"content": "@小波 你好", "mentionUserIds": ["bob"]})
    _call(_post_handler.handle_update_post, db, "p3", body={"content": "@小波 @卡萝 你好", "mentionUserIds": ["bob", "carol"]})
    assert len(_notifications(db, "bob", "mention")) == 1
    assert len(_notifications(db, "carol", "mention")) == 1


def test_mention_categories_are_listed(world: dict[str, Any]) -> None:
    from handlers._notification_handler import NOTIFICATION_CATEGORIES, notification_category

    assert {"repost", "mention"} <= set(NOTIFICATION_CATEGORIES)
    assert notification_category("mention") == "mention"


# ---------------------------------------------------------------- activity


def test_activity_lists_my_actions_newest_first(world: dict[str, Any]) -> None:
    from handlers import _social_handler

    db = world["db"]
    db["likes"] = [
        {"userId": "alice", "postId": "p1", "createdAt": "2026-09-26T01:00:00+00:00"},
        {"userId": "alice", "commentId": "cm1", "createdAt": "2026-09-26T02:00:00+00:00"},
        # A like on a post since rejected stays out of the list.
        {"userId": "alice", "postId": "p5", "createdAt": "2026-09-26T03:00:00+00:00"},
    ]
    db["favorites"] = [{"userId": "alice", "postId": "p1", "createdAt": "2026-09-26T04:00:00+00:00"}]
    db["reposts"] = [{"userId": "alice", "postId": "p1", "createdAt": "2026-09-26T05:00:00+00:00"}]
    db["userFollows"] = [{"followerUserId": "alice", "followeeUserId": "bob", "createdAt": "2026-09-26T06:00:00+00:00"}]
    items = _call(_social_handler.handle_get_my_activity, db, query={"limit": ["20"]}).payload()["data"]["items"]
    assert [item["type"] for item in items] == ["follow", "repost", "favorite", "like_comment", "like_post", "post"]
    assert items[0]["user"] == {"userId": "bob", "nickname": "小波"}
    assert items[3]["post"]["id"] == "p3"


def test_repost_and_mention_have_their_own_switches(world: dict[str, Any]) -> None:
    from handlers import _social_handler
    from handlers._social_handler import notify_mentions

    db = world["db"]
    world["bob"]["notifyRepost"] = False
    # Turning likes off must not silence reposts, and the other way round.
    world["carol"]["notifyLike"] = False
    _call(_social_handler.handle_toggle_repost, db, "p1", body={"reposted": True})
    assert _notifications(db, "bob", "repost") == []

    world["bob"]["notifyMention"] = False
    world["carol"]["notifyReply"] = False
    mentions = [{"userId": "bob", "nickname": "小波"}, {"userId": "carol", "nickname": "卡萝"}]
    notify_mentions(db, mentions, author=world["alice"], anonymous=False, actor_alias="阿丽", snippet="@小波 @卡萝", post_id="p3")
    assert _notifications(db, "bob", "mention") == []
    assert len(_notifications(db, "carol", "mention")) == 1


def test_new_switches_round_trip(tmp_path: Path) -> None:
    from services._db_service import default_db
    from sql_repository import SqliteTreeholeRepository

    repo = SqliteTreeholeRepository(tmp_path / "prefs.db")
    repo.initialize(default_db)
    db = repo.load_state()
    db["users"].append({**_person("alice", "2500500", "阿丽"), "notifyRepost": False, "notifyMention": True})
    repo.save_state(db)
    alice = next(u for u in repo.load_state()["users"] if u["id"] == "alice")
    assert (alice["notifyRepost"], alice["notifyMention"]) == (False, True)
