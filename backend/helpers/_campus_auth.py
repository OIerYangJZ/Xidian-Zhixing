from __future__ import annotations

import base64
import hashlib
import html
import random
import re
import secrets
import string
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timedelta
from html.parser import HTMLParser
from typing import Any
from urllib.parse import parse_qs, urljoin, urlsplit

from helpers._xidian_auth import (
    IDS_HEADERS,
    IDS_LOGIN_URL,
    XidianAuthCaptchaError,
    XidianAuthDependencyError,
    XidianAuthPasswordError,
    XidianAuthUnavailableError,
    _build_login_payload,
    _extract_inputs,
    _extract_login_error_message,
    _import_requests,
    _parse_password_error_message,
    _requests_timeout,
    _solve_slider_captcha,
    login_via_xidian_ids,
)


PAYMENT_SERVICE_URL = (
    "https://xxcapp.xidian.edu.cn/uc/api/oauth/index?"
    "redirect=https://ignypt.xidian.edu.cn/revenueH5/login?"
    "opcode=MPAY&appid=200260318155520600&state=12312312312312&qrcode=0"
)
EHALL_HOME_SERVICE_URL = "https://ehall.xidian.edu.cn/login?service=https://ehall.xidian.edu.cn/new/index.html"
EHALL_REFERER_URL = "http://ehall.xidian.edu.cn/new/index_xd.html"
EHALL_APP_IDS = {
    "classtable": "4770397878132218",
    "exam": "4768687067472349",
}
PHYSICS_LOGIN_URL = "http://wlsy.xidian.edu.cn/PhyEws/default.aspx"
PHYSICS_SELECT_URL = "http://wlsy.xidian.edu.cn/PhyEws/student/select.aspx"
SPORT_BASE_URL = "http://tybjxgl.xidian.edu.cn/app"
SCHOOLNET_BASE_URL = "https://zfw.xidian.edu.cn"
DORM_WATER_BASE_URL = "https://i.ilife798.com"


class CampusAuthError(Exception):
    status_code = 503


class CampusAuthInputError(CampusAuthError):
    status_code = 400


class CampusAuthCredentialError(CampusAuthError):
    status_code = 401


class CampusAuthExpiredError(CampusAuthError):
    status_code = 410


@dataclass(slots=True)
class _SchoolnetAttempt:
    session: Any
    csrf_name: str
    csrf_value: str
    public_key: str
    expires_at: float


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
CLASS_SECTION_TIMES = {
    1: ("08:30", "09:15"),
    2: ("09:20", "10:05"),
    3: ("10:25", "11:10"),
    4: ("11:15", "12:00"),
    5: ("14:00", "14:45"),
    6: ("14:50", "15:35"),
    7: ("15:55", "16:40"),
    8: ("16:45", "17:30"),
    9: ("19:00", "19:45"),
    10: ("19:50", "20:35"),
    11: ("20:40", "21:25"),
}
EXAM_TIME_RE = re.compile(
    r"(?P<date>\d{4}-\d{2}-\d{2}).*?(?P<start>\d{2}):(?P<start_min>\d{2})-(?P<end>\d{2}):(?P<end_min>\d{2})"
)


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
    response.encoding = encoding
    return response.text


def _collect_inputs(page_html: str) -> list[dict[str, str]]:
    parser = _InputCollector()
    parser.feed(page_html or "")
    return parser.inputs


def _input_value(inputs: list[dict[str, str]], name: str) -> str:
    for item in inputs:
        if item.get("name") == name or item.get("id") == name:
            return item.get("value", "")
    return ""


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


def _json_response(response: Any) -> dict[str, Any]:
    try:
        data = response.json()
    except ValueError as exc:
        raise CampusAuthError("目标系统响应不是有效 JSON") from exc
    if not isinstance(data, dict):
        raise CampusAuthError("目标系统响应格式异常")
    return data


