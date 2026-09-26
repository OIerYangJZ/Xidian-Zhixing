from __future__ import annotations

import base64
import html
import json
import random
import re
import secrets
import string
import threading
import time
from dataclasses import dataclass
from html.parser import HTMLParser
from typing import Any
from urllib.parse import urlsplit

from helpers._auth_helpers import detect_image_type
from helpers._xidian_auth import (
    IDS_HEADERS,
    XidianAuthDependencyError,
    XidianAuthPasswordError,
    XidianAuthUnavailableError,
    _import_requests,
    _requests_timeout,
)


SCHOOLNET_BASE_URL = "https://zfw.xidian.edu.cn"
DORM_WATER_BASE_URL = "https://i.ilife798.com"
_MAX_CAMPUS_TEXT_BYTES = 2 * 1024 * 1024
_MAX_CAMPUS_IMAGE_BYTES = 5 * 1024 * 1024


class CampusAuthError(Exception):
    status_code = 503


class CampusAuthInputError(CampusAuthError):
    status_code = 400


class CampusAuthCredentialError(CampusAuthError):
    # Not 401: that status means "this app's session is dead" to every client,
    # and a wrong campus-system password must not sign the user out.
    status_code = 400


class CampusAuthExpiredError(CampusAuthError):
    status_code = 410


@dataclass(slots=True)
class _SchoolnetAttempt:
    session: Any
    csrf_name: str
    csrf_value: str
    public_key: str
    expires_at: float


@dataclass(slots=True)
class _DormWaterAttempt:
    owner_user_id: str
    expires_at: float
    phone: str = ""


_DORM_WATER_LOCK = threading.Lock()
_DORM_WATER_ATTEMPTS: dict[str, _DormWaterAttempt] = {}


