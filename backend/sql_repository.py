from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _to_bool_int(value: Any) -> int:
    return 1 if bool(value) else 0


def _to_bool(value: Any) -> bool:
    return bool(value)


def _to_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _to_str(value: Any, default: str = "") -> str:
    if value is None:
        return default
    return str(value)


class SqliteTreeholeRepository:
    def __init__(self, db_file: Path) -> None:
        self.db_file = db_file

    def initialize(self, seed_factory: Callable[[], dict[str, Any]]) -> None:
        self.db_file.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as conn:
            self._create_schema(conn)
            count = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
            if count == 0:
                seed = seed_factory()
                self._save_state_tx(conn, seed)

    def load_state(self) -> dict[str, Any]:
        with self._connect() as conn:
            return self._load_state_tx(conn)

    def save_state(self, db: dict[str, Any]) -> None:
        with self._connect() as conn:
            self._save_state_tx(conn, db)

    def reset(self, seed_factory: Callable[[], dict[str, Any]]) -> None:
        with self._connect() as conn:
            self._create_schema(conn)
            self._save_state_tx(conn, seed_factory())

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(str(self.db_file))
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA synchronous = NORMAL")
        return conn

    def _create_schema(self, conn: sqlite3.Connection) -> None:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
              id TEXT PRIMARY KEY,
              email TEXT NOT NULL UNIQUE,
              password TEXT NOT NULL DEFAULT '',
              alias TEXT NOT NULL,
              nickname TEXT NOT NULL DEFAULT '',
              student_id TEXT NOT NULL DEFAULT '',
              avatar_url TEXT NOT NULL DEFAULT '',
              verified INTEGER NOT NULL DEFAULT 0,
              verified_at TEXT NULL,
              allow_stranger_dm INTEGER NOT NULL DEFAULT 1,
              show_contactable INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              deleted INTEGER NOT NULL DEFAULT 0,
              is_admin INTEGER NOT NULL DEFAULT 0,
              banned INTEGER NOT NULL DEFAULT 0,
              muted INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS sessions (
              token TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS email_codes (
              email TEXT PRIMARY KEY,
              code TEXT NOT NULL,
              expires_at TEXT NOT NULL,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS channels (
              name TEXT PRIMARY KEY,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS tags (
              name TEXT PRIMARY KEY,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS sensitive_words (
              word TEXT PRIMARY KEY,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS settings (
              setting_key TEXT PRIMARY KEY,
              value_int INTEGER NULL,
              value_text TEXT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS meta_seq (
              seq_key TEXT PRIMARY KEY,
              seq_value INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS posts (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              channel TEXT NOT NULL,
              has_image INTEGER NOT NULL DEFAULT 0,
              status TEXT NOT NULL,
              allow_comment INTEGER NOT NULL DEFAULT 1,
              allow_dm INTEGER NOT NULL DEFAULT 0,
              author_alias TEXT NOT NULL,
              author_id TEXT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              deleted INTEGER NOT NULL DEFAULT 0,
              review_status TEXT NOT NULL DEFAULT 'pending',
              risk_marked INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY(author_id) REFERENCES users(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS post_tags (
              post_id TEXT NOT NULL,
              tag_name TEXT NOT NULL,
              PRIMARY KEY (post_id, tag_name),
              FOREIGN KEY(post_id) REFERENCES posts(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS comments (
              id TEXT PRIMARY KEY,
              post_id TEXT NOT NULL,
              user_id TEXT NULL,
              author_alias TEXT NOT NULL,
              content TEXT NOT NULL,
              created_at TEXT NOT NULL,
              deleted INTEGER NOT NULL DEFAULT 0,
              like_count INTEGER NOT NULL DEFAULT 0,
              review_status TEXT NOT NULL DEFAULT 'pending',
              risk_marked INTEGER NOT NULL DEFAULT 0,
              parent_id TEXT NULL,
              FOREIGN KEY(post_id) REFERENCES posts(id) ON DELETE CASCADE,
              FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL,
              FOREIGN KEY(parent_id) REFERENCES comments(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS likes (
              user_id TEXT NOT NULL,
              post_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              PRIMARY KEY (user_id, post_id),
              FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
              FOREIGN KEY(post_id) REFERENCES posts(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS favorites (
              user_id TEXT NOT NULL,
              post_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              PRIMARY KEY (user_id, post_id),
              FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
              FOREIGN KEY(post_id) REFERENCES posts(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS reports (
              id TEXT PRIMARY KEY,
              user_id TEXT NULL,
              reporter_alias TEXT NOT NULL,
              target_type TEXT NOT NULL,
              target_id TEXT NOT NULL,
              reason TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              status TEXT NOT NULL DEFAULT 'pending',
              result TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              handled_at TEXT NULL,
              handled_by TEXT NULL,
              FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL,
              FOREIGN KEY(handled_by) REFERENCES users(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS dm_requests (
              id TEXT PRIMARY KEY,
              to_user_id TEXT NULL,
              from_alias TEXT NOT NULL,
              from_user_id TEXT NULL,
              from_avatar_url TEXT NOT NULL DEFAULT '',
              reason TEXT NOT NULL DEFAULT '',
              status TEXT NOT NULL DEFAULT 'pending',
              created_at TEXT NOT NULL,
              updated_at TEXT NULL,
              FOREIGN KEY(to_user_id) REFERENCES users(id) ON DELETE SET NULL,
              FOREIGN KEY(from_user_id) REFERENCES users(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS conversations (
              id TEXT PRIMARY KEY,
              user_id TEXT NULL,
              peer_user_id TEXT NULL,
              name TEXT NOT NULL,
              avatar_url TEXT NOT NULL DEFAULT '',
              last_message TEXT NOT NULL DEFAULT '',
              updated_at TEXT NOT NULL,
              FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL,
              FOREIGN KEY(peer_user_id) REFERENCES users(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS audit_logs (
              id TEXT PRIMARY KEY,
              actor_id TEXT NULL,
              action TEXT NOT NULL,
              detail TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              FOREIGN KEY(actor_id) REFERENCES users(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS media_uploads (
              id TEXT PRIMARY KEY,
              object_key TEXT NOT NULL UNIQUE,
              public_url TEXT NOT NULL,
              uploader_id TEXT NOT NULL,
              file_name TEXT NOT NULL,
              content_type TEXT NOT NULL,
              size_bytes INTEGER NOT NULL,
              sha256 TEXT NOT NULL,
              status TEXT NOT NULL,
              moderation_reason TEXT NOT NULL DEFAULT '',
              review_note TEXT NOT NULL DEFAULT '',
              reviewed_by TEXT NULL,
              reviewed_at TEXT NULL,
              created_at TEXT NOT NULL,
              post_id TEXT NULL,
              deleted INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY(uploader_id) REFERENCES users(id) ON DELETE CASCADE,
              FOREIGN KEY(post_id) REFERENCES posts(id) ON DELETE SET NULL,
              FOREIGN KEY(reviewed_by) REFERENCES users(id) ON DELETE SET NULL
            );

            CREATE INDEX IF NOT EXISTS idx_posts_channel_status_created
              ON posts(channel, status, deleted, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_posts_author_created
              ON posts(author_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_posts_review_deleted
              ON posts(review_status, deleted, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_comments_post_created
              ON comments(post_id, deleted, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_comments_user_created
              ON comments(user_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_comments_review_deleted
              ON comments(review_status, deleted, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_reports_status_created
              ON reports(status, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_reports_target
              ON reports(target_type, target_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_dm_requests_to_status_created
              ON dm_requests(to_user_id, status, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_conversations_user_updated
              ON conversations(user_id, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_created
              ON audit_logs(actor_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_media_uploads_status_created
              ON media_uploads(status, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_media_uploads_uploader_created
              ON media_uploads(uploader_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_media_uploads_post_status
              ON media_uploads(post_id, status, created_at DESC);
            """
        )
        self._ensure_column(conn, "users", "nickname", "TEXT NOT NULL DEFAULT ''")
        self._ensure_column(conn, "users", "student_id", "TEXT NOT NULL DEFAULT ''")
        self._ensure_column(conn, "users", "avatar_url", "TEXT NOT NULL DEFAULT ''")
        self._ensure_column(conn, "dm_requests", "from_user_id", "TEXT NULL")
        self._ensure_column(conn, "dm_requests", "from_avatar_url", "TEXT NOT NULL DEFAULT ''")
        self._ensure_column(conn, "conversations", "peer_user_id", "TEXT NULL")
        self._ensure_column(conn, "conversations", "avatar_url", "TEXT NOT NULL DEFAULT ''")
        conn.commit()

    def _ensure_column(self, conn: sqlite3.Connection, table_name: str, column_name: str, ddl: str) -> None:
        existing = {
            str(row["name"])
            for row in conn.execute(f"PRAGMA table_info({table_name})")
        }
        if column_name not in existing:
            conn.execute(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {ddl}")

    def _load_state_tx(self, conn: sqlite3.Connection) -> dict[str, Any]:
        db: dict[str, Any] = {
            "seq": {},
            "users": [],
            "sessions": {},
            "emailCodes": {},
            "channels": [],
            "tags": [],
            "sensitiveWords": [],
            "settings": {},
            "posts": [],
            "comments": [],
            "likes": [],
            "favorites": [],
            "reports": [],
            "dmRequests": [],
            "conversations": [],
            "auditLogs": [],
            "mediaUploads": [],
        }

        for row in conn.execute("SELECT seq_key, seq_value FROM meta_seq ORDER BY seq_key"):
            db["seq"][row["seq_key"]] = _to_int(row["seq_value"])

        for row in conn.execute(
            """
            SELECT id, email, password, alias, nickname, student_id, avatar_url, verified, verified_at, allow_stranger_dm,
                   show_contactable, created_at, deleted, is_admin, banned, muted
            FROM users
            ORDER BY created_at, id
            """
        ):
            nickname = _to_str(row["nickname"]) or _to_str(row["alias"])
            db["users"].append(
                {
                    "id": row["id"],
                    "email": row["email"],
                    "password": row["password"],
                    "alias": row["alias"],
                    "nickname": nickname,
                    "studentId": _to_str(row["student_id"]),
                    "avatarUrl": _to_str(row["avatar_url"]),
                    "verified": _to_bool(row["verified"]),
                    "verifiedAt": _to_str(row["verified_at"]),
                    "allowStrangerDm": _to_bool(row["allow_stranger_dm"]),
                    "showContactable": _to_bool(row["show_contactable"]),
                    "createdAt": row["created_at"],
                    "deleted": _to_bool(row["deleted"]),
                    "isAdmin": _to_bool(row["is_admin"]),
                    "banned": _to_bool(row["banned"]),
                    "muted": _to_bool(row["muted"]),
                }
            )

        for row in conn.execute("SELECT token, user_id FROM sessions ORDER BY created_at, token"):
            db["sessions"][row["token"]] = row["user_id"]

        for row in conn.execute("SELECT email, code, expires_at FROM email_codes ORDER BY created_at, email"):
            db["emailCodes"][row["email"]] = {"code": row["code"], "expiresAt": row["expires_at"]}

        db["channels"] = [row["name"] for row in conn.execute("SELECT name FROM channels ORDER BY sort_order, name")]
        db["tags"] = [row["name"] for row in conn.execute("SELECT name FROM tags ORDER BY sort_order, name")]
        db["sensitiveWords"] = [
            row["word"] for row in conn.execute("SELECT word FROM sensitive_words ORDER BY word")
        ]

        for row in conn.execute("SELECT setting_key, value_int, value_text FROM settings ORDER BY setting_key"):
            if row["value_int"] is not None:
                db["settings"][row["setting_key"]] = _to_int(row["value_int"])
            elif row["value_text"] is not None:
                text_val = _to_str(row["value_text"])
                try:
                    db["settings"][row["setting_key"]] = json.loads(text_val)
                except json.JSONDecodeError:
                    db["settings"][row["setting_key"]] = text_val

        tag_map: dict[str, list[str]] = {}
        for row in conn.execute("SELECT post_id, tag_name FROM post_tags ORDER BY post_id, tag_name"):
            tag_map.setdefault(row["post_id"], []).append(row["tag_name"])

        for row in conn.execute(
            """
            SELECT id, title, content, channel, has_image, status, allow_comment, allow_dm,
                   author_alias, author_id, created_at, updated_at, deleted, review_status, risk_marked
            FROM posts
            ORDER BY created_at DESC, id DESC
            """
        ):
            post_id = row["id"]
            db["posts"].append(
                {
                    "id": post_id,
                    "title": row["title"],
                    "content": row["content"],
                    "channel": row["channel"],
                    "tags": list(tag_map.get(post_id, [])),
                    "hasImage": _to_bool(row["has_image"]),
                    "status": row["status"],
                    "allowComment": _to_bool(row["allow_comment"]),
                    "allowDm": _to_bool(row["allow_dm"]),
                    "authorAlias": row["author_alias"],
                    "authorId": _to_str(row["author_id"]),
                    "createdAt": row["created_at"],
                    "updatedAt": row["updated_at"],
                    "deleted": _to_bool(row["deleted"]),
                    "reviewStatus": row["review_status"],
                    "riskMarked": _to_bool(row["risk_marked"]),
                }
            )

        for row in conn.execute(
            """
            SELECT id, post_id, user_id, author_alias, content, created_at, deleted,
                   like_count, review_status, risk_marked, parent_id
            FROM comments
            ORDER BY created_at DESC, id DESC
            """
        ):
            db["comments"].append(
                {
                    "id": row["id"],
                    "postId": row["post_id"],
                    "userId": _to_str(row["user_id"]),
                    "authorAlias": row["author_alias"],
                    "content": row["content"],
                    "createdAt": row["created_at"],
                    "deleted": _to_bool(row["deleted"]),
                    "likeCount": _to_int(row["like_count"]),
                    "reviewStatus": row["review_status"],
                    "riskMarked": _to_bool(row["risk_marked"]),
                    "parentId": _to_str(row["parent_id"]),
                }
            )

        for row in conn.execute("SELECT user_id, post_id FROM likes ORDER BY user_id, post_id"):
            db["likes"].append({"userId": row["user_id"], "postId": row["post_id"]})

        for row in conn.execute("SELECT user_id, post_id FROM favorites ORDER BY user_id, post_id"):
            db["favorites"].append({"userId": row["user_id"], "postId": row["post_id"]})

        for row in conn.execute(
            """
            SELECT id, user_id, reporter_alias, target_type, target_id, reason, description,
                   status, result, created_at, handled_at, handled_by
            FROM reports
            ORDER BY created_at DESC, id DESC
            """
        ):
            db["reports"].append(
                {
                    "id": row["id"],
                    "userId": _to_str(row["user_id"]),
                    "reporterAlias": row["reporter_alias"],
                    "targetType": row["target_type"],
                    "targetId": row["target_id"],
                    "reason": row["reason"],
                    "description": row["description"],
                    "status": row["status"],
                    "result": row["result"],
                    "createdAt": row["created_at"],
                    "handledAt": _to_str(row["handled_at"]),
                    "handledBy": _to_str(row["handled_by"]),
                }
            )

        for row in conn.execute(
            """
            SELECT id, to_user_id, from_alias, from_user_id, from_avatar_url, reason, status, created_at, updated_at
            FROM dm_requests
            ORDER BY created_at DESC, id DESC
            """
        ):
            db["dmRequests"].append(
                {
                    "id": row["id"],
                    "toUserId": _to_str(row["to_user_id"]),
                    "fromAlias": row["from_alias"],
                    "fromUserId": _to_str(row["from_user_id"]),
                    "fromAvatarUrl": _to_str(row["from_avatar_url"]),
                    "reason": row["reason"],
                    "status": row["status"],
                    "createdAt": row["created_at"],
                    "updatedAt": _to_str(row["updated_at"]),
                }
            )

        for row in conn.execute(
            """
            SELECT id, user_id, peer_user_id, name, avatar_url, last_message, updated_at
            FROM conversations
            ORDER BY updated_at DESC, id DESC
            """
        ):
            db["conversations"].append(
                {
                    "id": row["id"],
                    "userId": _to_str(row["user_id"]),
                    "peerUserId": _to_str(row["peer_user_id"]),
                    "name": row["name"],
                    "avatarUrl": _to_str(row["avatar_url"]),
                    "lastMessage": row["last_message"],
                    "updatedAt": row["updated_at"],
                }
            )

        for row in conn.execute(
            "SELECT id, actor_id, action, detail, created_at FROM audit_logs ORDER BY created_at DESC, id DESC"
        ):
            db["auditLogs"].append(
                {
                    "id": row["id"],
                    "actorId": _to_str(row["actor_id"]),
                    "action": row["action"],
                    "detail": row["detail"],
                    "createdAt": row["created_at"],
                }
            )

        for row in conn.execute(
            """
            SELECT id, object_key, public_url, uploader_id, file_name, content_type, size_bytes,
                   sha256, status, moderation_reason, review_note, reviewed_by, reviewed_at,
                   created_at, post_id, deleted
            FROM media_uploads
            ORDER BY created_at DESC, id DESC
            """
        ):
            db["mediaUploads"].append(
                {
                    "id": row["id"],
                    "objectKey": row["object_key"],
                    "url": row["public_url"],
                    "uploaderId": row["uploader_id"],
                    "fileName": row["file_name"],
                    "contentType": row["content_type"],
                    "sizeBytes": _to_int(row["size_bytes"]),
                    "sha256": row["sha256"],
                    "status": row["status"],
                    "moderationReason": row["moderation_reason"],
                    "reviewNote": row["review_note"],
                    "reviewedBy": _to_str(row["reviewed_by"]),
                    "reviewedAt": _to_str(row["reviewed_at"]),
                    "createdAt": row["created_at"],
                    "postId": _to_str(row["post_id"]),
                    "deleted": _to_bool(row["deleted"]),
                }
            )

        return db

    def _save_state_tx(self, conn: sqlite3.Connection, db: dict[str, Any]) -> None:
        conn.execute("BEGIN")
        try:
            for table in [
                "media_uploads",
                "audit_logs",
                "conversations",
                "dm_requests",
                "reports",
                "favorites",
                "likes",
                "comments",
                "post_tags",
                "posts",
                "meta_seq",
                "settings",
                "sensitive_words",
                "tags",
                "channels",
                "email_codes",
                "sessions",
                "users",
            ]:
                conn.execute(f"DELETE FROM {table}")

            created_now = now_iso()

            for row in db.get("users", []):
                if not isinstance(row, dict):
                    continue
                user_id = _to_str(row.get("id")).strip()
                email = _to_str(row.get("email")).strip().lower()
                if not user_id or not email:
                    continue
                conn.execute(
                    """
                    INSERT INTO users (
                      id, email, password, alias, nickname, student_id, avatar_url, verified, verified_at, allow_stranger_dm,
                      show_contactable, created_at, deleted, is_admin, banned, muted
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        user_id,
                        email,
                        _to_str(row.get("password")),
                        _to_str(row.get("alias")) or _to_str(row.get("nickname"), "匿名同学"),
                        _to_str(row.get("nickname")) or _to_str(row.get("alias"), "匿名同学"),
                        _to_str(row.get("studentId")),
                        _to_str(row.get("avatarUrl")),
                        _to_bool_int(row.get("verified")),
                        _to_str(row.get("verifiedAt")) or None,
                        _to_bool_int(row.get("allowStrangerDm", True)),
                        _to_bool_int(row.get("showContactable", True)),
                        _to_str(row.get("createdAt")) or created_now,
                        _to_bool_int(row.get("deleted")),
                        _to_bool_int(row.get("isAdmin")),
                        _to_bool_int(row.get("banned")),
                        _to_bool_int(row.get("muted")),
                    ),
                )

            sessions = db.get("sessions", {})
            if isinstance(sessions, dict):
                for token, user_id in sessions.items():
                    token_str = _to_str(token).strip()
                    uid = _to_str(user_id).strip()
                    if token_str and uid:
                        conn.execute(
                            "INSERT INTO sessions (token, user_id, created_at) VALUES (?, ?, ?)",
                            (token_str, uid, created_now),
                        )

            email_codes = db.get("emailCodes", {})
            if isinstance(email_codes, dict):
                for email, row in email_codes.items():
                    email_str = _to_str(email).strip().lower()
                    if not email_str:
                        continue
                    if isinstance(row, dict):
                        code = _to_str(row.get("code")).strip() or "000000"
                        expires_at = _to_str(row.get("expiresAt")) or created_now
                    else:
                        code = "000000"
                        expires_at = created_now
                    conn.execute(
                        "INSERT INTO email_codes (email, code, expires_at, created_at) VALUES (?, ?, ?, ?)",
                        (email_str, code, expires_at, created_now),
                    )

            for index, name in enumerate(db.get("channels", []), start=1):
                n = _to_str(name).strip()
                if n:
                    conn.execute(
                        "INSERT INTO channels (name, sort_order, created_at) VALUES (?, ?, ?)",
                        (n, index, created_now),
                    )

            for index, name in enumerate(db.get("tags", []), start=1):
                n = _to_str(name).strip()
                if n:
                    conn.execute(
                        "INSERT INTO tags (name, sort_order, created_at) VALUES (?, ?, ?)",
                        (n, index, created_now),
                    )

            for word in db.get("sensitiveWords", []):
                w = _to_str(word).strip()
                if w:
                    conn.execute(
                        "INSERT INTO sensitive_words (word, created_at) VALUES (?, ?)",
                        (w, created_now),
                    )

            settings = db.get("settings", {})
            if isinstance(settings, dict):
                for key, value in settings.items():
                    setting_key = _to_str(key).strip()
                    if not setting_key:
                        continue
                    value_int: int | None = None
                    value_text: str | None = None
                    try:
                        value_int = int(value)
                    except (TypeError, ValueError):
                        if value is not None:
                            if isinstance(value, (dict, list)):
                                value_text = json.dumps(value, ensure_ascii=False)
                            else:
                                value_text = _to_str(value)
                    conn.execute(
                        """
                        INSERT INTO settings (setting_key, value_int, value_text, updated_at)
                        VALUES (?, ?, ?, ?)
                        """,
                        (setting_key, value_int, value_text, created_now),
                    )

            seq = db.get("seq", {})
            if isinstance(seq, dict):
                for key, value in seq.items():
                    seq_key = _to_str(key).strip()
                    if not seq_key:
                        continue
                    conn.execute(
                        "INSERT INTO meta_seq (seq_key, seq_value) VALUES (?, ?)",
                        (seq_key, _to_int(value, 0)),
                    )

            for post in db.get("posts", []):
                if not isinstance(post, dict):
                    continue
                post_id = _to_str(post.get("id")).strip()
                if not post_id:
                    continue
                conn.execute(
                    """
                    INSERT INTO posts (
                      id, title, content, channel, has_image, status, allow_comment, allow_dm,
                      author_alias, author_id, created_at, updated_at, deleted, review_status, risk_marked
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        post_id,
                        _to_str(post.get("title")),
                        _to_str(post.get("content")),
                        _to_str(post.get("channel"), "未分类"),
                        _to_bool_int(post.get("hasImage")),
                        _to_str(post.get("status"), "ongoing"),
                        _to_bool_int(post.get("allowComment", True)),
                        _to_bool_int(post.get("allowDm", False)),
                        _to_str(post.get("authorAlias"), "匿名同学"),
                        _to_str(post.get("authorId")) or None,
                        _to_str(post.get("createdAt")) or created_now,
                        _to_str(post.get("updatedAt")) or created_now,
                        _to_bool_int(post.get("deleted")),
                        _to_str(post.get("reviewStatus"), "pending"),
                        _to_bool_int(post.get("riskMarked")),
                    ),
                )
                for tag_name in post.get("tags", []):
                    t = _to_str(tag_name).strip()
                    if t:
                        conn.execute(
                            "INSERT OR IGNORE INTO post_tags (post_id, tag_name) VALUES (?, ?)",
                            (post_id, t),
                        )

            for comment in db.get("comments", []):
                if not isinstance(comment, dict):
                    continue
                comment_id = _to_str(comment.get("id")).strip()
                post_id = _to_str(comment.get("postId")).strip()
                if not comment_id or not post_id:
                    continue
                conn.execute(
                    """
                    INSERT INTO comments (
                      id, post_id, user_id, author_alias, content, created_at, deleted,
                      like_count, review_status, risk_marked, parent_id
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        comment_id,
                        post_id,
                        _to_str(comment.get("userId")) or None,
                        _to_str(comment.get("authorAlias"), "匿名同学"),
                        _to_str(comment.get("content")),
                        _to_str(comment.get("createdAt")) or created_now,
                        _to_bool_int(comment.get("deleted")),
                        _to_int(comment.get("likeCount"), 0),
                        _to_str(comment.get("reviewStatus"), "pending"),
                        _to_bool_int(comment.get("riskMarked")),
                        _to_str(comment.get("parentId")) or None,
                    ),
                )

            for row in db.get("likes", []):
                if not isinstance(row, dict):
                    continue
                user_id = _to_str(row.get("userId")).strip()
                post_id = _to_str(row.get("postId")).strip()
                if user_id and post_id:
                    conn.execute(
                        "INSERT OR IGNORE INTO likes (user_id, post_id, created_at) VALUES (?, ?, ?)",
                        (user_id, post_id, created_now),
                    )

            for row in db.get("favorites", []):
                if not isinstance(row, dict):
                    continue
                user_id = _to_str(row.get("userId")).strip()
                post_id = _to_str(row.get("postId")).strip()
                if user_id and post_id:
                    conn.execute(
                        "INSERT OR IGNORE INTO favorites (user_id, post_id, created_at) VALUES (?, ?, ?)",
                        (user_id, post_id, created_now),
                    )

            for row in db.get("reports", []):
                if not isinstance(row, dict):
                    continue
                rid = _to_str(row.get("id")).strip()
                if not rid:
                    continue
                conn.execute(
                    """
                    INSERT INTO reports (
                      id, user_id, reporter_alias, target_type, target_id, reason, description,
                      status, result, created_at, handled_at, handled_by
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        rid,
                        _to_str(row.get("userId")) or None,
                        _to_str(row.get("reporterAlias"), "匿名同学"),
                        _to_str(row.get("targetType"), "other"),
                        _to_str(row.get("targetId"), "unknown"),
                        _to_str(row.get("reason"), "其他"),
                        _to_str(row.get("description")),
                        _to_str(row.get("status"), "pending"),
                        _to_str(row.get("result")),
                        _to_str(row.get("createdAt")) or created_now,
                        _to_str(row.get("handledAt")) or None,
                        _to_str(row.get("handledBy")) or None,
                    ),
                )

            for row in db.get("dmRequests", []):
                if not isinstance(row, dict):
                    continue
                rid = _to_str(row.get("id")).strip()
                if not rid:
                    continue
                conn.execute(
                    """
                    INSERT INTO dm_requests (
                      id, to_user_id, from_alias, from_user_id, from_avatar_url, reason, status, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        rid,
                        _to_str(row.get("toUserId")) or None,
                        _to_str(row.get("fromAlias"), "匿名同学"),
                        _to_str(row.get("fromUserId")) or None,
                        _to_str(row.get("fromAvatarUrl")),
                        _to_str(row.get("reason")),
                        _to_str(row.get("status"), "pending"),
                        _to_str(row.get("createdAt")) or created_now,
                        _to_str(row.get("updatedAt")) or None,
                    ),
                )

            for row in db.get("conversations", []):
                if not isinstance(row, dict):
                    continue
                cid = _to_str(row.get("id")).strip()
                if not cid:
                    continue
                conn.execute(
                    """
                    INSERT INTO conversations (
                      id, user_id, peer_user_id, name, avatar_url, last_message, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        cid,
                        _to_str(row.get("userId")) or None,
                        _to_str(row.get("peerUserId")) or None,
                        _to_str(row.get("name"), "会话"),
                        _to_str(row.get("avatarUrl")),
                        _to_str(row.get("lastMessage")),
                        _to_str(row.get("updatedAt")) or created_now,
                    ),
                )

            for row in db.get("auditLogs", []):
                if not isinstance(row, dict):
                    continue
                aid = _to_str(row.get("id")).strip()
                if not aid:
                    continue
                conn.execute(
                    """
                    INSERT INTO audit_logs (
                      id, actor_id, action, detail, created_at
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    (
                        aid,
                        _to_str(row.get("actorId")) or None,
                        _to_str(row.get("action"), "action"),
                        _to_str(row.get("detail")),
                        _to_str(row.get("createdAt")) or created_now,
                    ),
                )

            for row in db.get("mediaUploads", []):
                if not isinstance(row, dict):
                    continue
                upload_id = _to_str(row.get("id")).strip()
                object_key = _to_str(row.get("objectKey")).strip()
                if not upload_id or not object_key:
                    continue
                conn.execute(
                    """
                    INSERT INTO media_uploads (
                      id, object_key, public_url, uploader_id, file_name, content_type, size_bytes,
                      sha256, status, moderation_reason, review_note, reviewed_by, reviewed_at,
                      created_at, post_id, deleted
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        upload_id,
                        object_key,
                        _to_str(row.get("url")),
                        _to_str(row.get("uploaderId")),
                        _to_str(row.get("fileName"), "upload.bin"),
                        _to_str(row.get("contentType"), "application/octet-stream"),
                        _to_int(row.get("sizeBytes"), 0),
                        _to_str(row.get("sha256")),
                        _to_str(row.get("status"), "pending"),
                        _to_str(row.get("moderationReason")),
                        _to_str(row.get("reviewNote")),
                        _to_str(row.get("reviewedBy")) or None,
                        _to_str(row.get("reviewedAt")) or None,
                        _to_str(row.get("createdAt")) or created_now,
                        _to_str(row.get("postId")) or None,
                        _to_bool_int(row.get("deleted")),
                    ),
                )

            conn.commit()
        except Exception:
            conn.rollback()
            raise