def _ehall_headers() -> dict[str, str]:
    return {
        "User-Agent": IDS_HEADERS["User-Agent"],
        "Referer": EHALL_REFERER_URL,
        "Host": "ehall.xidian.edu.cn",
        "Accept": "application/json, text/javascript, */*; q=0.01",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        "X-Requested-With": "XMLHttpRequest",
    }


def _host_from_url(url: str) -> str:
    return urlsplit(url).netloc or url


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


def _login_ids_for_service(student_id: str, password: str, target_url: str) -> tuple[Any, str]:
    requests = _import_requests()
    session = requests.Session()
    session.headers.update(IDS_HEADERS)

    try:
        response = session.get(
            IDS_LOGIN_URL,
            params={"service": target_url},
            allow_redirects=False,
            timeout=_requests_timeout(),
        )
    except requests.RequestException as exc:
        raise XidianAuthUnavailableError("无法连接西电统一认证，请稍后重试") from exc

    if response.status_code == 401:
        raise XidianAuthPasswordError(_parse_password_error_message(response.text))
    if response.status_code in (301, 302):
        return session, response.headers.get("Location", "")
    if response.status_code != 200:
        raise XidianAuthUnavailableError(f"统一认证服务异常（状态码 {response.status_code}）")

    payload = _build_login_payload(student_id, password, _extract_inputs(response.text))
    _solve_slider_captcha(session)

    try:
        response = session.post(
            IDS_LOGIN_URL,
            data=payload,
            params={"service": target_url},
            allow_redirects=False,
            timeout=_requests_timeout(),
        )
    except requests.RequestException as exc:
        raise XidianAuthUnavailableError("统一认证登录请求失败，请稍后重试") from exc

    if response.status_code in (301, 302):
        return session, response.headers.get("Location", "")
    if response.status_code == 401:
        raise XidianAuthPasswordError(_parse_password_error_message(response.text))
    error_message = _extract_login_error_message(response.text)
    if error_message:
        raise XidianAuthPasswordError(_parse_password_error_message(response.text))

    continue_inputs = _extract_inputs(response.text, form_id="continue")
    if continue_inputs:
        try:
            response = session.post(
                IDS_LOGIN_URL,
                data=continue_inputs,
                allow_redirects=False,
                timeout=_requests_timeout(),
            )
        except requests.RequestException as exc:
            raise XidianAuthUnavailableError("统一认证登录续跳失败，请稍后重试") from exc
        if response.status_code in (301, 302):
            return session, response.headers.get("Location", "")
        if response.status_code == 401:
            raise XidianAuthPasswordError(_parse_password_error_message(response.text))
        error_message = _extract_login_error_message(response.text)
        if error_message:
            raise XidianAuthPasswordError(_parse_password_error_message(response.text))

    raise XidianAuthUnavailableError("统一认证登录失败：未返回目标系统跳转")


def _follow_redirects(session: Any, location: str, *, max_steps: int = 8) -> str:
    requests = _import_requests()
    current = location
    for _ in range(max_steps):
        if not current:
            break
        try:
            response = session.get(
                current,
                allow_redirects=False,
                timeout=_requests_timeout(),
            )
        except requests.RequestException as exc:
            raise CampusAuthError("目标系统跳转失败，请稍后重试") from exc
        next_location = response.headers.get("Location", "")
        if not next_location:
            return response.url or current
        current = urljoin(response.url or current, next_location)
    return current


def _ensure_ehall_session(session: Any, location: str = "") -> None:
    if location:
        _follow_redirects(session, location)
    requests = _import_requests()
    try:
        response = session.get(
            "https://ehall.xidian.edu.cn/jsonp/getAppUsageMonitor.json",
            params={"type": "uv"},
            headers=_ehall_headers(),
            timeout=_requests_timeout(),
        )
    except requests.RequestException as exc:
        raise CampusAuthError("一站式登录状态检查失败") from exc
    try:
        data = response.json()
    except ValueError:
        data = {}
    if isinstance(data, dict) and data.get("hasLogin") is True:
        return
    raise CampusAuthError("统一认证已通过，但一站式登录状态未生效")


