"""认证接口测试。"""
from __future__ import annotations

import io
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from http import HTTPStatus
from pathlib import Path
from typing import Any

import pytest

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))


class FakeJsonHandler:
    def __init__(self) -> None:
        self.headers: dict[str, str] = {}
        self.wfile = io.BytesIO()
        self.status_code = 0
        self.response_headers: list[tuple[str, str]] = []
        self.request_id = "test-request-id"
        self.client_address = ("127.0.0.1", 12345)

    def send_response(self, code: int) -> None:
        self.status_code = code

    def send_header(self, key: str, value: str) -> None:
        self.response_headers.append((key, value))

    def end_headers(self) -> None:
        pass


class TestAuthHelpers:
    """测试认证相关的辅助函数。"""

    def test_is_campus_email_valid(self):
        """测试校园邮箱验证 - 有效邮箱。"""
        from server import is_campus_email

        assert is_campus_email("student@stu.xidian.edu.cn") is True
        assert is_campus_email("STUDENT@Stu.Xidian.EDU.CN") is True

    def test_is_campus_email_invalid(self):
        """测试校园邮箱验证 - 无效邮箱。"""
        from server import is_campus_email

        assert is_campus_email("teacher@xidian.edu.cn") is False
        assert is_campus_email("student@gmail.com") is False
        assert is_campus_email("student@qq.com") is False
        assert is_campus_email("notanemail") is False
        assert is_campus_email("") is False

    def test_hash_password(self):
        """测试密码哈希。"""
        from server import hash_password, is_password_hashed, verify_password

        password = "test_password_123"
        hashed = hash_password(password)

        # 验证哈希格式
        assert is_password_hashed(hashed) is True
        assert hashed.startswith("pbkdf2_sha256$")

        # 验证密码匹配
        assert verify_password(hashed, password) is True
        assert verify_password(hashed, "wrong_password") is False

    def test_hash_password_different_hashes(self):
        """测试相同密码生成不同哈希（salt）。"""
        from server import hash_password

        password = "same_password"
        hash1 = hash_password(password)
        hash2 = hash_password(password)

        # 相同密码应该生成不同的哈希（因为 salt 不同）
        assert hash1 != hash2

        # 但两个哈希都应该能验证原始密码
        from server import verify_password

        assert verify_password(hash1, password) is True
        assert verify_password(hash2, password) is True

    def test_random_code_length(self):
        """测试随机验证码长度。"""
        from server import random_code

        code = random_code()
        assert len(code) == 6
        assert code.isdigit() is True

    def test_random_code_uniqueness(self):
        """测试随机验证码唯一性。"""
        from server import random_code

        codes = [random_code() for _ in range(100)]
        # 允许极少数碰撞，但大多数应该唯一
        assert len(set(codes)) > 90

    def test_student_id_from_email(self):
        """测试从邮箱提取学号。"""
        from server import student_id_from_email

        assert student_id_from_email("2111111@stu.xidian.edu.cn") == "2111111"

    def test_is_valid_student_id(self):
        """测试学号格式验证。"""
        from server import is_valid_student_id

        # 有效学号
        assert is_valid_student_id("2111111") is True
        assert is_valid_student_id("2023001") is True
        assert is_valid_student_id("ABC12345") is True

        # 无效学号
        assert is_valid_student_id("12345") is False  # 太短
        assert is_valid_student_id("") is False  # 为空
        assert is_valid_student_id("abc") is False  # 太短

    def test_sanitize_alias(self):
        """测试昵称清理。"""
        from server import sanitize_alias

        # 基本测试
        assert sanitize_alias("正常昵称") == "正常昵称"
        assert sanitize_alias("  带空格  ") == "带空格"
        assert sanitize_alias("") == "匿名同学"
        assert sanitize_alias("   ") == "匿名同学"

        # 长度限制
        long_name = "a" * 30
        result = sanitize_alias(long_name)
        assert len(result) <= 24

    def test_normalize_avatar_url(self):
        """测试头像 URL 规范化。"""
        from server import normalize_avatar_url

        # 有效的存储路径
        assert normalize_avatar_url("/api/storage/avatar.png") == "/api/storage/avatar.png"

        # 有效的 HTTP URL
        assert normalize_avatar_url("https://example.com/avatar.png") == "https://example.com/avatar.png"

        # 无效值
        assert normalize_avatar_url("") == ""
        assert normalize_avatar_url("invalid") == ""


