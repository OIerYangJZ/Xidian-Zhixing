from __future__ import annotations

import io
import json
import secrets
from datetime import timedelta
from http import HTTPStatus
from typing import Any

import pytest

import server  # noqa: F401  # Configures shared backend globals for direct handler tests.


class FakeJsonHandler:
    def __init__(self) -> None:
        self.headers: dict[str, str] = {}
        self.wfile = io.BytesIO()
        self.status_code = 0
        self.response_headers: list[tuple[str, str]] = []
        self.request_id = "logic-regression"
        self.client_address = ("127.0.0.1", 23456)

    def send_response(self, code: int) -> None:
        self.status_code = code

    def send_header(self, key: str, value: str) -> None:
        self.response_headers.append((key, value))

    def end_headers(self) -> None:
        pass

    def payload(self) -> dict[str, Any]:
        return json.loads(self.wfile.getvalue().decode("utf-8"))


def _user(user_id: str, email: str) -> dict[str, Any]:
    return {
        "id": user_id,
        "email": email,
        "password": "",
        "alias": user_id,
        "nickname": user_id,
        "studentId": email.split("@", 1)[0],
        "avatarUrl": "",
        "bio": "保留简介",
        "gender": "男",
        "college": "计算机学院",
        "major": "软件工程",
        "backgroundImageUrl": "https://example.com/background.png",
        "userLevel": 2,
        "verified": True,
        "verifiedAt": "",
        "allowStrangerDm": False,
        "showContactable": False,
        "notifyComment": False,
        "notifyReply": False,
        "notifyLike": False,
        "notifyFavorite": False,
        "notifyReportResult": False,
        "notifySystem": False,
        "createdAt": "2026-07-23T00:00:00+00:00",
        "deleted": False,
        "isAdmin": False,
        "banned": False,
        "muted": False,
    }


def _patch_admin(
    monkeypatch: pytest.MonkeyPatch,
    body: dict[str, Any],
) -> None:
    from handlers import _admin_handler

    admin = {
        "id": "",
        "adminId": "adm-test",
        "username": "admin",
        "role": "primary",
    }
    monkeypatch.setattr(_admin_handler, "_require_admin", lambda _h, _db: admin)
    monkeypatch.setattr(
        _admin_handler,
        "_require_primary_admin",
        lambda _h, _db: admin,
    )
    monkeypatch.setattr(_admin_handler, "read_json_body", lambda _h: body)
    monkeypatch.setattr(_admin_handler, "save_db", lambda _db: None)


