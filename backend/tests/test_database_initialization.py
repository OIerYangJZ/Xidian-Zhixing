from __future__ import annotations

import json
import os
import socket
import sqlite3
import subprocess
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any

import pytest

from sql_repository import SqliteTreeholeRepository


BACKEND_DIR = Path(__file__).resolve().parents[1]


def _production_env(db_file: Path, storage_dir: Path, web_root: Path) -> dict[str, str]:
    env = os.environ.copy()
    env.update(
        {
            "BACKEND_ENV": "production",
            "BACKEND_HOST": "127.0.0.1",
            "BACKEND_PORT": "8080",
            "BACKEND_SEED_DEMO_DATA": "false",
            "BACKEND_ADMIN_USERNAME": "production-test-admin",
            "BACKEND_ADMIN_PASSWORD": "ProductionTestPass123!",
            "BACKEND_DB_FILE": str(db_file),
            "BACKEND_OBJECT_STORAGE_BACKEND": "local",
            "BACKEND_STORAGE_DIR": str(storage_dir),
            "BACKEND_WEB_ROOT": str(web_root),
            "BACKEND_CORS_ALLOWED_ORIGINS": "https://zhixing.xidian.edu.cn",
            "BACKEND_AUTH_ALLOWED_STUDENT_IDS": "2500001",
            "BACKEND_MAX_REQUEST_BODY_MB": "20",
            "BACKEND_ENABLE_XIDIAN_AUTH": "true",
            "BACKEND_XIDIAN_PUBLIC_ORIGIN": "https://zhixing.xidian.edu.cn",
            "BACKEND_ALLOW_DEBUG_VERIFY_CODE": "false",
            "BACKEND_INCLUDE_DEBUG_CODE": "false",
            "PYTHONDONTWRITEBYTECODE": "1",
        }
    )
    env.pop("BACKEND_IMPORT_LEGACY_JSON", None)
    env.pop("BACKEND_AI_BASE_URL", None)
    env.pop("BACKEND_AI_API_KEY", None)
    env.pop("AI_BASE_URL", None)
    env.pop("AI_API_KEY", None)
    return env


def _run_production_ensure(db_file: Path, tmp_path: Path) -> dict[str, Any]:
    script = """
import json
import sqlite3
import server

server.ensure_db()
with sqlite3.connect(server.SQL_DB_FILE) as conn:
    result = {
        "users": conn.execute("SELECT COUNT(*) FROM users").fetchone()[0],
        "posts": conn.execute("SELECT COUNT(*) FROM posts").fetchone()[0],
        "admins": conn.execute("SELECT COUNT(*) FROM admin_accounts").fetchone()[0],
        "admin_hash": conn.execute(
            "SELECT password_hash FROM admin_accounts ORDER BY id LIMIT 1"
        ).fetchone()[0],
        "initialized": conn.execute(
            "SELECT COUNT(*) FROM repository_meta WHERE meta_key = 'initialized'"
        ).fetchone()[0],
        "foreign_keys": conn.execute("PRAGMA foreign_key_check").fetchall(),
    }
print(json.dumps(result))
"""
    completed = subprocess.run(
        [sys.executable, "-c", script],
        cwd=BACKEND_DIR,
        env=_production_env(db_file, tmp_path / "storage", tmp_path / "web"),
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    )
    return json.loads(completed.stdout.strip().splitlines()[-1])


def test_production_empty_database_first_ensure_db(tmp_path: Path) -> None:
    db_file = tmp_path / "production-first.db"
    assert not db_file.exists()

    result = _run_production_ensure(db_file, tmp_path)

    assert db_file.exists()
    assert result["users"] == 0
    assert result["posts"] == 0
    assert result["admins"] == 1
    assert result["initialized"] == 1


def test_production_ensure_db_succeeds_twice_without_reseeding(tmp_path: Path) -> None:
    db_file = tmp_path / "production-twice.db"

    first = _run_production_ensure(db_file, tmp_path)
    second = _run_production_ensure(db_file, tmp_path)

    assert second == first


def test_production_database_has_no_foreign_key_violations(tmp_path: Path) -> None:
    result = _run_production_ensure(tmp_path / "production-fk.db", tmp_path)

    assert result["foreign_keys"] == []


def _valid_repository_state() -> dict[str, Any]:
    return {
        "seq": {"user": 1, "post": 1},
        "users": [
            {
                "id": "u1",
                "email": "user@example.com",
                "password": "hash",
                "alias": "User",
                "nickname": "User",
                "createdAt": "2026-07-22T00:00:00+00:00",
            }
        ],
        "settings": {"sentinel": "before"},
        "posts": [
            {
                "id": "p1",
                "title": "Valid post",
                "content": "content",
                "authorAlias": "User",
                "authorId": "u1",
                "createdAt": "2026-07-22T00:00:00+00:00",
                "updatedAt": "2026-07-22T00:00:00+00:00",
            }
        ],
    }


def test_failed_initialization_transaction_rolls_back_completely(tmp_path: Path) -> None:
    db_file = tmp_path / "failed-initialization.db"
    repository = SqliteTreeholeRepository(db_file)
    invalid_state = _valid_repository_state()
    invalid_state["users"] = []

    with pytest.raises(sqlite3.IntegrityError, match="FOREIGN KEY constraint failed"):
        repository.initialize(lambda: invalid_state)

    with sqlite3.connect(db_file) as conn:
        assert conn.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        ).fetchall() == []

    repository.initialize(_valid_repository_state)
    recovered = repository.load_state()
    assert [user["id"] for user in recovered["users"]] == ["u1"]
    assert [post["id"] for post in recovered["posts"]] == ["p1"]