class TestEmailCodeAuth:
    """测试邮箱验证码登录 / 注册。"""

    def test_verify_auto_registers_missing_user(self, monkeypatch: pytest.MonkeyPatch):
        """未注册用户验证码验证后自动注册并登录。"""
        from helpers._datetime_helpers import now_utc
        from services._db_service import default_db
        from handlers import _auth_handler

        email = "2500001@stu.xidian.edu.cn"
        code = "654321"
        db = default_db()
        db["emailCodes"][email] = {
            "code": code,
            "expiresAt": (now_utc() + _auth_handler.timedelta(minutes=10)).isoformat(),
        }
        handler = FakeJsonHandler()

        monkeypatch.setattr(
            _auth_handler,
            "read_json_body",
            lambda _handler: {"email": email, "code": code},
        )
        monkeypatch.setattr(_auth_handler, "save_db", lambda _db: None)

        _auth_handler.handle_verify(handler, db)

        payload = json.loads(handler.wfile.getvalue().decode("utf-8"))
        created_user = next(user for user in db["users"] if user["email"] == email)

        assert handler.status_code == HTTPStatus.OK
        assert payload["data"]["token"]
        assert payload["data"]["studentId"] == "2500001"
        assert created_user["verified"] is True
        assert created_user["nickname"] == "西电同学0001"
        assert db["emailCodes"][email]["code"] == ""
        assert db["emailCodes"][email]["usedAt"]
        assert payload["data"]["token"] in db["sessions"]

    @staticmethod
    def _record(
        code: str,
        *,
        purpose: str = "email_verification",
        expires_at: datetime | None = None,
        used_at: str = "",
        attempts: int = 0,
    ) -> dict[str, Any]:
        created_at = datetime.now(timezone.utc)
        return {
            "code": code,
            "createdAt": created_at.isoformat(),
            "expiresAt": (
                expires_at or created_at + timedelta(minutes=10)
            ).isoformat(),
            "recordId": "record-test",
            "purpose": purpose,
            "attempts": attempts,
            "usedAt": used_at,
        }

    @staticmethod
    def _verify(
        monkeypatch: pytest.MonkeyPatch,
        db: dict[str, Any],
        *,
        email: str,
        code: Any,
    ) -> tuple[FakeJsonHandler, dict[str, Any]]:
        from handlers import _auth_handler

        handler = FakeJsonHandler()
        monkeypatch.setattr(
            _auth_handler,
            "read_json_body",
            lambda _handler: {"email": email, "code": code},
        )
        monkeypatch.setattr(_auth_handler, "save_db", lambda _db: None)
        _auth_handler.handle_verify(handler, db)
        return handler, json.loads(handler.wfile.getvalue().decode("utf-8"))

    def test_wrong_code_increments_attempts(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ):
        from services._db_service import default_db

        email = "2500010@stu.xidian.edu.cn"
        db = default_db()
        db["emailCodes"][email] = self._record("654321")

        handler, payload = self._verify(
            monkeypatch,
            db,
            email=email,
            code="111111",
        )

        assert handler.status_code == HTTPStatus.BAD_REQUEST
        assert payload["message"] == "验证码错误"
        assert db["emailCodes"][email]["attempts"] == 1

    def test_fifth_wrong_code_requires_a_new_code(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ):
        from services._db_service import default_db

        email = "2500018@stu.xidian.edu.cn"
        db = default_db()
        db["emailCodes"][email] = self._record("654321", attempts=4)

        handler, payload = self._verify(
            monkeypatch,
            db,
            email=email,
            code="111111",
        )

        assert handler.status_code == HTTPStatus.TOO_MANY_REQUESTS
        assert payload["message"] == "验证码尝试次数过多，请重新发送"

    def test_leading_zero_code_stays_a_string_and_succeeds(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ):
        from services._db_service import default_db

        email = "2500011@stu.xidian.edu.cn"
        db = default_db()
        db["emailCodes"][email] = self._record("012345")

        handler, payload = self._verify(
            monkeypatch,
            db,
            email=email,
            code="012345",
        )

        assert handler.status_code == HTTPStatus.OK
        assert payload["success"] is True

    def test_numeric_json_code_is_rejected_instead_of_converted(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ):
        from services._db_service import default_db

        email = "2500019@stu.xidian.edu.cn"
        db = default_db()
        db["emailCodes"][email] = self._record("12345")

        handler, payload = self._verify(
            monkeypatch,
            db,
            email=email,
            code=12345,
        )

        assert handler.status_code == HTTPStatus.BAD_REQUEST
        assert payload["message"] == "验证码格式错误"

    @pytest.mark.parametrize(
        "submitted_email",
        [
            "  2500012@stu.xidian.edu.cn  ",
            "2500012@STU.XIDIAN.EDU.CN",
        ],
    )
    def test_email_normalization_is_shared_by_lookup(
        self,
        monkeypatch: pytest.MonkeyPatch,
        submitted_email: str,
    ):
        from services._db_service import default_db

        normalized = "2500012@stu.xidian.edu.cn"
        db = default_db()
        db["emailCodes"][normalized] = self._record("234567")

        handler, _ = self._verify(
            monkeypatch,
            db,
            email=submitted_email,
            code="234567",
        )

        assert handler.status_code == HTTPStatus.OK

    def test_only_latest_resend_code_is_valid(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ):
        from handlers import _auth_handler
        from services._db_service import default_db

        email = "2500013@stu.xidian.edu.cn"
        db = default_db()
        generated = iter(("111111", "222222"))
        monkeypatch.setattr(
            _auth_handler,
            "_verification_code_or_error",
            lambda _handler: (next(generated), False),
        )
        monkeypatch.setattr(_auth_handler, "save_db", lambda _db: None)
        monkeypatch.setattr(
            _auth_handler,
            "read_json_body",
            lambda _handler: {"email": email},
        )

        _auth_handler.handle_send_code(FakeJsonHandler(), db)
        _auth_handler.handle_send_code(FakeJsonHandler(), db)

        old_handler, _ = self._verify(
            monkeypatch,
            db,
            email=email,
            code="111111",
        )
        new_handler, _ = self._verify(
            monkeypatch,
            db,
            email=email,
            code="222222",
        )

        assert old_handler.status_code == HTTPStatus.BAD_REQUEST
        assert new_handler.status_code == HTTPStatus.OK

    def test_resend_persists_record_before_smtp_delivery(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ):
        from handlers import _auth_handler
        from services._db_service import default_db

        email = "2500019@stu.xidian.edu.cn"
        db = default_db()
        events: list[str] = []
        monkeypatch.setattr(
            _auth_handler,
            "_verification_code_or_error",
            lambda _handler: ("012345", True),
        )
        monkeypatch.setattr(
            _auth_handler,
            "save_db",
            lambda state: events.append(
                str(state["emailCodes"][email]["code"]),
            ),
        )

        def assert_committed_before_mail(
            *,
            to_email: str,
            code: str,
            expires_in_minutes: int,
        ) -> None:
            assert to_email == email
            assert code == "012345"
            assert expires_in_minutes == 10
            assert events == ["012345"]

        monkeypatch.setattr(
            _auth_handler,
            "send_verification_email",
            assert_committed_before_mail,
        )
        monkeypatch.setattr(
            _auth_handler,
            "read_json_body",
            lambda _handler: {"email": email},
        )
        handler = FakeJsonHandler()

        _auth_handler.handle_send_code(handler, db)

        assert handler.status_code == HTTPStatus.OK

    def test_expiry_uses_utc_and_accepts_exact_boundary(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ):
        from handlers import _auth_handler
        from services._db_service import default_db

        email = "2500014@stu.xidian.edu.cn"
        boundary = datetime(2026, 7, 23, 8, 10, tzinfo=timezone.utc)
        monkeypatch.setattr(_auth_handler, "now_utc", lambda: boundary)

        valid_db = default_db()
        valid_db["emailCodes"][email] = self._record(
            "345678",
            expires_at=boundary,
        )
        valid_handler, _ = self._verify(
            monkeypatch,
            valid_db,
            email=email,
            code="345678",
        )

        expired_db = default_db()
        expired_db["emailCodes"][email] = self._record(
            "345678",
            expires_at=boundary - timedelta(microseconds=1),
        )
        expired_handler, expired_payload = self._verify(
            monkeypatch,
            expired_db,
            email=email,
            code="345678",
        )

        assert valid_handler.status_code == HTTPStatus.OK
        assert expired_handler.status_code == HTTPStatus.BAD_REQUEST
        assert expired_payload["message"] == "验证码已过期"

    def test_used_code_cannot_be_replayed(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ):
        from services._db_service import default_db

        email = "2500015@stu.xidian.edu.cn"
        db = default_db()
        db["emailCodes"][email] = self._record("456789")

        first, _ = self._verify(
            monkeypatch,
            db,
            email=email,
            code="456789",
        )
        second, payload = self._verify(
            monkeypatch,
            db,
            email=email,
            code="456789",
        )

        assert first.status_code == HTTPStatus.OK
        assert second.status_code == HTTPStatus.BAD_REQUEST
        assert payload["message"] == "验证码已失效，请重新发送"
        assert len(db["sessions"]) == 1

    def test_different_purpose_cannot_be_mixed(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ):
        from services._db_service import default_db

        email = "2500016@stu.xidian.edu.cn"
        db = default_db()
        db["emailCodes"][email] = self._record(
            "567890",
            purpose="password_reset",
        )

        handler, _ = self._verify(
            monkeypatch,
            db,
            email=email,
            code="567890",
        )

        assert handler.status_code == HTTPStatus.BAD_REQUEST

    def test_structured_log_never_contains_plaintext_code(
        self,
        monkeypatch: pytest.MonkeyPatch,
        caplog: pytest.LogCaptureFixture,
    ):
        from services._db_service import default_db

        email = "2500017@stu.xidian.edu.cn"
        db = default_db()
        db["emailCodes"][email] = self._record("678901")

        with caplog.at_level("INFO", logger="xduwhisperbox.auth"):
            self._verify(
                monkeypatch,
                db,
                email=email,
                code="000000",
            )

        assert "678901" not in caplog.text
        assert "000000" not in caplog.text
        assert caplog.records[-1].structured["result"] == "mismatch"

    def test_verify_rejects_email_outside_private_beta_allowlist(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ):
        import _globals
        from handlers import _auth_handler
        from services._db_service import default_db

        email = "2500999@stu.xidian.edu.cn"
        db = default_db()
        handler = FakeJsonHandler()
        monkeypatch.setattr(
            _globals,
            "AUTH_ALLOWED_EMAILS",
            {"2500001@stu.xidian.edu.cn"},
        )
        monkeypatch.setattr(
            _auth_handler,
            "read_json_body",
            lambda _handler: {"email": email, "code": "654321"},
        )

        _auth_handler.handle_verify(handler, db)

        payload = json.loads(handler.wfile.getvalue().decode("utf-8"))
        assert handler.status_code == HTTPStatus.FORBIDDEN
        assert payload["message"] == "当前仅向项目组测试账号开放"
        assert all(user.get("email") != email for user in db["users"])