class _InputCollector(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.inputs: list[dict[str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "input":
            return
        attr_map = {key: value or "" for key, value in attrs}
        if attr_map:
            self.inputs.append(attr_map)


_SCHOOLNET_LOCK = threading.Lock()
_SCHOOLNET_ATTEMPTS: dict[str, _SchoolnetAttempt] = {}
_ATTEMPT_TTL_SECONDS = 8 * 60
def _cleanup_schoolnet_attempts_locked() -> None:
    now_ts = time.time()
    for attempt_id in [
        key for key, attempt in _SCHOOLNET_ATTEMPTS.items()
        if attempt.expires_at <= now_ts
    ]:
        _SCHOOLNET_ATTEMPTS.pop(attempt_id, None)


def _strip_html(value: str) -> str:
    text = re.sub(r"<[^>]+>", " ", value or "", flags=re.S)
    return " ".join(html.unescape(text).split())


def _decode_response_text(response: Any, encoding: str = "utf-8") -> str:
    return _read_response_bytes(response, _MAX_CAMPUS_TEXT_BYTES).decode(
        encoding,
        errors="replace",
    )


def _read_response_bytes(response: Any, max_bytes: int) -> bytes:
    try:
        declared = str(response.headers.get("Content-Length", "") or "").strip()
        if declared:
            try:
                if int(declared) > max_bytes:
                    raise CampusAuthError("目标系统响应超过大小限制")
            except ValueError as exc:
                raise CampusAuthError("目标系统返回了无效的内容长度") from exc
        chunks: list[bytes] = []
        total = 0
        for chunk in response.iter_content(chunk_size=64 * 1024):
            if not chunk:
                continue
            total += len(chunk)
            if total > max_bytes:
                raise CampusAuthError("目标系统响应超过大小限制")
            chunks.append(bytes(chunk))
        return b"".join(chunks)
    finally:
        close = getattr(response, "close", None)
        if callable(close):
            close()


def _collect_inputs(page_html: str) -> list[dict[str, str]]:
    parser = _InputCollector()
    parser.feed(page_html or "")
    return parser.inputs


def _require_identifier(value: str) -> str:
    student_id = str(value or "").strip()
    if "@" in student_id:
        student_id = student_id.split("@", 1)[0].strip()
    if not re.fullmatch(r"[A-Za-z0-9]{6,20}", student_id):
        raise CampusAuthInputError("请输入有效学号")
    return student_id


def _require_password(value: str, label: str = "密码") -> str:
    password = str(value or "").strip()
    if not password:
        raise CampusAuthInputError(f"{label}不能为空")
    return password


def _require_phone(value: str) -> str:
    phone = re.sub(r"\s+", "", str(value or ""))
    if not re.fullmatch(r"1\d{10}", phone):
        raise CampusAuthInputError("请输入有效手机号")
    return phone


def normalize_dorm_water_phone(value: str) -> str:
    """Return the one canonical phone value used by validation and throttling."""
    return _require_phone(value)


def _json_response(response: Any) -> dict[str, Any]:
    try:
        data = json.loads(
            _read_response_bytes(response, _MAX_CAMPUS_TEXT_BYTES).decode("utf-8"),
        )
    except (UnicodeDecodeError, ValueError) as exc:
        raise CampusAuthError("目标系统响应不是有效 JSON") from exc
    if not isinstance(data, dict):
        raise CampusAuthError("目标系统响应格式异常")
    return data


def _load_public_key(public_key: str) -> Any:
    try:
        from cryptography.hazmat.backends import default_backend
        from cryptography.hazmat.primitives import serialization
    except ImportError as exc:
        raise XidianAuthDependencyError("后端缺少 cryptography 依赖，无法完成目标系统登录") from exc

    key_text = public_key.strip()
    if "BEGIN PUBLIC KEY" not in key_text:
        compact = "".join(key_text.split())
        key_text = "-----BEGIN PUBLIC KEY-----\n"
        key_text += "\n".join(compact[i:i + 64] for i in range(0, len(compact), 64))
        key_text += "\n-----END PUBLIC KEY-----"
    try:
        return serialization.load_pem_public_key(
            key_text.encode("utf-8"),
            backend=default_backend(),
        )
    except ValueError as exc:
        raise CampusAuthError("目标系统登录页公钥格式异常") from exc


def _rsa_encrypt_base64(value: str, public_key: str) -> str:
    try:
        from cryptography.hazmat.primitives.asymmetric import padding
    except ImportError as exc:
        raise XidianAuthDependencyError("后端缺少 cryptography 依赖，无法完成目标系统登录") from exc
    encrypted = _load_public_key(public_key).encrypt(value.encode("utf-8"), padding.PKCS1v15())
    return base64.b64encode(encrypted).decode("ascii")


def create_schoolnet_captcha(identifier: str = "") -> dict[str, Any]:
    if identifier:
        _require_identifier(identifier)
    requests = _import_requests()
    session = requests.Session()
    session.headers.update({
        "User-Agent": IDS_HEADERS["User-Agent"],
        "Host": "zfw.xidian.edu.cn",
    })
    try:
        response = session.get(
            f"{SCHOOLNET_BASE_URL}/login",
            timeout=_requests_timeout(),
            stream=True,
        )
        response.raise_for_status()
    except requests.RequestException as exc:
        raise CampusAuthError("无法连接校园网自服务") from exc
    inputs = _collect_inputs(_decode_response_text(response))
    csrf_name = ""
    csrf_value = ""
    public_key = ""
    for item in inputs:
        name = item.get("name", "")
        if "csrf" in name.lower() and item.get("value"):
            csrf_name = name
            csrf_value = item.get("value", "")
        if "public" in item.get("id", "").lower() and item.get("value"):
            public_key = item.get("value", "")
    if not csrf_name or not csrf_value or not public_key:
        raise CampusAuthError("校园网登录页格式已变化")
    try:
        session.get(
            f"{SCHOOLNET_BASE_URL}/site/captcha",
            params={"refresh": 1, "_": str(int(time.time() * 1000))},
            timeout=_requests_timeout(),
            stream=True,
        )
        image_response = session.get(
            f"{SCHOOLNET_BASE_URL}/site/captcha",
            timeout=_requests_timeout(),
            stream=True,
        )
        image_response.raise_for_status()
    except requests.RequestException as exc:
        raise CampusAuthError("校园网验证码获取失败") from exc

    attempt_id = secrets.token_urlsafe(18)
    with _SCHOOLNET_LOCK:
        _cleanup_schoolnet_attempts_locked()
        _SCHOOLNET_ATTEMPTS[attempt_id] = _SchoolnetAttempt(
            session=session,
            csrf_name=csrf_name,
            csrf_value=csrf_value,
            public_key=public_key,
            expires_at=time.time() + _ATTEMPT_TTL_SECONDS,
        )
    image_bytes = _read_response_bytes(image_response, _MAX_CAMPUS_IMAGE_BYTES)
    if detect_image_type(image_bytes) is None:
        raise CampusAuthError("校园网验证码响应不是有效图片")
    return {
        "attemptId": attempt_id,
        "imageBase64": base64.b64encode(image_bytes).decode("ascii"),
        "imageContentType": image_response.headers.get("Content-Type", "image/png").split(";", 1)[0],
        "expiresInSeconds": _ATTEMPT_TTL_SECONDS,
    }


def _load_schoolnet_attempt(attempt_id: str) -> _SchoolnetAttempt:
    with _SCHOOLNET_LOCK:
        _cleanup_schoolnet_attempts_locked()
        attempt = _SCHOOLNET_ATTEMPTS.get(str(attempt_id or "").strip())
    if attempt is None:
        raise CampusAuthExpiredError("校园网验证码已过期，请重新获取")
    return attempt


def _parse_schoolnet_usage(page: str) -> dict[str, Any]:
    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", page or "", flags=re.S | re.I)
    ip_list: list[dict[str, str]] = []
    summary = {"used": "", "rest": "", "charged": ""}
    for row in rows:
        cells = [_strip_html(cell) for cell in re.findall(r"<td[^>]*>(.*?)</td>", row, flags=re.S | re.I)]
        if len(cells) == 7 and cells[2]:
            ip_list.append({"ip": cells[1], "location": cells[3], "used": cells[2]})
        if len(cells) == 4:
            name = cells[0]
            if not any(operator in name for operator in ("联通", "移动", "电信")):
                summary = {"used": cells[1], "rest": cells[2], "charged": cells[3]}
    return {"summary": summary, "onlineDevices": ip_list}


def login_schoolnet(attempt_id: str, identifier: str, password: str, captcha: str) -> dict[str, Any]:
    student_id = _require_identifier(identifier)
    password = _require_password(password, "校园网查询密码")
    captcha = str(captcha or "").strip()
    if not captcha:
        raise CampusAuthInputError("请输入校园网验证码")
    requests = _import_requests()
    attempt = _load_schoolnet_attempt(attempt_id)
    encrypted_password = _rsa_encrypt_base64(password, attempt.public_key)
    headers = {
        "X-CSRF-Token": attempt.csrf_value,
        "Accept": "*/*",
        "X-Requested-With": "XMLHttpRequest",
        "User-Agent": IDS_HEADERS["User-Agent"],
    }
    validate_payload = {
        "LoginForm[username]": student_id,
        "LoginForm[password]": encrypted_password,
        "LoginForm[verifyCode]": captcha,
    }
    try:
        response = attempt.session.post(
            f"{SCHOOLNET_BASE_URL}/site/validate-user",
            data=validate_payload,
            headers=headers,
            timeout=_requests_timeout(),
            stream=True,
        )
    except requests.RequestException as exc:
        raise CampusAuthError("校园网登录预校验失败") from exc
    try:
        response.raise_for_status()
    except requests.RequestException as exc:
        raise CampusAuthError("校园网登录预校验失败") from exc
    data = _json_response(response)
    if not data.get("success"):
        message = str(data.get("message") or "校园网账号、密码或验证码错误")
        if any(keyword in message for keyword in ("用户名", "账号", "密码")):
            raise CampusAuthCredentialError(message)
        raise CampusAuthInputError(message)
    login_payload = {
        attempt.csrf_name: attempt.csrf_value,
        "LoginForm[username]": student_id,
        "LoginForm[password]": encrypted_password,
        "LoginForm[smsCode]": "",
        "LoginForm[verifyCode]": captcha,
    }
    try:
        login_response = attempt.session.post(
            f"{SCHOOLNET_BASE_URL}/",
            data=login_payload,
            headers=headers,
            timeout=_requests_timeout(),
            stream=True,
        )
        login_response.raise_for_status()
        home_response = attempt.session.get(
            f"{SCHOOLNET_BASE_URL}/home",
            timeout=_requests_timeout(),
            stream=True,
        )
        home_response.raise_for_status()
    except requests.RequestException as exc:
        raise CampusAuthError("校园网登录后查询失败") from exc
    home_url = str(getattr(home_response, "url", "") or "").lower()
    home_page = _decode_response_text(home_response)
    if (
        "/login" in home_url
        or re.search(
            r"""<input[^>]+name=["']LoginForm\[username\]["']""",
            home_page,
            flags=re.I,
        )
    ):
        raise CampusAuthCredentialError("校园网账号、密码或验证码错误")
    home_parts = urlsplit(home_url)
    expected_home_parts = urlsplit(f"{SCHOOLNET_BASE_URL}/home")
    if (
        home_parts.netloc.lower() != expected_home_parts.netloc.lower()
        or home_parts.path.rstrip("/").lower()
        != expected_home_parts.path.rstrip("/").lower()
    ):
        raise CampusAuthError("校园网登录后页面地址异常")
    usage = _parse_schoolnet_usage(home_page)
    usage_summary = usage.get("summary") if isinstance(usage.get("summary"), dict) else {}
    has_usage_data = any(str(value or "").strip() for value in usage_summary.values()) or bool(
        usage.get("onlineDevices")
    )
    authenticated_markers = (
        r'href=["\'][^"\']*(?:site/)?logout[^"\']*["\']',
        r"(?:退出登录|注销登录|在线设备|已用流量|剩余流量|套餐余额)",
    )
    if not has_usage_data and not any(
        re.search(pattern, home_page, flags=re.I)
        for pattern in authenticated_markers
    ):
        raise CampusAuthError("校园网未返回可验证的登录后页面")
    with _SCHOOLNET_LOCK:
        _SCHOOLNET_ATTEMPTS.pop(attempt_id, None)
    return {
        "system": "schoolnet",
        "status": "authenticated",
        "studentId": student_id,
        "usage": usage,
        "message": "校园网自服务登录通过",
    }


def _random_digits(length: int) -> str:
    return "".join(random.choice(string.digits) for _ in range(length))


def _load_dorm_water_attempt(session_id: str, owner_user_id: str) -> _DormWaterAttempt:
    normalized_session_id = str(session_id or "").strip()
    normalized_owner = str(owner_user_id or "").strip()
    with _DORM_WATER_LOCK:
        now_ts = time.time()
        for key in [
            key for key, row in _DORM_WATER_ATTEMPTS.items()
            if row.expires_at <= now_ts
        ]:
            _DORM_WATER_ATTEMPTS.pop(key, None)
        attempt = _DORM_WATER_ATTEMPTS.get(normalized_session_id)
        if attempt is None or attempt.owner_user_id != normalized_owner:
            raise CampusAuthExpiredError("宿舍水机验证码已过期，请重新获取")
        return attempt


def create_dorm_water_captcha(owner_user_id: str) -> dict[str, Any]:
    normalized_owner = str(owner_user_id or "").strip()
    if not normalized_owner:
        raise CampusAuthInputError("请先登录")
    requests = _import_requests()
    session_id = _random_digits(16)
    try:
        response = requests.get(
            f"{DORM_WATER_BASE_URL}/api/v1/captcha/",
            params={"s": session_id, "r": str(int(time.time() * 1000))},
            headers={
                "accept": "*/*",
                "User-Agent": "iLife798/3.1.1 (iPhone; iOS 26.2; Scale/3.00)",
                "accept-language": "zh-Hans-US;q=1, en-US;q=0.8",
            },
            timeout=_requests_timeout(),
            stream=True,
        )
        response.raise_for_status()
    except requests.RequestException as exc:
        raise CampusAuthError("宿舍水机验证码获取失败") from exc
    image_bytes = _read_response_bytes(response, _MAX_CAMPUS_IMAGE_BYTES)
    if detect_image_type(image_bytes) is None:
        raise CampusAuthError("宿舍水机验证码响应不是有效图片")
    with _DORM_WATER_LOCK:
        _DORM_WATER_ATTEMPTS[session_id] = _DormWaterAttempt(
            owner_user_id=normalized_owner,
            expires_at=time.time() + 5 * 60,
        )
    return {
        "sessionId": session_id,
        "imageBase64": base64.b64encode(image_bytes).decode("ascii"),
        "imageContentType": response.headers.get("Content-Type", "image/png").split(";", 1)[0],
    }


def send_dorm_water_sms(
    session_id: str,
    phone: str,
    image_code: str,
    *,
    owner_user_id: str,
) -> dict[str, Any]:
    phone = _require_phone(phone)
    session_id = str(session_id or "").strip()
    image_code = str(image_code or "").strip()
    if not session_id or not image_code:
        raise CampusAuthInputError("请先填写图形验证码")
    attempt = _load_dorm_water_attempt(session_id, owner_user_id)
    if attempt.phone and attempt.phone != phone:
        raise CampusAuthInputError("验证码会话与手机号不匹配")
    requests = _import_requests()
    try:
        response = requests.post(
            f"{DORM_WATER_BASE_URL}/api/v1/acc/login/code",
            json={"s": session_id, "authCode": image_code, "un": phone},
            headers={
                "accept": "*/*",
                "content-type": "application/json",
                "User-Agent": "iOS_ilife798_3.1.1",
            },
            timeout=_requests_timeout(),
            stream=True,
        )
    except requests.RequestException as exc:
        raise CampusAuthError("宿舍水机短信发送失败") from exc
    try:
        response.raise_for_status()
    except requests.RequestException as exc:
        raise CampusAuthError("宿舍水机短信发送失败") from exc
    data = _json_response(response)
    if data.get("code") != 0:
        raise CampusAuthInputError("宿舍水机短信发送失败，请检查图形验证码")
    with _DORM_WATER_LOCK:
        current = _DORM_WATER_ATTEMPTS.get(session_id)
        if current is not None:
            current.phone = phone
    return {"system": "dormWater", "status": "smsSent", "phone": phone, "message": "短信验证码已发送"}


def login_dorm_water(
    session_id: str,
    phone: str,
    sms_code: str,
    *,
    owner_user_id: str,
) -> dict[str, Any]:
    phone = _require_phone(phone)
    attempt = _load_dorm_water_attempt(session_id, owner_user_id)
    if not attempt.phone or attempt.phone != phone:
        raise CampusAuthInputError("请先为当前手机号发送短信验证码")
    sms_code = str(sms_code or "").strip()
    if not sms_code:
        raise CampusAuthInputError("请输入短信验证码")
    requests = _import_requests()
    try:
        response = requests.post(
            f"{DORM_WATER_BASE_URL}/api/v1/acc/login",
            json={"cid": "", "authCode": sms_code, "un": phone},
            headers={
                "accept": "*/*",
                "content-type": "application/json",
                "User-Agent": "iOS_ilife798_3.1.1",
            },
            timeout=_requests_timeout(),
            stream=True,
        )
    except requests.RequestException as exc:
        raise CampusAuthError("宿舍水机登录失败") from exc
    try:
        response.raise_for_status()
    except requests.RequestException as exc:
        raise CampusAuthError("宿舍水机登录失败") from exc
    data = _json_response(response)
    if data.get("code") != 0:
        raise CampusAuthCredentialError("宿舍水机登录失败，请检查验证码")
    payload = data.get("data") if isinstance(data.get("data"), dict) else {}
    account = payload.get("al") if isinstance(payload.get("al"), dict) else {}
    if not str(account.get("token", "")).strip():
        raise CampusAuthCredentialError("宿舍水机未返回有效登录凭证")
    with _DORM_WATER_LOCK:
        _DORM_WATER_ATTEMPTS.pop(str(session_id or "").strip(), None)
    return {
        "system": "dormWater",
        "status": "authenticated",
        "phone": phone,
        "uid": str(account.get("uid", "")),
        "eid": str(account.get("eid", "")),
        "hasToken": bool(account.get("token")),
        "message": "宿舍水机登录通过",
    }


def map_campus_auth_error(error: Exception) -> tuple[int, str]:
    if isinstance(error, CampusAuthError):
        return error.status_code, str(error)
    if isinstance(error, XidianAuthPasswordError):
        return 400, str(error)
    if isinstance(error, (XidianAuthUnavailableError, XidianAuthDependencyError)):
        return 503, str(error)
    return 503, str(error) or "校园服务认证失败"