def test_admin_ban_preserves_user_data_and_only_revokes_sessions(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    target = _user("ban-target", "2500101@stu.xidian.edu.cn")
    db["users"].append(target)
    db["sessions"]["active-token"] = target["id"]
    db["conversations"] = [{"id": "c1", "userId": target["id"]}]
    db["directMessages"] = [{"id": "m1", "senderUserId": target["id"]}]
    db["notifications"] = [{"id": "n1", "userId": target["id"]}]
    _patch_admin(monkeypatch, {"action": "ban", "reviewNote": "违规"})

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_user_action(handler, db, target["id"])

    assert handler.status_code == HTTPStatus.OK
    assert target["banned"] is True
    assert target["deleted"] is False
    assert target["verified"] is True
    assert "active-token" not in db["sessions"]
    assert [row["id"] for row in db["conversations"]] == ["c1"]
    assert [row["id"] for row in db["directMessages"]] == ["m1"]
    assert [row["id"] for row in db["notifications"]] == ["n1"]


def test_report_delete_really_deletes_target(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    owner = _user("report-owner", "2500102@stu.xidian.edu.cn")
    post = {
        "id": "reported-post",
        "authorId": owner["id"],
        "authorAlias": owner["nickname"],
        "deleted": False,
        "reviewStatus": "approved",
        "riskMarked": False,
    }
    db["users"].append(owner)
    db["posts"].append(post)
    db["reports"].append(
        {
            "id": "report-1",
            "targetType": "post",
            "targetId": post["id"],
            "status": "pending",
        }
    )
    _patch_admin(monkeypatch, {"action": "delete", "reviewNote": "确认违规"})

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_report_action(handler, db, "report-1")

    assert handler.status_code == HTTPStatus.OK
    assert post["deleted"] is True
    assert db["reports"][-1]["status"] == "resolved"


def test_approve_restore_records_approved_and_restores_account(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    target = _user("restore-target", "2500103@stu.xidian.edu.cn")
    target["deleted"] = True
    target["banned"] = True
    db["users"].append(target)
    appeal = {
        "id": "appeal-1",
        "userId": target["id"],
        "appealType": "account_restore",
        "status": "pending",
    }
    db["appeals"].append(appeal)
    _patch_admin(
        monkeypatch,
        {"action": "approve_restore", "reviewNote": "核验通过"},
    )

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_appeal_action(handler, db, appeal["id"])

    assert handler.status_code == HTTPStatus.OK
    assert appeal["status"] == "approved"
    assert target["deleted"] is False
    assert target["banned"] is False


@pytest.mark.parametrize(
    ("handler_name", "collection_name", "row"),
    [
        (
            "handle_admin_post_pin_request_action",
            "postPinRequests",
            {"id": "req", "postId": "missing", "status": "pending"},
        ),
        (
            "handle_admin_user_level_request_action",
            "userLevelRequests",
            {"id": "req", "userId": "missing", "status": "pending"},
        ),
        (
            "handle_admin_appeal_action",
            "appeals",
            {"id": "req", "userId": "missing", "status": "pending"},
        ),
        (
            "handle_admin_cancellation_action",
            "accountCancellationRequests",
            {"id": "req", "userId": "missing", "status": "pending"},
        ),
    ],
)
def test_invalid_admin_action_does_not_reject_pending_request(
    monkeypatch: pytest.MonkeyPatch,
    handler_name: str,
    collection_name: str,
    row: dict[str, Any],
) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    db[collection_name] = [dict(row)]
    _patch_admin(monkeypatch, {"action": "typo"})

    handler = FakeJsonHandler()
    getattr(_admin_handler, handler_name)(handler, db, "req")

    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert db[collection_name][0]["status"] == "pending"


def test_upload_rejects_foreign_post_before_storing_object(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _upload_handler
    from services._db_service import default_db

    db = default_db()
    attacker = _user("attacker", "2500104@stu.xidian.edu.cn")
    owner = _user("upload-owner", "2500105@stu.xidian.edu.cn")
    db["users"].extend([attacker, owner])
    db["posts"].append(
        {"id": "foreign-post", "authorId": owner["id"], "deleted": False}
    )
    monkeypatch.setattr(
        _upload_handler,
        "auth_user_helper",
        lambda _h, _db: (attacker, "token"),
    )
    monkeypatch.setattr(
        _upload_handler,
        "read_json_body",
        lambda _h: {
            "postId": "foreign-post",
            "imageDataBase64": "iVBORw0KGgoAAAAAAAAAAAAA=",
        },
    )

    handler = FakeJsonHandler()
    _upload_handler.handle_upload_image(handler, db)

    assert handler.status_code == HTTPStatus.FORBIDDEN
    assert db["mediaUploads"] == []


def test_password_reset_revokes_all_existing_user_sessions(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _auth_handler
    from helpers import hash_password, now_utc
    from services._db_service import default_db

    db = default_db()
    target = _user("reset-target", "2500106@stu.xidian.edu.cn")
    target["password"] = hash_password("old-password")
    db["users"].append(target)
    db["sessions"] = {"old-1": target["id"], "other": "another-user"}
    db["emailCodes"][f"reset::{target['email']}"] = {
        "code": "012345",
        "expiresAt": (now_utc() + timedelta(minutes=10)).isoformat(),
        "createdAt": now_utc().isoformat(),
        "recordId": "reset-record",
        "purpose": "password_reset",
        "attempts": 0,
        "usedAt": "",
    }
    monkeypatch.setattr(
        _auth_handler,
        "read_json_body",
        lambda _h: {
            "email": target["email"],
            "code": "012345",
            "newPassword": "new-password",
        },
    )
    monkeypatch.setattr(_auth_handler, "save_db", lambda _db: None)

    handler = FakeJsonHandler()
    _auth_handler.handle_password_reset(handler, db)

    assert handler.status_code == HTTPStatus.OK
    assert "old-1" not in db["sessions"]
    assert db["sessions"]["other"] == "another-user"


def test_random_code_uses_secrets_choice(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from helpers._auth_helpers import random_code

    calls: list[str] = []

    def choose(sequence: str) -> str:
        calls.append(sequence)
        return "0"

    monkeypatch.setattr(secrets, "choice", choose)

    assert random_code() == "000000"
    assert calls == ["0123456789"] * 6


def test_registration_rolls_back_user_when_smtp_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _auth_handler
    from services._db_service import default_db

    db = default_db()
    db["users"] = []
    starting_seq = db["seq"]["user"]
    email = "2500107@stu.xidian.edu.cn"
    monkeypatch.setattr(
        _auth_handler,
        "read_json_body",
        lambda _h: {
            "email": email,
            "password": "password-123",
            "nickname": "测试用户",
        },
    )
    monkeypatch.setattr(
        _auth_handler,
        "_verification_code_or_error",
        lambda _h: ("123456", True),
    )
    monkeypatch.setattr(
        _auth_handler,
        "send_verification_email",
        lambda **_kwargs: (_ for _ in ()).throw(RuntimeError("smtp failed")),
    )
    monkeypatch.setattr(_auth_handler, "save_db", lambda _db: None)

    handler = FakeJsonHandler()
    _auth_handler.handle_register(handler, db)

    assert handler.status_code == HTTPStatus.SERVICE_UNAVAILABLE
    assert db["users"] == []
    assert db["seq"]["user"] == starting_seq
    assert email not in db["emailCodes"]


def test_auth_code_send_is_rate_limited(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _auth_handler
    from services._db_service import default_db

    db = default_db()
    email = "2500108@stu.xidian.edu.cn"
    monkeypatch.setattr(
        _auth_handler,
        "read_json_body",
        lambda _h: {"email": email},
    )
    monkeypatch.setattr(
        _auth_handler,
        "_verification_code_or_error",
        lambda _h: ("123456", False),
    )
    monkeypatch.setattr(_auth_handler, "save_db", lambda _db: None)

    handlers = [FakeJsonHandler() for _ in range(4)]
    for handler in handlers:
        _auth_handler.handle_send_code(handler, db)

    assert [handler.status_code for handler in handlers[:3]] == [
        HTTPStatus.OK,
        HTTPStatus.OK,
        HTTPStatus.OK,
    ]
    assert handlers[3].status_code == HTTPStatus.TOO_MANY_REQUESTS


def test_cross_post_parent_comment_is_rejected(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    author = _user("comment-author", "2500109@stu.xidian.edu.cn")
    db["users"].append(author)
    db["posts"] = [
        {"id": "p1", "deleted": False, "allowComment": True},
        {"id": "p2", "deleted": False, "allowComment": True},
    ]
    db["comments"] = [
        {"id": "cm1", "postId": "p1", "deleted": False},
    ]
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: author)
    monkeypatch.setattr(
        _post_handler,
        "read_json_body",
        lambda _h: {"content": "跨帖回复", "parentId": "cm1"},
    )

    handler = FakeJsonHandler()
    _post_handler.handle_create_comment(handler, db, "p2")

    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert len(db["comments"]) == 1


def test_message_history_checks_peer_block_direction(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _message_handler
    from services._db_service import default_db

    db = default_db()
    viewer = _user("viewer", "2500110@stu.xidian.edu.cn")
    peer = _user("peer", "2500111@stu.xidian.edu.cn")
    db["users"].extend([viewer, peer])
    db["conversations"] = [
        {
            "id": "conversation",
            "userId": viewer["id"],
            "peerUserId": peer["id"],
            "deleted": False,
        }
    ]
    db["userBlocks"] = [
        {"blockerUserId": peer["id"], "blockedUserId": viewer["id"]}
    ]
    monkeypatch.setattr(_message_handler, "_require_auth", lambda _h, _db: viewer)

    handler = FakeJsonHandler()
    _message_handler.handle_get_messages(handler, db, "conversation")

    assert handler.status_code == HTTPStatus.FORBIDDEN
    assert "对方已将你屏蔽" in handler.payload()["message"]


def test_partial_user_updates_preserve_omitted_fields(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _user_handler
    from services._db_service import default_db

    db = default_db()
    target = _user("profile-user", "2500112@stu.xidian.edu.cn")
    db["users"].append(target)
    monkeypatch.setattr(
        _user_handler,
        "auth_user_helper",
        lambda _h, _db: (target, "token"),
    )
    monkeypatch.setattr(_user_handler, "save_db", lambda _db: None)

    monkeypatch.setattr(
        _user_handler,
        "read_json_body",
        lambda _h: {"nickname": "新昵称"},
    )
    _user_handler.handle_update_me(FakeJsonHandler(), db)
    assert target["nickname"] == "新昵称"
    assert target["bio"] == "保留简介"
    assert target["gender"] == "男"
    assert target["college"] == "计算机学院"
    assert target["major"] == "软件工程"
    assert target["backgroundImageUrl"] == "https://example.com/background.png"

    monkeypatch.setattr(
        _user_handler,
        "read_json_body",
        lambda _h: {"allowStrangerDm": True},
    )
    _user_handler.handle_update_privacy(FakeJsonHandler(), db)
    assert target["allowStrangerDm"] is True
    assert target["showContactable"] is False

    monkeypatch.setattr(
        _user_handler,
        "read_json_body",
        lambda _h: {"notifyComment": True},
    )
    _user_handler.handle_update_notification_preferences(FakeJsonHandler(), db)
    assert target["notifyComment"] is True
    assert target["notifyReply"] is False
    assert target["notifySystem"] is False


def test_invalid_json_and_empty_settings_updates_are_rejected(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from helpers import InvalidJsonBody, read_json_body
    from handlers import _user_handler
    from services._db_service import default_db

    class InvalidBodyHandler:
        headers = {"Content-Length": "4"}

        def __init__(self) -> None:
            self.rfile = io.BytesIO(b"{bad")

    with pytest.raises(InvalidJsonBody):
        read_json_body(InvalidBodyHandler())

    db = default_db()
    target = _user("empty-update-user", "2500216@stu.xidian.edu.cn")
    db["users"].append(target)
    monkeypatch.setattr(
        _user_handler,
        "auth_user_helper",
        lambda _h, _db: (target, "token"),
    )
    monkeypatch.setattr(_user_handler, "read_json_body", lambda _h: {})
    monkeypatch.setattr(_user_handler, "save_db", lambda _db: None)

    privacy_handler = FakeJsonHandler()
    _user_handler.handle_update_privacy(privacy_handler, db)
    assert privacy_handler.status_code == HTTPStatus.BAD_REQUEST

    notification_handler = FakeJsonHandler()
    _user_handler.handle_update_notification_preferences(notification_handler, db)
    assert notification_handler.status_code == HTTPStatus.BAD_REQUEST

    profile_handler = FakeJsonHandler()
    _user_handler.handle_update_me(profile_handler, db)
    assert profile_handler.status_code == HTTPStatus.BAD_REQUEST


def test_direct_conversation_creation_respects_target_privacy(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _message_handler
    from services._db_service import default_db

    db = default_db()
    requester = _user("dm-requester", "2500217@stu.xidian.edu.cn")
    target = _user("dm-private-target", "2500218@stu.xidian.edu.cn")
    target["allowStrangerDm"] = False
    target["showContactable"] = False
    db["users"].extend([requester, target])
    db["conversations"] = []
    monkeypatch.setattr(
        _message_handler,
        "_require_auth",
        lambda _h, _db: requester,
    )
    monkeypatch.setattr(
        _message_handler,
        "read_json_body",
        lambda _h: {"targetUserId": target["id"]},
    )
    monkeypatch.setattr(_message_handler, "save_db", lambda _db: None)

    handler = FakeJsonHandler()
    _message_handler.handle_direct_conversation(handler, db)

    assert handler.status_code == HTTPStatus.FORBIDDEN
    assert db["conversations"] == []


def test_public_profile_count_excludes_private_and_unapproved_posts() -> None:
    from services._db_service import default_db
    from services._user_service import serialize_public_user_profile

    db = default_db()
    target = _user("count-owner", "2500219@stu.xidian.edu.cn")
    viewer = _user("count-viewer", "2500220@stu.xidian.edu.cn")
    db["users"].extend([target, viewer])
    db["posts"].extend(
        [
            {
                "id": "public-approved",
                "authorId": target["id"],
                "authorAlias": target["nickname"],
                "visibility": "public",
                "reviewStatus": "approved",
                "deleted": False,
            },
            {
                "id": "private-approved",
                "authorId": target["id"],
                "authorAlias": target["nickname"],
                "visibility": "private",
                "reviewStatus": "approved",
                "deleted": False,
            },
            {
                "id": "public-rejected",
                "authorId": target["id"],
                "authorAlias": target["nickname"],
                "visibility": "public",
                "reviewStatus": "rejected",
                "deleted": False,
            },
        ]
    )

    profile = serialize_public_user_profile(
        db,
        target_user=target,
        viewer_user_id=viewer["id"],
    )
    assert profile["postCount"] == 1


def test_invalid_pin_duration_returns_400_without_creating_request(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    owner = _user("pin-owner", "2500113@stu.xidian.edu.cn")
    db["users"].append(owner)
    db["posts"] = [
        {
            "id": "pin-post",
            "authorId": owner["id"],
            "deleted": False,
            "pinExpiresAt": "",
            "pinDurationMinutes": 0,
        }
    ]
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: owner)
    monkeypatch.setattr(
        _post_handler,
        "read_json_body",
        lambda _h: {"durationMinutes": -1, "reason": "测试"},
    )

    handler = FakeJsonHandler()
    _post_handler.handle_pin_request(handler, db, "pin-post")

    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert db["postPinRequests"] == []


def test_announcement_publish_list_filter_summary_and_persistence(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Any,
) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db
    from sql_repository import SqliteTreeholeRepository

    db = default_db()
    _patch_admin(
        monkeypatch,
        {
            "title": "系统维护通知",
            "content": "今晚进行系统维护。",
            "type": "维护公告",
            "isImportant": True,
        },
    )
    publish_handler = FakeJsonHandler()
    _admin_handler.handle_admin_publish_announcement(publish_handler, db)

    assert publish_handler.status_code == HTTPStatus.OK
    announcement_id = publish_handler.payload()["data"]["id"]
    assert db["announcements"][0]["id"] == announcement_id

    list_handler = FakeJsonHandler()
    _admin_handler.handle_public_announcements(
        list_handler,
        db,
        {"type": ["维护公告"]},
    )
    assert list_handler.payload()["data"][0]["title"] == "系统维护通知"

    filter_handler = FakeJsonHandler()
    _admin_handler.handle_public_announcement_filters(filter_handler, db)
    assert filter_handler.payload()["data"]["types"] == ["维护公告"]

    summary_handler = FakeJsonHandler()
    _admin_handler.handle_public_announcement_daily_summary(summary_handler, db)
    assert "系统维护通知" in summary_handler.payload()["data"]["summary"]

    repository = SqliteTreeholeRepository(tmp_path / "announcements.db")
    repository.initialize(lambda: db)
    loaded = repository.load_state()
    assert loaded["announcements"][0]["id"] == announcement_id


def test_private_posts_and_pending_comments_are_filtered_at_shared_service() -> None:
    from services._db_service import default_db, list_comments, list_posts

    db = default_db()
    owner = _user("privacy-owner", "2500201@stu.xidian.edu.cn")
    stranger = _user("privacy-stranger", "2500202@stu.xidian.edu.cn")
    db["users"].extend([owner, stranger])
    db["posts"] = [
        {
            "id": "public-post",
            "authorId": owner["id"],
            "visibility": "public",
            "reviewStatus": "approved",
            "deleted": False,
        },
        {
            "id": "private-post",
            "authorId": owner["id"],
            "visibility": "private",
            "reviewStatus": "approved",
            "deleted": False,
        },
    ]
    db["comments"] = [
        {
            "id": "approved-comment",
            "postId": "public-post",
            "userId": owner["id"],
            "reviewStatus": "approved",
            "deleted": False,
        },
        {
            "id": "pending-comment",
            "postId": "public-post",
            "userId": owner["id"],
            "reviewStatus": "pending",
            "deleted": False,
        },
    ]

    assert [row["id"] for row in list_posts(db)] == ["public-post"]
    assert {row["id"] for row in list_posts(db, viewer_user_id=owner["id"])} == {
        "private-post",
        "public-post",
    }
    assert [row["id"] for row in list_comments(db, "public-post", stranger["id"])] == [
        "approved-comment",
    ]
    assert [row["id"] for row in list_comments(db, "public-post", owner["id"])] == [
        "approved-comment",
        "pending-comment",
    ]


def test_cached_private_hot_topic_is_not_returned() -> None:
    from handlers import _radio_handler
    from services._db_service import default_db

    db = default_db()
    db["posts"] = [
        {
            "id": "cached-public",
            "visibility": "public",
            "reviewStatus": "approved",
            "deleted": False,
        },
        {
            "id": "cached-private",
            "visibility": "private",
            "reviewStatus": "approved",
            "deleted": False,
        },
    ]
    db["hotTopics"] = [
        {
            "id": "hot-public",
            "postId": "cached-public",
            "reviewStatus": "approved",
            "rank": 1,
        },
        {
            "id": "hot-private",
            "postId": "cached-private",
            "reviewStatus": "approved",
            "rank": 2,
        },
    ]

    handler = FakeJsonHandler()
    _radio_handler.handle_get_hot_topics(handler, db)

    assert [row["id"] for row in handler.payload()["data"]] == ["hot-public"]


def test_private_comment_like_is_not_a_visibility_bypass(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    owner = _user("like-owner", "2500203@stu.xidian.edu.cn")
    stranger = _user("like-stranger", "2500204@stu.xidian.edu.cn")
    db["users"].extend([owner, stranger])
    db["posts"] = [
        {
            "id": "private-like-post",
            "authorId": owner["id"],
            "visibility": "private",
            "deleted": False,
        }
    ]
    db["comments"] = [
        {
            "id": "private-comment",
            "postId": "private-like-post",
            "userId": owner["id"],
            "reviewStatus": "approved",
            "deleted": False,
        }
    ]
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: stranger)

    handler = FakeJsonHandler()
    _post_handler.handle_toggle_comment_like(handler, db, "private-comment")

    assert handler.status_code == HTTPStatus.NOT_FOUND
    assert db["likes"] == []


def test_user_admin_is_secondary_and_cannot_enter_primary_user_actions(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _admin_handler
    from services._db_service import build_authenticated_user_admin, default_db

    db = default_db()
    user_admin = _user("secondary-admin", "2500205@stu.xidian.edu.cn")
    target = _user("admin-target", "2500206@stu.xidian.edu.cn")
    user_admin["isAdmin"] = True
    db["users"].extend([user_admin, target])
    authenticated = build_authenticated_user_admin(user_admin)
    assert authenticated["role"] == "secondary"
    assert authenticated["isPrimary"] is False

    monkeypatch.setattr(
        _admin_handler,
        "_require_primary_admin",
        lambda handler, _db: (
            _admin_handler.json_error(
                handler,
                HTTPStatus.FORBIDDEN,
                "需要一级管理员权限",
            )
            or None
        ),
    )
    handler = FakeJsonHandler()
    _admin_handler.handle_admin_user_action(handler, db, target["id"])

    assert handler.status_code == HTTPStatus.FORBIDDEN
    assert target["isAdmin"] is False


@pytest.mark.parametrize(
    ("handler_name", "collection_name", "row"),
    [
        (
            "handle_admin_post_pin_request_action",
            "postPinRequests",
            {
                "id": "missing-target",
                "postId": "missing",
                "durationMinutes": 60,
                "status": "pending",
            },
        ),
        (
            "handle_admin_user_level_request_action",
            "userLevelRequests",
            {"id": "missing-target", "userId": "missing", "status": "pending"},
        ),
        (
            "handle_admin_appeal_action",
            "appeals",
            {
                "id": "missing-target",
                "userId": "missing",
                "appealType": "account_restore",
                "status": "pending",
            },
        ),
        (
            "handle_admin_cancellation_action",
            "accountCancellationRequests",
            {"id": "missing-target", "userId": "missing", "status": "pending"},
        ),
    ],
)
def test_approve_missing_target_keeps_request_pending(
    monkeypatch: pytest.MonkeyPatch,
    handler_name: str,
    collection_name: str,
    row: dict[str, Any],
) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    db[collection_name] = [dict(row)]
    _patch_admin(monkeypatch, {"action": "approve"})

    handler = FakeJsonHandler()
    getattr(_admin_handler, handler_name)(handler, db, "missing-target")

    assert handler.status_code == HTTPStatus.NOT_FOUND
    assert db[collection_name][0]["status"] == "pending"


def test_report_legacy_action_is_normalized_before_mutation(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    db["reports"] = [
        {
            "id": "legacy-report",
            "targetType": "post",
            "targetId": "missing",
            "status": "pending",
            "handledAt": "",
        }
    ]
    _patch_admin(monkeypatch, {"action": "delete_content"})

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_report_action(handler, db, "legacy-report")

    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert db["reports"][0]["status"] == "pending"
    assert db["reports"][0]["handledAt"] == ""


def test_appeal_requires_account_proof_and_persists_complete_fields(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Any,
) -> None:
    from handlers import _post_handler
    from helpers import hash_password
    from services._db_service import default_db
    from sql_repository import SqliteTreeholeRepository

    db = default_db()
    target = _user("appeal-user", "2500207@stu.xidian.edu.cn")
    target["password"] = hash_password("correct-password")
    target["deleted"] = True
    db["users"].append(target)
    monkeypatch.setattr(
        _post_handler,
        "auth_user_helper",
        lambda _h, _db: (None, None),
    )
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)

    monkeypatch.setattr(
        _post_handler,
        "read_json_body",
        lambda _h: {
            "email": target["email"],
            "appealType": "account_restore",
            "content": "请求恢复账号",
            "password": "wrong-password",
        },
    )
    rejected = FakeJsonHandler()
    _post_handler.handle_submit_appeal(rejected, db)
    assert rejected.status_code == HTTPStatus.UNAUTHORIZED
    assert db["appeals"] == []

    monkeypatch.setattr(
        _post_handler,
        "read_json_body",
        lambda _h: {
            "email": target["email"],
            "appealType": "account_restore",
            "content": "请求恢复账号",
            "password": "correct-password",
        },
    )
    accepted = FakeJsonHandler()
    accepted.client_address = ("127.0.0.2", 23456)
    _post_handler.handle_submit_appeal(accepted, db)
    assert accepted.status_code == HTTPStatus.OK
    appeal = db["appeals"][0]
    assert appeal["userEmail"] == target["email"]
    assert appeal["studentId"] == target["studentId"]
    assert appeal["targetId"] == target["id"]
    assert appeal["adminNote"] == ""

    repository = SqliteTreeholeRepository(tmp_path / "appeal-fields.db")
    repository.initialize(lambda: db)
    loaded = repository.load_state()
    assert loaded["appeals"][0]["userEmail"] == target["email"]
    assert loaded["appeals"][0]["title"] == "账号恢复申诉"


def test_cancellation_request_uses_sql_schema_field_names(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _comment_handler
    from services._db_service import default_db

    db = default_db()
    target = _user("cancel-user", "2500208@stu.xidian.edu.cn")
    db["users"].append(target)
    monkeypatch.setattr(_comment_handler, "_require_auth", lambda _h, _db: target)
    monkeypatch.setattr(
        _comment_handler,
        "read_json_body",
        lambda _h: {"reason": "不再使用"},
    )
    monkeypatch.setattr(_comment_handler, "save_db", lambda _db: None)

    handler = FakeJsonHandler()
    _comment_handler.handle_cancel_account_request(handler, db)

    assert handler.status_code == HTTPStatus.OK
    request = db["accountCancellationRequests"][0]
    assert request["userEmail"] == target["email"]
    assert request["userNickname"] == target["nickname"]
    assert request["studentId"] == target["studentId"]
    assert request["reviewNote"] == ""


def test_account_cancellation_fails_before_mutation_when_storage_delete_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from services import _user_service
    from services._db_service import default_db

    class FailingStorage:
        def delete(self, _key: str) -> None:
            raise RuntimeError("storage unavailable")

    db = default_db()
    target = _user("cancel-storage-user", "2500215@stu.xidian.edu.cn")
    target["avatarUrl"] = "/api/storage/avatars/user.png"
    db["users"].append(target)
    db["sessions"]["session-token"] = target["id"]
    monkeypatch.setattr(_user_service._globals, "OBJECT_STORAGE", FailingStorage())

    with pytest.raises(RuntimeError, match="账号未注销"):
        _user_service.cancel_user_account(
            db,
            target,
            actor_id=target["id"],
            detail="测试注销",
        )

    assert target["deleted"] is False
    assert target["avatarUrl"] == "/api/storage/avatars/user.png"
    assert db["sessions"]["session-token"] == target["id"]


def test_image_mime_mismatch_and_sensitive_filename_risk_are_enforced(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _upload_handler
    from services._db_service import default_db

    db = default_db()
    target = _user("mime-user", "2500209@stu.xidian.edu.cn")
    db["users"].append(target)
    monkeypatch.setattr(
        _upload_handler,
        "auth_user_helper",
        lambda _h, _db: (target, "token"),
    )
    monkeypatch.setattr(
        _upload_handler,
        "read_json_body",
        lambda _h: {
            "fileName": "normal.png",
            "contentType": "image/jpeg",
            "imageDataBase64": "iVBORw0KGgoAAAAAAAAAAAAA=",
        },
    )
    handler = FakeJsonHandler()
    _upload_handler.handle_upload_image(handler, db)
    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert db["mediaUploads"] == []

    status, reason = _upload_handler.moderate_image_upload(
        file_name="诈骗海报.png",
        content_type="image/png",
        size_bytes=128,
        db=db,
    )
    assert status == "risk"
    assert "诈骗" in reason


def test_binding_risk_image_to_post_does_not_auto_approve(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    target = _user("image-owner", "2500210@stu.xidian.edu.cn")
    db["users"].append(target)
    db["mediaUploads"] = [
        {
            "id": "risk-image",
            "uploaderId": target["id"],
            "postId": "",
            "status": "risk",
            "deleted": False,
        }
    ]
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: target)
    monkeypatch.setattr(
        _post_handler,
        "read_json_body",
        lambda _h: {
            "title": "图片帖",
            "content": "正文",
            "imageUploadIds": ["risk-image"],
        },
    )
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)

    handler = FakeJsonHandler()
    _post_handler.handle_create_post(handler, db)

    assert handler.status_code == HTTPStatus.OK
    assert db["mediaUploads"][0]["status"] == "risk"


@pytest.mark.parametrize(
    ("content", "expected_category"),
    [
        ("这里发布血腥肢解内容", "血腥"),
        ("这里发布群殴暴力内容", "暴力"),
        ("这里发布色情视频", "色情"),
        ("这里提供洗钱服务", "违法犯罪"),
    ],
)
def test_create_post_blocks_prohibited_content_before_persistence(
    monkeypatch: pytest.MonkeyPatch,
    content: str,
    expected_category: str,
) -> None:
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    target = _user("moderation-owner", "2500211@stu.xidian.edu.cn")
    db["users"].append(target)
    original_post_ids = [post["id"] for post in db["posts"]]
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: target)
    monkeypatch.setattr(
        _post_handler,
        "read_json_body",
        lambda _h: {"title": "自动审核测试", "content": content},
    )
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)

    handler = FakeJsonHandler()
    _post_handler.handle_create_post(handler, db)

    payload = handler.payload()
    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert payload["data"]["code"] == "POST_CONTENT_REJECTED"
    assert expected_category in payload["data"]["categories"]
    assert [post["id"] for post in db["posts"]] == original_post_ids
    assert db["auditLogs"][-1]["action"] == "risk_block_post"


def test_create_post_blocks_admin_configured_sensitive_word(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    db["sensitiveWords"] = ["校内禁词"]
    target = _user("sensitive-owner", "2500212@stu.xidian.edu.cn")
    db["users"].append(target)
    original_post_count = len(db["posts"])
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: target)
    monkeypatch.setattr(
        _post_handler,
        "read_json_body",
        lambda _h: {"title": "测试", "content": "包含校 内 禁 词的帖子"},
    )
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)

    handler = FakeJsonHandler()
    _post_handler.handle_create_post(handler, db)

    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert handler.payload()["message"] == "内容命中敏感词，禁止发布，请修改后重试"
    assert len(db["posts"]) == original_post_count


def test_image_delete_failure_keeps_review_state_unchanged(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _admin_handler
    from services._db_service import default_db

    class FailingStorage:
        def delete(self, _key: str) -> None:
            raise RuntimeError("storage unavailable")

    db = default_db()
    upload = {
        "id": "delete-image",
        "objectKey": "object.png",
        "status": "approved",
        "deleted": False,
        "postId": "",
    }
    db["mediaUploads"] = [upload]
    _patch_admin(monkeypatch, {"action": "delete"})
    monkeypatch.setattr(_admin_handler._globals, "OBJECT_STORAGE", FailingStorage())

    handler = FakeJsonHandler()
    _admin_handler.handle_admin_image_review(handler, db, upload["id"])

    assert handler.status_code == HTTPStatus.BAD_GATEWAY
    assert upload["status"] == "approved"
    assert upload["deleted"] is False


def test_post_delete_removes_storage_before_returning_success(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _post_handler
    from services._db_service import default_db

    class Storage:
        def __init__(self, *, fail: bool = False) -> None:
            self.fail = fail
            self.deleted: list[str] = []
            self.restored: list[str] = []

        def get_bytes(self, key: str) -> tuple[bytes, str]:
            return b"image", "image/png"

        def delete(self, key: str) -> None:
            if self.fail:
                raise RuntimeError("storage unavailable")
            self.deleted.append(key)

        def restore_bytes(
            self,
            *,
            key: str,
            data: bytes,
            content_type: str,
        ) -> None:
            self.restored.append(key)

    db = default_db()
    owner = _user("delete-owner", "2500214@stu.xidian.edu.cn")
    db["users"].append(owner)
    post = {
        "id": "delete-post",
        "authorId": owner["id"],
        "deleted": False,
    }
    upload = {
        "id": "delete-upload",
        "postId": post["id"],
        "objectKey": "posts/image.png",
        "status": "approved",
        "deleted": False,
    }
    db["posts"].append(post)
    db["mediaUploads"].append(upload)
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: owner)
    monkeypatch.setattr(_post_handler, "save_db", lambda _db: None)

    failing_storage = Storage(fail=True)
    monkeypatch.setattr(_post_handler._globals, "OBJECT_STORAGE", failing_storage)
    failed_handler = FakeJsonHandler()
    _post_handler.handle_delete_post(failed_handler, db, post["id"])
    assert failed_handler.status_code == HTTPStatus.BAD_GATEWAY
    assert post["deleted"] is False
    assert upload["deleted"] is False

    storage = Storage()
    monkeypatch.setattr(_post_handler._globals, "OBJECT_STORAGE", storage)
    success_handler = FakeJsonHandler()
    _post_handler.handle_delete_post(success_handler, db, post["id"])
    assert success_handler.status_code == HTTPStatus.OK
    assert storage.deleted == ["posts/image.png"]
    assert post["deleted"] is True
    assert upload["deleted"] is True


def test_post_delete_restores_storage_when_database_save_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _post_handler
    from services._db_service import default_db

    class Storage:
        def __init__(self) -> None:
            self.objects = {"posts/rollback.png": (b"image", "image/png")}

        def get_bytes(self, key: str) -> tuple[bytes, str] | None:
            return self.objects.get(key)

        def delete(self, key: str) -> None:
            self.objects.pop(key, None)

        def restore_bytes(
            self,
            *,
            key: str,
            data: bytes,
            content_type: str,
        ) -> None:
            self.objects[key] = (data, content_type)

    db = default_db()
    owner = _user("rollback-owner", "2500298@stu.xidian.edu.cn")
    post = {
        "id": "rollback-post",
        "authorId": owner["id"],
        "deleted": False,
    }
    upload = {
        "id": "rollback-upload",
        "postId": post["id"],
        "objectKey": "posts/rollback.png",
        "status": "approved",
        "deleted": False,
    }
    db["users"].append(owner)
    db["posts"].append(post)
    db["mediaUploads"].append(upload)
    storage = Storage()
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: owner)
    monkeypatch.setattr(_post_handler._globals, "OBJECT_STORAGE", storage)
    monkeypatch.setattr(
        _post_handler,
        "save_db",
        lambda _db: (_ for _ in ()).throw(RuntimeError("database unavailable")),
    )

    with pytest.raises(RuntimeError, match="database unavailable"):
        _post_handler.handle_delete_post(FakeJsonHandler(), db, post["id"])

    restored_post = next(row for row in db["posts"] if row["id"] == post["id"])
    restored_upload = next(
        row for row in db["mediaUploads"] if row["id"] == upload["id"]
    )
    assert restored_post["deleted"] is False
    assert restored_upload["deleted"] is False
    assert storage.objects["posts/rollback.png"] == (b"image", "image/png")


def test_admin_post_delete_does_not_change_state_when_storage_delete_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from services import _db_service
    from services._db_service import default_db

    class FailingStorage:
        def delete(self, _key: str) -> None:
            raise RuntimeError("storage unavailable")

    db = default_db()
    post = {
        "id": "admin-delete-post",
        "deleted": False,
        "reviewStatus": "approved",
    }
    upload = {
        "id": "admin-delete-upload",
        "postId": post["id"],
        "objectKey": "posts/admin-delete.png",
        "status": "approved",
        "deleted": False,
    }
    db["posts"].append(post)
    db["mediaUploads"].append(upload)
    monkeypatch.setattr(_db_service._globals, "OBJECT_STORAGE", FailingStorage())

    with pytest.raises(RuntimeError, match="状态未变更"):
        _db_service.apply_admin_review_action(
            db,
            target_type="post",
            target_id=post["id"],
            action="delete",
        )

    assert post["deleted"] is False
    assert post["reviewStatus"] == "approved"
    assert upload["deleted"] is False


def test_deleted_upload_is_not_served_even_if_object_remains(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _static_handler

    class Storage:
        def get_bytes(self, _key: str) -> tuple[bytes, str]:
            return b"secret", "image/png"

    monkeypatch.setattr(_static_handler._globals, "OBJECT_STORAGE", Storage())
    db = {
        "mediaUploads": [
            {
                "objectKey": "posts/deleted.png",
                "status": "approved",
                "deleted": True,
            }
        ]
    }
    handler = FakeJsonHandler()
    handled = _static_handler.handle_storage_get(
        handler,
        "/api/storage/posts/deleted.png",
        db,
    )
    assert handled is False
    assert handler.wfile.getvalue() == b""


def test_schoolnet_requires_actual_login_and_authenticated_home(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from helpers import _campus_auth

    requests = _campus_auth._import_requests()

    class Response:
        def __init__(
            self,
            *,
            payload: dict[str, Any] | None = None,
            status: int = 200,
            url: str = "",
            text: str = "",
        ) -> None:
            self._payload = payload or {}
            self.status_code = status
            self.url = url
            self.text = text
            self.content = (
                text.encode("utf-8")
                if text
                else json.dumps(self._payload).encode("utf-8")
            )
            self.headers: dict[str, str] = {}

        def json(self) -> dict[str, Any]:
            return self._payload

        def raise_for_status(self) -> None:
            if self.status_code >= 400:
                raise requests.HTTPError(f"HTTP {self.status_code}")

        def iter_content(self, chunk_size: int):
            del chunk_size
            yield self.content

    class Session:
        def __init__(self, login_status: int, home_url: str, home_text: str) -> None:
            self.login_status = login_status
            self.home_url = home_url
            self.home_text = home_text
            self.posts = 0

        def post(self, *_args: Any, **_kwargs: Any) -> Response:
            self.posts += 1
            if self.posts == 1:
                return Response(payload={"success": True})
            return Response(status=self.login_status)

        def get(self, *_args: Any, **_kwargs: Any) -> Response:
            return Response(url=self.home_url, text=self.home_text)

    monkeypatch.setattr(
        _campus_auth,
        "_rsa_encrypt_base64",
        lambda _password, _key: "encrypted",
    )

    failed_attempt = _campus_auth._SchoolnetAttempt(
        session=Session(500, "", ""),
        csrf_name="csrf",
        csrf_value="token",
        public_key="key",
        expires_at=9999999999,
    )
    monkeypatch.setattr(
        _campus_auth,
        "_load_schoolnet_attempt",
        lambda _attempt_id: failed_attempt,
    )
    with pytest.raises(_campus_auth.CampusAuthError):
        _campus_auth.login_schoolnet("attempt", "2500211", "password", "1234")

    login_page_attempt = _campus_auth._SchoolnetAttempt(
        session=Session(
            200,
            "https://zfw.xidian.edu.cn/login",
            "<input name='LoginForm[username]'>",
        ),
        csrf_name="csrf",
        csrf_value="token",
        public_key="key",
        expires_at=9999999999,
    )
    monkeypatch.setattr(
        _campus_auth,
        "_load_schoolnet_attempt",
        lambda _attempt_id: login_page_attempt,
    )
    with pytest.raises(_campus_auth.CampusAuthCredentialError):
        _campus_auth.login_schoolnet("attempt", "2500211", "password", "1234")

    unverifiable_attempt = _campus_auth._SchoolnetAttempt(
        session=Session(
            200,
            "https://zfw.xidian.edu.cn/home",
            "<html><body>maintenance</body></html>",
        ),
        csrf_name="csrf",
        csrf_value="token",
        public_key="key",
        expires_at=9999999999,
    )
    monkeypatch.setattr(
        _campus_auth,
        "_load_schoolnet_attempt",
        lambda _attempt_id: unverifiable_attempt,
    )
    with pytest.raises(_campus_auth.CampusAuthError, match="可验证"):
        _campus_auth.login_schoolnet("attempt", "2500211", "password", "1234")

    authenticated_attempt = _campus_auth._SchoolnetAttempt(
        session=Session(
            200,
            "https://zfw.xidian.edu.cn/home",
            "<html><a href='/site/logout'>退出登录</a></html>",
        ),
        csrf_name="csrf",
        csrf_value="token",
        public_key="key",
        expires_at=9999999999,
    )
    monkeypatch.setattr(
        _campus_auth,
        "_load_schoolnet_attempt",
        lambda _attempt_id: authenticated_attempt,
    )
    result = _campus_auth.login_schoolnet(
        "authenticated-attempt",
        "2500211",
        "password",
        "1234",
    )
    assert result["status"] == "authenticated"


def test_unapproved_post_access_and_interactions_are_separated() -> None:
    from handlers import _post_handler

    pending = {
        "authorId": "owner",
        "visibility": "public",
        "reviewStatus": "pending",
    }
    rejected = {
        "authorId": "owner",
        "visibility": "public",
        "reviewStatus": "rejected",
    }
    assert _post_handler._can_view_post(pending, "owner") is True
    assert _post_handler._can_view_post(pending, "stranger") is False
    assert _post_handler._can_view_post(rejected, "stranger") is False
    assert _post_handler._can_interact_with_post(pending, "owner") is False
    assert _post_handler._can_interact_with_post(rejected, "owner") is False


def test_post_serialization_excludes_hidden_comments_and_deleted_images() -> None:
    from services._db_service import default_db, serialize_post

    db = default_db()
    post = {
        "id": "serialize-post",
        "authorId": "owner",
        "reviewStatus": "approved",
        "visibility": "public",
        "hasImage": True,
        "deleted": False,
    }
    db["posts"].append(post)
    db["comments"].extend(
        [
            {
                "id": "approved-comment",
                "postId": post["id"],
                "userId": "approved-user",
                "reviewStatus": "approved",
                "deleted": False,
            },
            {
                "id": "pending-comment",
                "postId": post["id"],
                "userId": "pending-user",
                "reviewStatus": "pending",
                "deleted": False,
            },
        ]
    )
    db["mediaUploads"].append(
        {
            "id": "deleted-upload",
            "postId": post["id"],
            "url": "/api/storage/deleted.png",
            "status": "approved",
            "deleted": True,
        }
    )

    public_row = serialize_post(db, post)
    owner_row = serialize_post(db, post, viewer_user_id="pending-user")
    assert public_row["commentCount"] == 1
    assert owner_row["commentCount"] == 2
    assert public_row["imageUrls"] == []
    assert public_row["hasImage"] is False


def test_storage_denies_unapproved_upload_and_rejected_post(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _static_handler

    class Storage:
        def get_bytes(self, _key: str) -> tuple[bytes, str]:
            raise AssertionError("denied objects must not be read")

    monkeypatch.setattr(_static_handler._globals, "OBJECT_STORAGE", Storage())
    pending_db = {
        "mediaUploads": [
            {
                "objectKey": "pending.png",
                "status": "pending",
                "deleted": False,
            }
        ],
        "users": [],
    }
    rejected_post_db = {
        "mediaUploads": [
            {
                "objectKey": "rejected.png",
                "postId": "rejected-post",
                "status": "approved",
                "deleted": False,
            }
        ],
        "posts": [
            {
                "id": "rejected-post",
                "reviewStatus": "rejected",
                "visibility": "public",
                "deleted": False,
            }
        ],
        "users": [],
    }
    assert (
        _static_handler.handle_storage_get(
            FakeJsonHandler(),
            "/api/storage/pending.png",
            pending_db,
        )
        is False
    )
    assert (
        _static_handler.handle_storage_get(
            FakeJsonHandler(),
            "/api/storage/rejected.png",
            rejected_post_db,
        )
        is False
    )


@pytest.mark.parametrize(
    ("uploader_id", "status", "expected_status"),
    [
        ("other-user", "approved", HTTPStatus.FORBIDDEN),
        ("background-owner", "pending", HTTPStatus.BAD_REQUEST),
    ],
)
def test_profile_rejects_foreign_or_unapproved_background_upload(
    monkeypatch: pytest.MonkeyPatch,
    uploader_id: str,
    status: str,
    expected_status: HTTPStatus,
) -> None:
    from handlers import _user_handler
    from services._db_service import default_db

    db = default_db()
    owner = _user("background-owner", "2500297@stu.xidian.edu.cn")
    db["users"].append(owner)
    db["mediaUploads"].append(
        {
            "id": "background-upload",
            "url": "/api/storage/background.png",
            "objectKey": "background.png",
            "uploaderId": uploader_id,
            "postId": "",
            "status": status,
            "deleted": False,
        }
    )
    monkeypatch.setattr(
        _user_handler,
        "auth_user_helper",
        lambda _handler, _db: (owner, "token"),
    )
    monkeypatch.setattr(
        _user_handler,
        "read_json_body",
        lambda _handler: {
            "backgroundImageUrl": "/api/storage/background.png",
        },
    )

    handler = FakeJsonHandler()
    _user_handler.handle_update_me(handler, db)

    assert handler.status_code == expected_status
    assert owner["backgroundImageUrl"] == "https://example.com/background.png"


def test_deleted_review_target_is_terminal() -> None:
    from services import _db_service
    from services._db_service import default_db

    db = default_db()
    db["posts"].append(
        {
            "id": "terminal-post",
            "reviewStatus": "rejected",
            "deleted": True,
        }
    )
    with pytest.raises(ValueError, match="已删除"):
        _db_service.apply_admin_review_action(
            db,
            target_type="post",
            target_id="terminal-post",
            action="approve",
        )


def test_invalid_post_status_returns_400_without_mutation(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _post_handler
    from services._db_service import default_db

    db = default_db()
    owner = _user("status-owner", "2500212@stu.xidian.edu.cn")
    post = {
        "id": "status-post",
        "authorId": owner["id"],
        "status": "ongoing",
        "deleted": False,
    }
    db["users"].append(owner)
    db["posts"] = [post]
    monkeypatch.setattr(_post_handler, "_require_auth", lambda _h, _db: owner)
    monkeypatch.setattr(
        _post_handler,
        "read_json_body",
        lambda _h: {"status": "definitely-not-valid"},
    )

    handler = FakeJsonHandler()
    _post_handler.handle_update_post(handler, db, post["id"])

    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert post["status"] == "ongoing"


def test_club_approval_rejects_missing_applicant(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from handlers import _radio_handler
    from services._db_service import default_db

    db = default_db()
    application = {
        "id": "club-application",
        "applicantUserId": "missing-user",
        "status": "pending",
        "name": "不存在的社团",
    }
    db["clubApplications"] = [application]
    monkeypatch.setattr(
        _radio_handler,
        "_require_admin",
        lambda _h, _db: {"adminId": "primary"},
    )
    monkeypatch.setattr(
        _radio_handler,
        "read_json_body",
        lambda _h: {"action": "approve"},
    )

    handler = FakeJsonHandler()
    _radio_handler.handle_admin_club_application_action(
        handler,
        db,
        application["id"],
    )

    assert handler.status_code == HTTPStatus.NOT_FOUND
    assert application["status"] == "pending"
    assert db["clubs"] == []