class TestRegisterOptionalNickname:
    """测试注册时昵称可选。"""

    def test_register_allows_empty_nickname(self, monkeypatch: pytest.MonkeyPatch):
        """昵称留空时，后端会自动生成默认昵称。"""
        import _globals
        from handlers import _auth_handler
        from services._db_service import default_db

        email = "2500002@stu.xidian.edu.cn"
        db = default_db()
        handler = FakeJsonHandler()

        monkeypatch.setattr(
            _auth_handler,
            "read_json_body",
            lambda _handler: {
                "email": email,
                "password": "123456",
                "nickname": "",
            },
        )
        monkeypatch.setattr(_auth_handler, "save_db", lambda _db: None)
        monkeypatch.setattr(_globals, "ALLOW_DEBUG_VERIFY_CODE", True)

        _auth_handler.handle_register(handler, db)

        payload = json.loads(handler.wfile.getvalue().decode("utf-8"))
        created_user = next(user for user in db["users"] if user["email"] == email)

        assert handler.status_code == HTTPStatus.OK
        assert payload["data"]["email"] == email
        assert created_user["nickname"] == "西电同学0002"
        assert created_user["alias"] == "西电同学0002"
        assert created_user["studentId"] == "2500002"


class TestPasswordReset:
    """测试密码重置相关功能。"""

    def test_password_reset_code_key(self):
        """测试密码重置验证码键生成。"""
        from server import password_reset_code_key

        key = password_reset_code_key("Test@Stu.Xidian.EDU.CN")
        assert key.startswith("reset::")
        # 应该被规范化为小写
        assert "test@" in key

    def test_parse_bool(self):
        """测试布尔值解析。"""
        from server import parse_bool

        # 有效值
        assert parse_bool("true") is True
        assert parse_bool("True") is True
        assert parse_bool("1") is True
        assert parse_bool("yes") is True
        assert parse_bool(True) is True

        assert parse_bool("false") is False
        assert parse_bool("0") is False
        assert parse_bool("no") is False
        assert parse_bool(False) is False

        # 无效值
        assert parse_bool("invalid") is None
        assert parse_bool(None) is None

    def test_parse_list(self):
        """测试列表解析。"""
        from server import parse_list

        # 字符串转列表
        assert parse_list("a,b,c") == ["a", "b", "c"]
        assert parse_list("a, b, c") == ["a", "b", "c"]

        # 已经是列表
        assert parse_list(["a", "b", "c"]) == ["a", "b", "c"]

        # 空值
        assert parse_list("") == []
        assert parse_list(None) == []