def _use_ehall_app(session: Any, app_id: str) -> str:
    requests = _import_requests()
    try:
        response = session.get(
            "https://ehall.xidian.edu.cn/appShow",
            params={"appId": app_id},
            headers=_ehall_headers(),
            allow_redirects=False,
            timeout=_requests_timeout(),
        )
    except requests.RequestException as exc:
        raise CampusAuthError("一站式应用跳转失败") from exc
    location = response.headers.get("Location", "")
    if not location:
        raise CampusAuthError("一站式应用未返回跳转地址")
    return re.sub(r";jsessionid=.*?\?", "?", urljoin(response.url, location))


def _open_ehall_app(session: Any, app_id: str, *, method: str = "get") -> None:
    requests = _import_requests()
    location = _use_ehall_app(session, app_id)
    try:
        if method == "post":
            response = session.post(
                location,
                headers=_ehall_headers(),
                allow_redirects=False,
                timeout=_requests_timeout(),
            )
        else:
            response = session.get(
                location,
                headers=_ehall_headers(),
                allow_redirects=False,
                timeout=_requests_timeout(),
            )
    except requests.RequestException as exc:
        raise CampusAuthError("一站式应用初始化失败") from exc
    next_location = response.headers.get("Location", "")
    if next_location:
        _follow_redirects(session, urljoin(response.url or location, next_location))


def _post_ehall_json(session: Any, url: str, data: dict[str, Any] | None = None) -> dict[str, Any]:
    requests = _import_requests()
    try:
        response = session.post(
            url,
            data=data or {},
            headers=_ehall_headers(),
            timeout=_requests_timeout(),
        )
        response.raise_for_status()
    except requests.RequestException as exc:
        raise CampusAuthError("一站式数据接口请求失败") from exc
    return _json_response(response)


def _current_semester_code(session: Any) -> str:
    _open_ehall_app(session, EHALL_APP_IDS["classtable"], method="post")
    data = _post_ehall_json(
        session,
        "https://ehall.xidian.edu.cn/jwapp/sys/wdkb/modules/jshkcb/dqxnxq.do",
    )
    rows = (((data.get("datas") or {}).get("dqxnxq") or {}).get("rows") or [])
    if not rows:
        raise CampusAuthError("一站式未返回当前学期")
    return str(rows[0].get("DM", "")).strip()


def _section_time_range(start: Any, stop: Any) -> tuple[str, str]:
    try:
        start_no = int(start)
        stop_no = int(stop)
    except (TypeError, ValueError):
        return "", ""
    start_time = CLASS_SECTION_TIMES.get(start_no, ("", ""))[0]
    end_time = CLASS_SECTION_TIMES.get(stop_no, ("", ""))[1]
    return start_time, end_time


def _date_for_weekday(term_start: str, week_index: int, weekday: int) -> str:
    base = datetime.fromisoformat(str(term_start).split(" ", 1)[0]).date()
    return (base + timedelta(days=(week_index * 7) + max(0, weekday - 1))).isoformat()


