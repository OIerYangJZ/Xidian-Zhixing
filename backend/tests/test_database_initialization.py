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
            "BACKEND_SMTP_HOST": "smtp.example.com",
            "BACKEND_SMTP_PORT": "465",
            "BACKEND_SMTP_USERNAME": "noreply@example.com",
            "BACKEND_SMTP_PASSWORD": "ProductionSmtpPass123!",
            "BACKEND_SMTP_FROM_EMAIL": "noreply@example.com",
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