class TestTextValidation:
    """测试文本验证功能。"""

    def test_assess_text_risk_empty(self):
        """测试空文本风险评估。"""
        from server import assess_text_risk

        risk_marked, high_risk, reasons = assess_text_risk({}, "")
        assert risk_marked is False
        assert high_risk is False
        assert reasons == []

    def test_assess_text_risk_sensitive_words(self):
        """测试敏感词检测。"""
        from server import assess_text_risk

        db = {"sensitiveWords": ["广告", "诈骗"]}
        risk_marked, high_risk, reasons = assess_text_risk(db, "这是广告内容")

        assert risk_marked is True
        assert len(reasons) > 0
        assert any("敏感词" in r for r in reasons)

    def test_assess_text_risk_repeat_spam(self):
        """测试重复刷屏检测。"""
        from server import assess_text_risk

        risk_marked, high_risk, reasons = assess_text_risk({}, "aaaaaaaabbbbbbbbccccccccc")
        assert risk_marked is True
        assert any("刷屏" in r for r in reasons)

    def test_assess_text_risk_too_long(self):
        """测试超长文本检测。"""
        from server import assess_text_risk

        long_text = "a" * 5001
        risk_marked, high_risk, reasons = assess_text_risk({}, long_text)

        assert risk_marked is True
        assert any("长度" in r for r in reasons)