def _sync_course_schedules(session: Any, *, student_id: str, owner_user_id: str, semester_code: str) -> list[dict[str, Any]]:
    _open_ehall_app(session, EHALL_APP_IDS["classtable"], method="post")
    year_parts = semester_code.split("-")
    term_start_data = _post_ehall_json(
        session,
        "https://ehall.xidian.edu.cn/jwapp/sys/wdkb/modules/jshkcb/cxjcs.do",
        {
            "XN": f"{year_parts[0]}-{year_parts[1]}" if len(year_parts) >= 2 else semester_code,
            "XQ": year_parts[2] if len(year_parts) >= 3 else "",
        },
    )
    term_rows = (((term_start_data.get("datas") or {}).get("cxjcs") or {}).get("rows") or [])
    term_start = str((term_rows[0] if term_rows else {}).get("XQKSRQ", "")).strip()
    if not term_start:
        raise CampusAuthError("一站式未返回学期开始日期")

    data = _post_ehall_json(
        session,
        "https://ehall.xidian.edu.cn/jwapp/sys/wdkb/modules/xskcb/xskcb.do",
        {"XNXQDM": semester_code, "XH": student_id},
    )
    table = ((data.get("datas") or {}).get("xskcb") or {})
    ext = table.get("extParams") if isinstance(table.get("extParams"), dict) else {}
    if ext and int(ext.get("code", 1) or 0) != 1:
        message = str(ext.get("msg") or "课表接口返回异常")
        if "未发布" in message:
            return []
        raise CampusAuthError(message)
    rows = table.get("rows") if isinstance(table.get("rows"), list) else []
    schedules: list[dict[str, Any]] = []
    for row in rows:
        week_bits = str(row.get("SKZC") or "")
        weekday = int(row.get("SKXQ") or 0)
        start_time, end_time = _section_time_range(row.get("KSJC"), row.get("JSJC"))
        if not week_bits or not weekday or not start_time or not end_time:
            continue
        for week_index, enabled in enumerate(week_bits):
            if enabled != "1":
                continue
            schedules.append({
                "id": f"ids-course-{owner_user_id}-{semester_code}-{row.get('KCH', '')}-{row.get('KXH', '')}-{week_index + 1}-{weekday}-{row.get('KSJC', '')}",
                "ownerUserId": owner_user_id,
                "studentId": student_id,
                "semesterCode": semester_code,
                "title": str(row.get("KCM") or ""),
                "date": _date_for_weekday(term_start, week_index, weekday),
                "startTime": start_time,
                "endTime": end_time,
                "location": str(row.get("JASMC") or ""),
                "teacher": str(row.get("SKJS") or ""),
                "section": f"{row.get('KSJC')}-{row.get('JSJC')} 节",
                "kind": "course",
                "sourceProvider": "xidian-ehall",
            })
    return schedules


def _parse_exam_time(value: Any) -> tuple[str, str, str]:
    match = EXAM_TIME_RE.search(str(value or ""))
    if not match:
        return "", "", ""
    return (
        match.group("date"),
        f"{match.group('start')}:{match.group('start_min')}",
        f"{match.group('end')}:{match.group('end_min')}",
    )


def _sync_exam_schedules(session: Any, *, student_id: str, owner_user_id: str, semester_code: str) -> list[dict[str, Any]]:
    _open_ehall_app(session, EHALL_APP_IDS["exam"])
    data = _post_ehall_json(
        session,
        "https://ehall.xidian.edu.cn/jwapp/sys/studentWdksapApp/modules/wdksap/wdksap.do",
        {"XNXQDM": semester_code, "*order": "-KSRQ,-KSSJMS"},
    )
    table = ((data.get("datas") or {}).get("wdksap") or {})
    rows = table.get("rows") if isinstance(table.get("rows"), list) else []
    schedules: list[dict[str, Any]] = []
    for index, row in enumerate(rows):
        date_text, start_time, end_time = _parse_exam_time(row.get("KSSJMS"))
        if not date_text:
            continue
        schedules.append({
            "id": f"ids-exam-{owner_user_id}-{semester_code}-{row.get('KCH', '')}-{index}",
            "ownerUserId": owner_user_id,
            "studentId": student_id,
            "semesterCode": semester_code,
            "title": str(row.get("KCM") or row.get("KCMH") or "考试"),
            "date": date_text,
            "startTime": start_time,
            "endTime": end_time,
            "location": str(row.get("JASMC") or "尚无安排"),
            "teacher": "",
            "section": str(row.get("ZWH") or ""),
            "kind": "exam",
            "examType": str(row.get("KSMC") or ""),
            "sourceProvider": "xidian-ehall",
        })
    return schedules