def test_failed_save_restores_existing_database_state(tmp_path: Path) -> None:
    repository = SqliteTreeholeRepository(tmp_path / "rollback-existing.db")
    repository.initialize(_valid_repository_state)
    invalid_state = _valid_repository_state()
    invalid_state["posts"][0]["authorId"] = "missing-user"

    with pytest.raises(sqlite3.IntegrityError, match="FOREIGN KEY constraint failed"):
        repository.save_state(invalid_state)

    recovered = repository.load_state()
    assert recovered["settings"]["sentinel"] == "before"
    assert recovered["posts"][0]["authorId"] == "u1"
    with sqlite3.connect(repository.db_file) as conn:
        assert conn.execute("PRAGMA foreign_key_check").fetchall() == []


def test_existing_database_without_marker_is_preserved(tmp_path: Path) -> None:
    repository = SqliteTreeholeRepository(tmp_path / "existing-upgrade.db")
    repository.initialize(_valid_repository_state)
    with sqlite3.connect(repository.db_file) as conn:
        conn.execute("DELETE FROM repository_meta WHERE meta_key = 'initialized'")
        conn.commit()

    def unexpected_seed() -> dict[str, Any]:
        raise AssertionError("existing database must not be reseeded")

    repository.initialize(unexpected_seed)

    recovered = repository.load_state()
    assert recovered["settings"]["sentinel"] == "before"
    assert [post["id"] for post in recovered["posts"]] == ["p1"]


def test_email_code_survives_repository_restart_with_leading_zero(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import _globals
    from services._db_service import default_db

    monkeypatch.setattr(_globals, "SEED_DEMO_DATA", False)
    email = "2500020@stu.xidian.edu.cn"
    state = default_db()
    state["emailCodes"][email] = {
        "code": "012345",
        "expiresAt": "2099-07-23T08:10:00+00:00",
        "createdAt": "2099-07-23T08:00:00+00:00",
        "recordId": "restart-record",
        "purpose": "email_verification",
        "attempts": 0,
        "usedAt": "",
    }
    db_file = tmp_path / "verification-restart.db"
    SqliteTreeholeRepository(db_file).initialize(lambda: state)

    restarted = SqliteTreeholeRepository(db_file).load_state()

    assert restarted["emailCodes"][email]["code"] == "012345"
    assert isinstance(restarted["emailCodes"][email]["code"], str)
    assert restarted["emailCodes"][email]["purpose"] == "email_verification"


def test_legacy_integer_code_column_is_migrated_to_text(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import _globals
    from services._db_service import default_db

    monkeypatch.setattr(_globals, "SEED_DEMO_DATA", False)
    db_file = tmp_path / "legacy-code-type.db"
    repository = SqliteTreeholeRepository(db_file)
    repository.initialize(default_db)
    with sqlite3.connect(db_file) as conn:
        conn.execute("ALTER TABLE email_codes RENAME TO email_codes_text")
        conn.execute(
            """
            CREATE TABLE email_codes (
              email TEXT PRIMARY KEY,
              code INTEGER NOT NULL,
              expires_at TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            INSERT INTO email_codes (email, code, expires_at, created_at)
            VALUES (?, ?, ?, ?)
            """,
            (
                "2500021@stu.xidian.edu.cn",
                123456,
                "2099-07-23T08:10:00+00:00",
                "2099-07-23T08:00:00+00:00",
            ),
        )
        conn.execute("DROP TABLE email_codes_text")
        conn.commit()

    repository.initialize(default_db)
    with sqlite3.connect(db_file) as conn:
        declared_type = next(
            row[2]
            for row in conn.execute("PRAGMA table_info(email_codes)")
            if row[1] == "code"
        )
    state = repository.load_state()
    state["emailCodes"]["2500021@stu.xidian.edu.cn"]["code"] = "012345"
    repository.save_state(state)
    restarted = SqliteTreeholeRepository(db_file).load_state()

    assert declared_type.upper() == "TEXT"
    assert restarted["emailCodes"]["2500021@stu.xidian.edu.cn"]["code"] == "012345"


def test_load_migration_is_idempotent_after_repository_round_trip(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import _globals
    from services._db_service import default_db, migrate_db

    monkeypatch.setattr(_globals, "SEED_DEMO_DATA", False)
    repository = SqliteTreeholeRepository(tmp_path / "idempotent-migration.db")
    repository.initialize(default_db)
    first = repository.load_state()
    if migrate_db(first):
        repository.save_state(first)

    second = repository.load_state()

    assert migrate_db(second) is False


def test_server_binds_production_loopback_port_8080(tmp_path: Path) -> None:
    db_file = tmp_path / "server.db"
    process = subprocess.Popen(
        [sys.executable, "server.py"],
        cwd=BACKEND_DIR,
        env=_production_env(db_file, tmp_path / "storage", tmp_path / "web"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        deadline = time.monotonic() + 15
        last_error: Exception | None = None
        while time.monotonic() < deadline:
            if process.poll() is not None:
                stdout, stderr = process.communicate(timeout=1)
                pytest.fail(
                    f"server exited before binding 127.0.0.1:8080\nstdout:\n{stdout}\nstderr:\n{stderr}"
                )
            try:
                with socket.create_connection(("127.0.0.1", 8080), timeout=0.25):
                    break
            except OSError as exc:
                last_error = exc
                time.sleep(0.05)
        else:
            pytest.fail(f"server did not bind 127.0.0.1:8080: {last_error}")

        with urllib.request.urlopen("http://127.0.0.1:8080/api/health", timeout=3) as response:
            payload = json.load(response)
        assert response.status == 200
        assert payload["status"] == "healthy"
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
