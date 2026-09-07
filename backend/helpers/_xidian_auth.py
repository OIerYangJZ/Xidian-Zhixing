from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass


IDS_LOGIN_URL = "https://ids.xidian.edu.cn/authserver/login"
IDS_SERVICE_VALIDATE_URLS = (
    "https://ids.xidian.edu.cn/authserver/p3/serviceValidate",
    "https://ids.xidian.edu.cn/authserver/serviceValidate",
)
IDS_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/130.0.0.0 Safari/537.36"
    ),
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;q=0.9,"
        "image/avif,image/webp,image/apng,*/*;q=0.8"
    ),
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
}


class XidianAuthError(Exception):
    pass


class XidianAuthPasswordError(XidianAuthError):
    pass


class XidianAuthUnavailableError(XidianAuthError):
    pass


class XidianAuthDependencyError(XidianAuthError):
    pass


@dataclass(slots=True)
class XidianAuthResult:
    student_id: str
    campus_email: str


def _import_requests():
    try:
        import requests
    except ImportError as exc:
        raise XidianAuthDependencyError("后端缺少 requests 依赖，无法使用统一认证登录") from exc
    return requests


def _requests_timeout() -> tuple[int, int]:
    return (10, 30)


def _build_campus_email(student_id: str, *, email_hint: str = "") -> str:
    hint = email_hint.strip().lower()
    if hint.endswith("@stu.xidian.edu.cn"):
        return hint
    return f"{student_id}@stu.xidian.edu.cn"


def _xml_local_name(tag: str) -> str:
    if "}" in tag:
        return tag.rsplit("}", 1)[-1]
    return tag


_XML_DOCTYPE_RE = re.compile(r"<!DOCTYPE", re.I)
_MAX_TICKET_RESPONSE_CHARS = 256 * 1024


def _parse_service_validate_result(xml_text: str) -> XidianAuthResult:
    # ElementTree does not resolve external entities (no XXE), but it does
    # expand internally declared ones, so a "billion laughs" document would
    # exhaust memory.  A CAS response has no legitimate reason to carry a DTD.
    if len(xml_text) > _MAX_TICKET_RESPONSE_CHARS or _XML_DOCTYPE_RE.search(xml_text):
        raise XidianAuthUnavailableError("统一认证票据校验响应异常")
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as exc:
        raise XidianAuthUnavailableError("统一认证票据校验响应异常") from exc

    auth_success = None
    auth_failure = None
    for child in root.iter():
        local_name = _xml_local_name(child.tag)
        if local_name == "authenticationSuccess":
            auth_success = child
            break
        if local_name == "authenticationFailure":
            auth_failure = child

    if auth_success is None:
        message = ""
        if auth_failure is not None:
            message = " ".join((auth_failure.text or "").split())
        raise XidianAuthPasswordError(message or "统一认证票据无效或已过期")

    student_id = ""
    campus_email = ""
    for child in auth_success.iter():
        local_name = _xml_local_name(child.tag)
        value = " ".join((child.text or "").split())
        if not value:
            continue
        if local_name == "user" and not student_id:
            student_id = value
        elif local_name in {"studentId", "uid", "username"} and not student_id:
            student_id = value
        elif local_name in {"mail", "email", "campusEmail"} and not campus_email:
            campus_email = value

    if not student_id:
        raise XidianAuthUnavailableError("统一认证票据校验成功，但未返回学号")
    if not campus_email:
        campus_email = _build_campus_email(student_id)

    return XidianAuthResult(student_id=student_id, campus_email=campus_email)


def validate_xidian_service_ticket(ticket: str, service_url: str) -> XidianAuthResult:
    requests = _import_requests()
    last_error: Exception | None = None

    for endpoint in IDS_SERVICE_VALIDATE_URLS:
        try:
            response = requests.get(
                endpoint,
                params={"service": service_url, "ticket": ticket},
                headers=IDS_HEADERS,
                timeout=_requests_timeout(),
            )
            response.raise_for_status()
            return _parse_service_validate_result(response.text)
        except XidianAuthPasswordError:
            raise
        except (requests.RequestException, XidianAuthUnavailableError) as exc:
            last_error = exc

    raise XidianAuthUnavailableError("统一认证票据校验失败，请稍后重试") from last_error