def sync_ids_academic_data(session: Any, *, student_id: str, owner_user_id: str) -> dict[str, Any]:
    semester_code = _current_semester_code(session)
    courses = _sync_course_schedules(
        session,
        student_id=student_id,
        owner_user_id=owner_user_id,
        semester_code=semester_code,
    )
    exams = _sync_exam_schedules(
        session,
        student_id=student_id,
        owner_user_id=owner_user_id,
        semester_code=semester_code,
    )
    return {
        "semesterCode": semester_code,
        "courseSchedules": courses,
        "examSchedules": exams,
    }


def apply_ids_academic_data(db: dict[str, Any], *, owner_user_id: str, synced: dict[str, Any]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for key in ("courseSchedules", "examSchedules"):
        rows = synced.get(key) if isinstance(synced.get(key), list) else []
        db[key] = [
            row for row in db.get(key, [])
            if str(row.get("ownerUserId", "")) != owner_user_id or str(row.get("sourceProvider", "")) != "xidian-ehall"
        ]
        db[key].extend(rows)
        counts[key] = len(rows)
    return counts


def login_ids(identifier: str, password: str, *, owner_user_id: str = "", db: dict[str, Any] | None = None) -> dict[str, Any]:
    student_id = _require_identifier(identifier)
    password = _require_password(password, "统一认证密码")
    session, location = _login_ids_for_service(student_id, password, EHALL_HOME_SERVICE_URL)
    _ensure_ehall_session(session, location)
    synced = sync_ids_academic_data(session, student_id=student_id, owner_user_id=owner_user_id or student_id)
    sync_counts = {"courseSchedules": 0, "examSchedules": 0}
    if db is not None and owner_user_id:
        sync_counts = apply_ids_academic_data(db, owner_user_id=owner_user_id, synced=synced)
    return {
        "system": "ids",
        "status": "authenticated",
        "studentId": student_id,
        "email": f"{student_id}@stu.xidian.edu.cn",
        "semesterCode": synced.get("semesterCode", ""),
        "synced": {
            "courseCount": sync_counts.get("courseSchedules", 0),
            "examCount": sync_counts.get("examSchedules", 0),
        },
        "message": "统一认证验证通过，已同步课表和考试安排",
    }


def login_payment(identifier: str, password: str) -> dict[str, Any]:
    student_id = _require_identifier(identifier)
    session, location = _login_ids_for_service(
        student_id,
        _require_password(password, "统一认证密码"),
        PAYMENT_SERVICE_URL,
    )
    final_url = _follow_redirects(session, location)
    query = parse_qs(urlsplit(final_url).query)
    return {
        "system": "payment",
        "status": "authenticated",
        "studentId": student_id,
        "targetHost": _host_from_url(final_url),
        "codeReceived": bool(query.get("code")),
        "message": "缴费/水电系统统一认证跳转已通过",
    }


def login_physics(identifier: str, password: str) -> dict[str, Any]:
    student_id = _require_identifier(identifier)
    password = _require_password(password, "物理实验密码")
    requests = _import_requests()
    session = requests.Session()
    session.headers.update({
        "User-Agent": IDS_HEADERS["User-Agent"],
        "Referer": PHYSICS_LOGIN_URL,
        "Origin": "http://wlsy.xidian.edu.cn",
    })

    try:
        response = session.get(PHYSICS_LOGIN_URL, timeout=_requests_timeout())
        response.raise_for_status()
    except requests.RequestException as exc:
        raise CampusAuthError("无法连接物理实验系统") from exc

    inputs = _collect_inputs(_decode_response_text(response, "gb18030"))
    payload = {
        "__EVENTTARGET": "",
        "__EVENTARGUMENT": "",
        "__VIEWSTATE": _input_value(inputs, "__VIEWSTATE"),
        "__VIEWSTATEGENERATOR": _input_value(inputs, "__VIEWSTATEGENERATOR"),
        "__EVENTVALIDATION": _input_value(inputs, "__EVENTVALIDATION"),
        "login1$StuLoginID": student_id,
        "login1$StuPassword": password,
        "login1$UserRole": "Student",
        "login1$btnLogin.x": "28",
        "login1$btnLogin.y": "14",
    }

    try:
        response = session.post(
            PHYSICS_LOGIN_URL,
            data=payload,
            allow_redirects=False,
            timeout=_requests_timeout(),
        )
    except requests.RequestException as exc:
        raise CampusAuthError("物理实验系统登录请求失败") from exc

    if response.status_code not in (301, 302):
        page = _decode_response_text(response, "gb18030")
        message = _strip_html(
            re.search(r'id=["\']login1_Label1["\'][^>]*>(.*?)</[^>]+>', page, flags=re.S | re.I).group(1)
            if re.search(r'id=["\']login1_Label1["\'][^>]*>(.*?)</[^>]+>', page, flags=re.S | re.I)
            else ""
        )
        raise CampusAuthCredentialError(message or "物理实验账号或密码错误")

    try:
        select_response = session.get(PHYSICS_SELECT_URL, timeout=_requests_timeout())
        select_text = _decode_response_text(select_response, "gb18030")
    except requests.RequestException as exc:
        raise CampusAuthError("物理实验系统登录后数据页访问失败") from exc
    experiment_count = len(re.findall(r'id=["\']Orders_ctl\d+["\']', select_text, flags=re.I))
    return {
        "system": "physics",
        "status": "authenticated",
        "studentId": student_id,
        "experimentCount": experiment_count,
        "message": "物理实验系统登录通过",
    }


_SPORT_PUBLIC_KEY = """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAq4laolA7zAk7jzsqDb3Oa5pS/uCPlZfASK8Soh/NzEmry77QDZ2koyr96M5Wx+A9cxwewQMHzi8RoOfb3UcQO4UDQlMUImLuzUnfbk3TTppijSLH+PU88XQxcgYm2JTa546c7JdZSI6dBeXOJH20quuxWyzgLk9jAlt3ytYygPQ7C6o6ZSmjcMgE3xgLaHGvixEVpOjL/pdVLzXhrMqWVAnB/snMjpCqesDVTDe5c6OOmj2q5J8n+tzIXtnvrkxQSDaUp8DWF8meMwyTErmYklMXzKic2rjdYZpHh4x98Fg0Q28sp6i2ZoWiGrJDKW29mntVQQiDNhKDawb4B45zUwIDAQAB
-----END PUBLIC KEY-----"""


def _sport_sign(params: dict[str, Any]) -> str:
    raw = "&".join(f"{key}={params[key]}" for key in sorted(params))
    return hashlib.md5(raw.encode("utf-8")).hexdigest()


def login_sport(identifier: str, password: str) -> dict[str, Any]:
    student_id = _require_identifier(identifier)
    password = _require_password(password, "体育系统密码")
    requests = _import_requests()
    timestamp = str(int(time.time() * 1000))
    payload: dict[str, Any] = {
        "openid": "",
        "pwd": _rsa_encrypt_base64(password, _SPORT_PUBLIC_KEY),
        "timestamp": timestamp,
        "uname": student_id,
    }
    headers = {
        "channel": "H5",
        "version": "99999",
        "type": "0",
        "timestamp": timestamp,
        "sign": _sport_sign(payload),
        "User-Agent": IDS_HEADERS["User-Agent"],
    }
    try:
        response = requests.post(
            f"{SPORT_BASE_URL}/h5/login",
            data=payload,
            headers=headers,
            timeout=_requests_timeout(),
        )
    except requests.RequestException as exc:
        raise CampusAuthError("无法连接体育系统") from exc
    data = _json_response(response)
    return_code = str(data.get("returnCode", ""))
    if return_code != "200":
        message = str(data.get("returnMsg") or data.get("msg") or "体育系统登录失败")
        if any(keyword in message for keyword in ("用户名", "账号", "密码")):
            raise CampusAuthCredentialError(message)
        raise CampusAuthError(message)
    payload_data = data.get("data") if isinstance(data.get("data"), dict) else {}
    return {
        "system": "sport",
        "status": "authenticated",
        "studentId": student_id,
        "userId": str(payload_data.get("id", "")),
        "hasToken": bool(payload_data.get("token")),
        "message": "体育系统登录通过",
    }


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
        response = session.get(f"{SCHOOLNET_BASE_URL}/login", timeout=_requests_timeout())
        response.raise_for_status()
    except requests.RequestException as exc:
        raise CampusAuthError("无法连接校园网自服务") from exc
    inputs = _collect_inputs(response.text)
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
        )
        image_response = session.get(
            f"{SCHOOLNET_BASE_URL}/site/captcha",
            timeout=_requests_timeout(),
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
    return {
        "attemptId": attempt_id,
        "imageBase64": base64.b64encode(image_response.content).decode("ascii"),
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
        )
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
        attempt.session.post(
            f"{SCHOOLNET_BASE_URL}/",
            data=login_payload,
            headers=headers,
            timeout=_requests_timeout(),
        )
        home_response = attempt.session.get(f"{SCHOOLNET_BASE_URL}/home", timeout=_requests_timeout())
    except requests.RequestException as exc:
        raise CampusAuthError("校园网登录后查询失败") from exc
    with _SCHOOLNET_LOCK:
        _SCHOOLNET_ATTEMPTS.pop(attempt_id, None)
    return {
        "system": "schoolnet",
        "status": "authenticated",
        "studentId": student_id,
        "usage": _parse_schoolnet_usage(home_response.text),
        "message": "校园网自服务登录通过",
    }


def _random_digits(length: int) -> str:
    return "".join(random.choice(string.digits) for _ in range(length))


def create_dorm_water_captcha() -> dict[str, Any]:
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
        )
        response.raise_for_status()
    except requests.RequestException as exc:
        raise CampusAuthError("宿舍水机验证码获取失败") from exc
    return {
        "sessionId": session_id,
        "imageBase64": base64.b64encode(response.content).decode("ascii"),
        "imageContentType": response.headers.get("Content-Type", "image/png").split(";", 1)[0],
    }


