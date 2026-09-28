"""学院 from the identity mapping, channels retired, sections by sectionId."""
from __future__ import annotations

import sqlite3
from http import HTTPStatus
from pathlib import Path
from typing import Any

import pytest

from tests.test_logic_regressions import FakeJsonHandler, _user


def _call(fn: Any, *args: Any, body: dict[str, Any] | None = None) -> FakeJsonHandler:
    handler = FakeJsonHandler()
    handler.headers["Content-Length"] = "0"
    if body is not None:
        handler._cached_json_body = body  # type: ignore[attr-defined]
    fn(handler, *args)
    return handler


@pytest.fixture
def world(monkeypatch: pytest.MonkeyPatch) -> dict[str, Any]:
    import _globals
    from handlers import _post_handler, _radio_handler, _user_handler
    from services._db_service import default_db, migrate_db

    db = default_db()
    migrate_db(db)
    alice = _user("alice", "2500500@stu.xidian.edu.cn")  # typed college: 计算机学院
    bob = _user("bob", "2500501@stu.xidian.edu.cn")
    db["users"].extend([alice, bob])
    monkeypatch.setattr(_globals, "AUTH_STUDENT_COLLEGE_SECTIONS", {"2500500": "ee"})
    viewer = {"current": alice}
    for module in (_post_handler, _user_handler, _radio_handler):
        monkeypatch.setattr(module, "auth_user_helper", lambda _h, _db: (viewer["current"], "token"))
        monkeypatch.setattr(module, "save_db", lambda _db: None)
    monkeypatch.setattr(_radio_handler, "_require_admin", lambda _h, _db: {"adminId": "a1"})
    return {"db": db, "alice": alice, "bob": bob, "as": lambda user: viewer.update(current=user)}


# ---------------------------------------------------------------- 学院


def test_profile_college_comes_from_the_identity_mapping(world: dict[str, Any]) -> None:
    from handlers import _user_handler

    me = _call(_user_handler.handle_get_me, world["db"]).payload()["data"]
    # Not the typed-in 计算机学院: the mapping puts alice in ee.
    assert me["college"] == "电子工程学院"
    world["as"](world["bob"])
    assert _call(_user_handler.handle_get_me, world["db"]).payload()["data"]["college"] == ""


def test_users_cannot_set_their_college(world: dict[str, Any]) -> None:
    from handlers import _user_handler

    handler = _call(_user_handler.handle_update_me, world["db"], body={"bio": "新简介", "college": "物理学院"})
    assert handler.status_code == HTTPStatus.BAD_REQUEST
    assert world["alice"]["bio"] == "保留简介"
    # Echoing the verified value back (old clients send the whole form) is fine.
    handler = _call(_user_handler.handle_update_me, world["db"], body={"bio": "新简介", "college": "电子工程学院"})
    assert handler.status_code == HTTPStatus.OK
    assert handler.payload()["data"]["college"] == "电子工程学院"


def test_colleges_follow_the_mapping(world: dict[str, Any], monkeypatch: pytest.MonkeyPatch) -> None:
    import _globals
    from services import college_sections

    assert [row["sectionId"] for row in college_sections(world["db"])] == ["ee"]
    monkeypatch.setattr(_globals, "AUTH_STUDENT_COLLEGE_SECTIONS", {"1": "cs", "2": "ee", "3": "no-such"})
    assert [row["sectionId"] for row in college_sections(world["db"])] == ["cs", "ee"]
    monkeypatch.setattr(_globals, "AUTH_STUDENT_COLLEGE_SECTIONS", {})
    assert college_sections(world["db"]) == []


def test_migration_drops_typed_colleges() -> None:
    from services._db_service import default_db, migrate_db

    db = default_db()
    db["users"].append(_user("alice", "2500500@stu.xidian.edu.cn"))
    migrate_db(db)
    assert "college" not in db["users"][-1]


# ---------------------------------------------------------------- channels


def test_posts_filter_by_tag_not_channel(world: dict[str, Any]) -> None:
    from handlers import _post_handler

    db = world["db"]
    tagged = {"tag": ["北校区"], "limit": ["50"]}
    handler = FakeJsonHandler()
    _post_handler.handle_get_posts(handler, db, tagged)
    items = handler.payload()["data"]["items"]
    assert items and all("北校区" in item["tags"] for item in items)
    assert all("channel" not in item for item in items)


def test_repository_folds_legacy_channels_into_tags(tmp_path: Path) -> None:
    from services._db_service import default_db
    from sql_repository import SqliteTreeholeRepository

    path = tmp_path / "legacy.db"
    repo = SqliteTreeholeRepository(path)
    repo.initialize(default_db)
    db = repo.load_state()
    post_id = db["posts"][0]["id"]
    # What an older database still holds.
    with sqlite3.connect(path) as conn:
        conn.execute("CREATE TABLE channels (name TEXT PRIMARY KEY, sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)")
        conn.execute("INSERT INTO channels VALUES ('旧频道', 1, '2026-01-01'), ('综合', 0, '2026-01-01')")
        conn.execute("UPDATE posts SET channel = '旧帖频道' WHERE id = ?", (post_id,))

    again = SqliteTreeholeRepository(path)
    again.initialize(default_db)
    state = again.load_state()
    assert "旧频道" in state["tags"] and "综合" not in state["tags"]
    assert "旧帖频道" in next(p for p in state["posts"] if p["id"] == post_id)["tags"]
    assert "channels" not in state
    with sqlite3.connect(path) as conn:
        assert conn.execute("SELECT 1 FROM sqlite_master WHERE name = 'channels'").fetchone() is None
        assert conn.execute("SELECT COUNT(*) FROM posts WHERE channel != ''").fetchone()[0] == 0