class TestTimeUtilities:
    """测试时间工具函数。"""

    def test_now_iso(self):
        """测试 ISO 时间生成。"""
        from server import now_iso

        iso = now_iso()
        assert "T" in iso  # ISO 格式包含 T
        assert "Z" in iso or "+" in iso  # UTC 偏移

    def test_parse_iso_normalizes_offsets_and_legacy_naive_values_to_utc(self):
        from server import parse_iso

        offset_value = parse_iso("2026-07-23T16:00:00+08:00")
        naive_value = parse_iso("2026-07-23T08:00:00")

        assert offset_value == datetime(2026, 7, 23, 8, 0, tzinfo=timezone.utc)
        assert naive_value == datetime(2026, 7, 23, 8, 0, tzinfo=timezone.utc)

    def test_parse_iso(self):
        """测试 ISO 时间解析。"""
        from server import parse_iso

        dt = parse_iso("2024-01-15T10:30:00+00:00")
        assert dt is not None
        assert dt.year == 2024
        assert dt.month == 1
        assert dt.day == 15

        # 无效格式
        assert parse_iso(None) is None
        assert parse_iso("invalid") is None


class TestDatabaseMigration:
    """测试数据库迁移功能。"""

    def test_default_db_structure(self):
        """测试默认数据库结构。"""
        from server import default_db

        db = default_db()

        # 检查必要字段
        assert "users" in db
        assert "posts" in db
        assert "channels" in db
        assert "tags" in db
        assert "sessions" in db
        assert "settings" in db

    def test_default_db_demo_user(self):
        """测试默认演示用户。"""
        from server import default_db, DEMO_USER_EMAIL, DEMO_USER_ID

        db = default_db()

        # 查找演示用户
        demo_user = None
        for user in db.get("users", []):
            if user.get("id") == DEMO_USER_ID:
                demo_user = user
                break

        assert demo_user is not None
        assert demo_user["email"] == DEMO_USER_EMAIL
        assert demo_user["verified"] is True

    def test_default_db_seed_posts(self):
        """测试默认种子帖子。"""
        from server import default_db, SEED_POSTS

        db = default_db()
        posts = db.get("posts", [])

        assert len(posts) == len(SEED_POSTS)

        # 验证帖子结构
        for post in posts:
            assert "id" in post
            assert "title" in post
            assert "content" in post
            assert "channel" in post
            assert "authorId" in post


class TestVersionInfo:
    """测试版本信息功能。"""

    def test_get_version_info(self):
        """测试版本信息获取。"""
        from server import _get_version_info

        info = _get_version_info()

        assert "version" in info
        assert "backendVersion" in info
        assert "gitHash" in info
        assert "buildDate" in info
        assert "timestamp" in info

    def test_version_format(self):
        """测试版本号格式。"""
        from server import _get_version_info

        info = _get_version_info()
        assert "XduTreeholeBackend" in info["version"]
        assert info["backendVersion"] == "0.2"