def send_dorm_water_sms(session_id: str, phone: str, image_code: str) -> dict[str, Any]:
    phone = _require_phone(phone)
    session_id = str(session_id or "").strip()
    image_code = str(image_code or "").strip()
    if not session_id or not image_code:
        raise CampusAuthInputError("请先填写图形验证码")
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
        )
    except requests.RequestException as exc:
        raise CampusAuthError("宿舍水机短信发送失败") from exc
    data = _json_response(response)
    if data.get("code") != 0:
        raise CampusAuthInputError(str(data.get("msg") or "宿舍水机短信发送失败"))
    return {"system": "dormWater", "status": "smsSent", "phone": phone, "message": "短信验证码已发送"}


def login_dorm_water(phone: str, sms_code: str) -> dict[str, Any]:
    phone = _require_phone(phone)
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
        )
    except requests.RequestException as exc:
        raise CampusAuthError("宿舍水机登录失败") from exc
    data = _json_response(response)
    if data.get("code") != 0:
        raise CampusAuthCredentialError(str(data.get("msg") or "宿舍水机登录失败"))
    payload = data.get("data") if isinstance(data.get("data"), dict) else {}
    account = payload.get("al") if isinstance(payload.get("al"), dict) else {}
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
        return 401, str(error)
    if isinstance(error, XidianAuthCaptchaError):
        return 503, str(error)
    if isinstance(error, (XidianAuthUnavailableError, XidianAuthDependencyError)):
        return 503, str(error)
    return 503, str(error) or "校园服务认证失败"