# ---------------------------------------------------------------- sections


def test_sections_are_named_by_section_id(world: dict[str, Any]) -> None:
    from handlers import _radio_handler

    db = world["db"]
    rows = _call(_radio_handler.handle_get_sections, db).payload()["data"]
    assert rows and all("id" not in row and row["sectionId"] for row in rows)

    handler = _call(_radio_handler.handle_update_section, db, "ee", body={"description": "新说明"})
    assert handler.status_code == HTTPStatus.OK and handler.payload()["data"]["description"] == "新说明"
    # The row id no longer works, and the sectionId cannot change.
    assert _call(_radio_handler.handle_update_section, db, "college-ee", body={}).status_code == HTTPStatus.NOT_FOUND
    handler = _call(_radio_handler.handle_update_section, db, "ee", body={"sectionId": "ee2"})
    assert handler.status_code == HTTPStatus.BAD_REQUEST


def test_creating_a_section_needs_a_new_valid_section_id(world: dict[str, Any]) -> None:
    from handlers import _radio_handler

    db = world["db"]
    body = {"sectionType": "college", "name": "新学院"}
    assert _call(_radio_handler.handle_create_section, db, body=body).status_code == HTTPStatus.BAD_REQUEST
    assert _call(_radio_handler.handle_create_section, db, body={**body, "sectionId": "新学院"}).status_code == HTTPStatus.BAD_REQUEST
    assert _call(_radio_handler.handle_create_section, db, body={**body, "sectionId": "ee"}).status_code == HTTPStatus.CONFLICT
    handler = _call(_radio_handler.handle_create_section, db, body={**body, "sectionId": "new-college"})
    assert handler.status_code == HTTPStatus.CREATED and handler.payload()["data"]["sectionId"] == "new-college"


def test_section_migration_runs_once_and_leaves_only_section_ids() -> None:
    from services._db_service import default_db, migrate_db

    db = default_db()
    db["sections"].append({"id": "sec-school", "sectionType": "school", "sectionId": "school", "sectionName": "学校总分区"})
    db["sections"].append({"id": "sec9", "sectionType": "club", "sectionId": "", "sectionName": "棋社"})
    db["clubs"] = [{"id": "club1", "name": "棋社", "sectionId": "sec9"}]
    db["posts"][0].update(sectionType="school", sectionId="school", sectionName="学校总分区")
    db["posts"][1].update(sectionType="college", sectionId="college-ee", sectionName="电子工程学院")
    db.setdefault("settings", {}).pop("dataMigrations", None)

    assert migrate_db(db)
    assert all(row.get("sectionType") != "school" for row in db["sections"])
    assert next(row for row in db["sections"] if row["id"] == "sec9")["sectionId"] == "sec9"
    assert (db["posts"][0]["sectionType"], db["posts"][0]["sectionId"]) == ("general", "general")
    # A post that stored the row id now stores the sectionId.
    assert db["posts"][1]["sectionId"] == "ee"
    assert "2026-09-28-section-id" in db["settings"]["dataMigrations"]

    # Recorded: a school row added later is not touched again by this migration.
    db["sections"].append({"id": "x", "sectionType": "school", "sectionId": "x", "sectionName": "学校总分区"})
    migrate_db(db)
    assert any(row["id"] == "x" for row in db["sections"])


def test_a_renamed_default_section_is_not_added_twice() -> None:
    from services._db_service import default_db, migrate_db

    db = default_db()
    migrate_db(db)
    next(row for row in db["sections"] if row["sectionId"] == "ee")["sectionName"] = "电子工程学院（改名）"
    migrate_db(db)
    assert [row["sectionId"] for row in db["sections"]].count("ee") == 1


def test_the_migration_marker_survives_a_save(tmp_path: Path) -> None:
    from services._db_service import default_db, migrate_db
    from sql_repository import SqliteTreeholeRepository

    repo = SqliteTreeholeRepository(tmp_path / "marker.db")
    repo.initialize(default_db)
    db = repo.load_state()
    migrate_db(db)
    repo.save_state(db)
    again = repo.load_state()
    assert "2026-09-28-section-id" in again["settings"]["dataMigrations"]
    migrate_db(again)
    assert again["settings"]["dataMigrations"].count("2026-09-28-section-id") == 1


def test_primary_admin_can_create_an_admin_account(monkeypatch: pytest.MonkeyPatch) -> None:
    # It used to import build_admin_account from `services`, which does not
    # export it, so every create answered 500.
    from handlers import _admin_handler
    from services._db_service import default_db

    db = default_db()
    admin = {"id": "", "adminId": "adm-test", "username": "admin", "role": "primary"}
    monkeypatch.setattr(_admin_handler, "_require_primary_admin", lambda _h, _db: admin)
    monkeypatch.setattr(_admin_handler, "save_db", lambda _db: None)
    handler = _call(_admin_handler.handle_admin_create_account, db, body={"username": "helper01", "password": "Str0ng-Passw0rd!"})
    assert handler.status_code == HTTPStatus.OK, handler.payload()
    assert any(row.get("username") == "helper01" for row in db["adminAccounts"])
