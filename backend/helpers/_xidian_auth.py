from __future__ import annotations

import base64
import binascii
import html
import io
import json
import random
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from html.parser import HTMLParser
from typing import Any
from urllib.parse import parse_qs, urljoin, urlsplit


IDS_LOGIN_URL = "https://ids.xidian.edu.cn/authserver/login"
IDS_SLIDER_OPEN_URL = "https://ids.xidian.edu.cn/authserver/common/openSliderCaptcha.htl"
IDS_SLIDER_VERIFY_URL = "https://ids.xidian.edu.cn/authserver/common/verifySliderCaptcha.htl"
EHALL_SERVICE_URL = (
    "https://ehall.xidian.edu.cn/login"
    "?service=https://ehall.xidian.edu.cn/new/index.html"
)
IDS_SERVICE_VALIDATE_URLS = (
    "https://ids.xidian.edu.cn/authserver/p3/serviceValidate",
    "https://ids.xidian.edu.cn/authserver/serviceValidate",
)
IDS_AES_IV = b"xidianscriptsxdu"
IDS_AES_PREFIX = (
    "xidianscriptsxdu"
    "xidianscriptsxdu"
    "xidianscriptsxdu"
    "xidianscriptsxdu"
)
IDS_CAPTCHA_CANVAS_WIDTH = 280
IDS_CAPTCHA_AES_CHARS = "ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678"
IDS_CAPTCHA_MOVE_DELTAS = (
    1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 8, -8, 10, -10,
    12, -12, 15, -15, 18, -18, 22, -22, 26, -26, 30, -30, 34, -34, 38, -38, 42, -42,
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


class XidianAuthCaptchaError(XidianAuthError):
    pass


class XidianAuthUnavailableError(XidianAuthError):
    pass


class XidianAuthDependencyError(XidianAuthError):
    pass


@dataclass(slots=True)
class XidianAuthResult:
    student_id: str
    campus_email: str


class _InputParser(HTMLParser):
    def __init__(self, *, target_form_id: str | None = None) -> None:
        super().__init__()
        self._target_form_id = target_form_id
        self._in_target_form = target_form_id is None
        self._form_depth = 0
        self.inputs: dict[str, str] = {}

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = {key: value or "" for key, value in attrs}
        if tag == "form":
            if self._target_form_id is None:
                return
            if attr_map.get("id", "") == self._target_form_id:
                self._in_target_form = True
                self._form_depth = 1
            elif self._in_target_form:
                self._form_depth += 1
            return
        if tag != "input":
            return
        if not self._in_target_form:
            return
        name = attr_map.get("name") or attr_map.get("id")
        if not name:
            return
        self.inputs[name] = attr_map.get("value", "")

    def handle_endtag(self, tag: str) -> None:
        if tag != "form" or self._target_form_id is None or not self._in_target_form:
            return
        if self._form_depth > 0:
            self._form_depth -= 1
        if self._form_depth <= 0:
            self._in_target_form = False


def _import_requests():
    try:
        import requests
    except ImportError as exc:
        raise XidianAuthDependencyError("后端缺少 requests 依赖，无法使用统一认证登录") from exc
    return requests


def _import_pillow_image():
    try:
        from PIL import Image
    except ImportError as exc:
        raise XidianAuthDependencyError("后端缺少 Pillow 依赖，无法使用统一认证登录") from exc
    return Image


def _requests_timeout() -> tuple[int, int]:
    return (10, 30)


def _strip_html(value: str) -> str:
    text = re.sub(r"<[^>]+>", " ", value or "", flags=re.S)
    return " ".join(html.unescape(text).split())


def _parse_password_error_message(page_html: str) -> str:
    match = re.search(
        r'<[^>]*id=["\']showErrorTip["\'][^>]*>(.*?)</[^>]+>',
        page_html or "",
        flags=re.S | re.I,
    )
    if not match:
        return "统一认证登录失败"
    message = _strip_html(match.group(1))
    if re.search(r"(用户名|密码).*误", message, flags=re.I):
        return "学号或统一认证密码错误"
    return message or "统一认证登录失败"


def _extract_login_error_message(page_html: str) -> str:
    match = re.search(
        r'<[^>]*id=["\']showErrorTip["\'][^>]*>(.*?)</[^>]+>',
        page_html or "",
        flags=re.S | re.I,
    )
    if not match:
        return ""
    return _strip_html(match.group(1))


def _extract_inputs(page_html: str, *, form_id: str | None = None) -> dict[str, str]:
    parser = _InputParser(target_form_id=form_id)
    parser.feed(page_html or "")
    return parser.inputs


def _aes_cipher_name(key_bytes: bytes) -> str:
    size = len(key_bytes)
    if size == 16:
        return "aes-128-cbc"
    if size == 24:
        return "aes-192-cbc"
    if size == 32:
        return "aes-256-cbc"
    raise XidianAuthUnavailableError("统一认证加密密钥长度异常")


def _encrypt_ids_password(password: str, key: str) -> str:
    key_bytes = key.encode("utf-8")
    cipher = _aes_cipher_name(key_bytes)
    raw = (IDS_AES_PREFIX + password).encode("utf-8")
    pad_len = 16 - (len(raw) % 16)
    raw += bytes([pad_len]) * pad_len
    try:
        result = subprocess.run(
            [
                "openssl",
                "enc",
                f"-{cipher}",
                "-K",
                key_bytes.hex(),
                "-iv",
                IDS_AES_IV.hex(),
                "-nopad",
                "-e",
                "-A",
                "-base64",
            ],
            input=raw,
            capture_output=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise XidianAuthDependencyError("后端缺少 openssl，无法使用统一认证登录") from exc
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", errors="ignore").strip()
        raise XidianAuthUnavailableError(stderr or "统一认证密码加密失败")
    return result.stdout.decode("utf-8", errors="ignore").strip()


def _load_slider_payload(session: Any) -> dict[str, Any]:
    requests = _import_requests()
    try:
        response = session.get(
            IDS_SLIDER_OPEN_URL,
            params={"_": str(int(time.time() * 1000))},
            allow_redirects=False,
            timeout=_requests_timeout(),
        )
        response.raise_for_status()
    except requests.RequestException as exc:
        raise XidianAuthUnavailableError("统一认证验证码服务不可用，请稍后重试") from exc
    try:
        data = response.json()
    except ValueError as exc:
        raise XidianAuthUnavailableError("统一认证验证码响应异常") from exc
    if not isinstance(data, dict):
        raise XidianAuthUnavailableError("统一认证验证码响应异常")
    return data


def _decode_image(data: str) -> bytes:
    try:
        return base64.b64decode(data, validate=False)
    except (ValueError, binascii.Error) as exc:
        raise XidianAuthUnavailableError("统一认证验证码图片解析失败") from exc


def _verify_slider_answer(session: Any, *, move_length: int, canvas_length: int) -> bool:
    requests = _import_requests()
    try:
        response = session.post(
            IDS_SLIDER_VERIFY_URL,
            data={
                "canvasLength": str(canvas_length),
                "moveLength": str(max(0, move_length)),
            },
            headers={
                "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
            },
            allow_redirects=False,
            timeout=_requests_timeout(),
        )
        response.raise_for_status()
    except requests.RequestException as exc:
        raise XidianAuthUnavailableError("统一认证验证码校验失败，请稍后重试") from exc
    try:
        data = response.json()
    except ValueError:
        return False
    return isinstance(data, dict) and int(data.get("errorCode", 0)) == 1


def _captcha_aes_sign(payload: str, key_bytes: bytes) -> str:
    if len(key_bytes) != 16:
        raise XidianAuthUnavailableError("统一认证验证码密钥长度异常")
    nonce = "".join(random.choice(IDS_CAPTCHA_AES_CHARS) for _ in range(80))
    raw = (nonce[:64] + payload).encode("utf-8")
    pad_len = 16 - (len(raw) % 16)
    raw += bytes([pad_len]) * pad_len
    try:
        result = subprocess.run(
            [
                "openssl",
                "enc",
                "-aes-128-cbc",
                "-K",
                key_bytes.hex(),
                "-iv",
                nonce[64:80].encode("utf-8").hex(),
                "-e",
                "-A",
                "-base64",
            ],
            input=raw,
            capture_output=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise XidianAuthDependencyError("后端缺少 openssl，无法使用统一认证登录") from exc
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", errors="ignore").strip()
        raise XidianAuthUnavailableError(stderr or "统一认证验证码签名失败")
    return result.stdout.decode("utf-8", errors="ignore").strip()


def _generate_slider_tracks(move_length: int) -> list[dict[str, int]]:
    move = max(0, min(IDS_CAPTCHA_CANVAS_WIDTH, int(move_length)))
    tracks = [{"a": 0, "b": 0, "c": 0}]
    point_count = random.randint(10, 14)
    y = 0
    norm = 1.0 / (1.0 + pow(2.718281828459045, -7.0 * (1.0 - 0.42)))
    for index in range(point_count):
        z = (1.0 / (1.0 + pow(2.718281828459045, -7.0 * ((index / point_count) - 0.42)))) / norm
        x = min(move - 1, max(tracks[-1]["a"] + 1, round(move * z))) if move > 0 else 0
        r = random.random()
        if r < 0.65:
            y -= 1
        elif r < 0.80:
            y += 1
        y = max(-10, min(10, y))
        tracks.append({"a": int(x), "b": int(y), "c": random.randint(300, 500)})
    tracks.append({"a": move, "b": int(y), "c": random.randint(300, 500)})
    return tracks


def _verify_slider_tracks(session: Any, *, move_length: int, key_bytes: bytes) -> bool:
    requests = _import_requests()
    tracks = _generate_slider_tracks(move_length)
    payload = json.dumps(
        {
            "canvasLength": IDS_CAPTCHA_CANVAS_WIDTH,
            "moveLength": tracks[-1]["a"] if tracks else 0,
            "tracks": tracks,
        },
        separators=(",", ":"),
        ensure_ascii=False,
    )
    sign = _captcha_aes_sign(payload, key_bytes)
    try:
        response = session.post(
            IDS_SLIDER_VERIFY_URL,
            data={"sign": sign},
            headers={
                "Accept": "application/json, text/javascript, */*; q=0.01",
                "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
                "Origin": "https://ids.xidian.edu.cn",
                "Referer": "https://ids.xidian.edu.cn/authserver/login",
                "X-Requested-With": "XMLHttpRequest",
            },
            allow_redirects=False,
            timeout=_requests_timeout(),
        )
        response.raise_for_status()
    except requests.RequestException as exc:
        raise XidianAuthUnavailableError("统一认证验证码校验失败，请稍后重试") from exc
    try:
        data = response.json()
    except ValueError:
        return False
    return isinstance(data, dict) and int(data.get("errorCode", 0)) == 1


def _find_alpha_bounding_box(alpha_pixels: list[int], *, width: int, height: int) -> tuple[int, int, int, int] | None:
    x_left = width
    y_top = height
    x_right = -1
    y_bottom = -1
    for y in range(height):
        row_offset = y * width
        for x in range(width):
            if alpha_pixels[row_offset + x] != 255:
                continue
            if x < x_left:
                x_left = x
            if y < y_top:
                y_top = y
            if x > x_right:
                x_right = x
            if y > y_bottom:
                y_bottom = y
    if x_right < x_left or y_bottom < y_top:
        return None
    return (x_left, y_top, x_right, y_bottom)


def _sum_region(gray_pixels: list[int], *, image_width: int, x: int, y: int, width: int, height: int) -> float:
    total = 0.0
    for yy in range(y, y + height):
        row = yy * image_width
        for xx in range(x, x + width):
            total += gray_pixels[row + xx]
    return total


def _normalized_template(gray_pixels: list[int], *, image_width: int, x: int, y: int, width: int, height: int) -> tuple[list[float], float]:
    values: list[float] = []
    total = 0.0
    for yy in range(y, y + height):
        row = yy * image_width
        for xx in range(x, x + width):
            value = float(gray_pixels[row + xx])
            values.append(value)
            total += value
    mean = total / max(1, width * height)
    return [value - mean for value in values], mean


def _calc_ncc(
    window_pixels: list[int],
    *,
    image_width: int,
    x: int,
    y: int,
    width: int,
    height: int,
    template: list[float],
    mean_window: float,
) -> float:
    idx = 0
    sum_wt = 0.0
    sum_ww = 1e-6
    for yy in range(y, y + height):
        row = yy * image_width
        for xx in range(x, x + width):
            window_val = float(window_pixels[row + xx]) - mean_window
            template_val = template[idx]
            idx += 1
            sum_wt += window_val * template_val
            sum_ww += window_val * window_val
    return sum_wt / sum_ww


def _solve_slider_offset(puzzle_data: bytes, piece_data: bytes, *, border: int = 24) -> float | None:
    Image = _import_pillow_image()
    try:
        puzzle_rgba = Image.open(io.BytesIO(puzzle_data)).convert("RGBA")
        piece_rgba = Image.open(io.BytesIO(piece_data)).convert("RGBA")
    except Exception as exc:
        raise XidianAuthUnavailableError("统一认证验证码图片解析失败") from exc

    puzzle_gray = puzzle_rgba.convert("L")
    piece_gray = piece_rgba.convert("L")
    puzzle_width, puzzle_height = puzzle_gray.size
    piece_width, piece_height = piece_gray.size

    alpha_pixels = list(piece_rgba.getchannel("A").getdata())
    bbox = _find_alpha_bounding_box(alpha_pixels, width=piece_width, height=piece_height)
    if bbox is None:
        return None

    x_left = bbox[0] + border
    y_top = bbox[1] + border
    x_right = bbox[2] - border
    y_bottom = bbox[3] - border
    if x_right <= x_left or y_bottom <= y_top:
        return None

    match_width = x_right - x_left + 1
    match_height = y_bottom - y_top + 1
    if match_width <= 0 or match_height <= 0:
        return None

    template, _ = _normalized_template(
        list(piece_gray.getdata()),
        image_width=piece_width,
        x=x_left,
        y=y_top,
        width=match_width,
        height=match_height,
    )
    puzzle_pixels = list(puzzle_gray.getdata())

    search_width = puzzle_width - piece_width + match_width
    if search_width <= match_width:
        return None

    best_score = float("-inf")
    best_x = 0
    area = max(1, match_width * match_height)
    for candidate_x in range(0, search_width - match_width):
        mean_window = _sum_region(
            puzzle_pixels,
            image_width=puzzle_width,
            x=candidate_x + x_left,
            y=y_top,
            width=match_width,
            height=match_height,
        ) / area
        score = _calc_ncc(
            puzzle_pixels,
            image_width=puzzle_width,
            x=candidate_x + x_left,
            y=y_top,
            width=match_width,
            height=match_height,
            template=template,
            mean_window=mean_window,
        )
        if score > best_score:
            best_score = score
            best_x = candidate_x
    return best_x / max(1, puzzle_width)


def _solve_slider_captcha(session: Any, *, retry_count: int = 6) -> None:
    for _ in range(retry_count):
        payload = _load_slider_payload(session)
        big_image = str(payload.get("bigImage", "")).strip()
        small_image = str(payload.get("smallImage", "")).strip()
        if not big_image or not small_image:
            continue
        small_bytes = _decode_image(small_image)
        offset_ratio = _solve_slider_offset(_decode_image(big_image), small_bytes)
        if offset_ratio is None:
            continue
        base_move = round(offset_ratio * IDS_CAPTCHA_CANVAS_WIDTH)
        key_bytes = small_bytes[-16:]
        for delta in IDS_CAPTCHA_MOVE_DELTAS:
            move_length = base_move + delta
            if move_length < 0 or move_length > IDS_CAPTCHA_CANVAS_WIDTH:
                continue
            if _verify_slider_tracks(session, move_length=move_length, key_bytes=key_bytes):
                return
    raise XidianAuthCaptchaError("统一认证验证码校验失败，请稍后重试")


def _build_login_payload(student_id: str, password: str, inputs: dict[str, str]) -> dict[str, str]:
    encrypt_key = inputs.get("pwdEncryptSalt", "").strip()
    if not encrypt_key:
        raise XidianAuthUnavailableError("统一认证登录页格式已变化，缺少加密参数")

    payload = {
        "username": student_id,
        "password": _encrypt_ids_password(password, encrypt_key),
        "rememberMe": "true",
        "cllt": "userNameLogin",
        "dllt": "generalLogin",
        "_eventId": "submit",
    }
    for key in ("lt", "execution"):
        if key not in inputs:
            raise XidianAuthUnavailableError(f"统一认证登录页缺少必要字段：{key}")
        payload[key] = str(inputs.get(key, ""))
    return payload


def _build_campus_email(student_id: str, *, email_hint: str = "") -> str:
    hint = email_hint.strip().lower()
    if hint.endswith("@stu.xidian.edu.cn"):
        return hint
    return f"{student_id}@stu.xidian.edu.cn"


def _validated_service_ticket_redirect(response: Any, service_url: str) -> str:
    location = str(getattr(response, "headers", {}).get("Location", "") or "").strip()
    if not location:
        raise XidianAuthUnavailableError("统一认证未返回目标系统跳转地址")

    response_url = str(getattr(response, "url", "") or IDS_LOGIN_URL)
    redirect_url = urljoin(response_url, location)
    expected = urlsplit(service_url)
    actual = urlsplit(redirect_url)
    if (
        actual.scheme.lower() != expected.scheme.lower()
        or actual.netloc.lower() != expected.netloc.lower()
        or actual.path.rstrip("/") != expected.path.rstrip("/")
    ):
        raise XidianAuthUnavailableError("统一认证返回了非目标系统跳转")

    tickets = [
        value.strip()
        for value in parse_qs(actual.query, keep_blank_values=True).get("ticket", [])
        if value.strip()
    ]
    if not tickets:
        raise XidianAuthUnavailableError("统一认证未返回有效服务票据")
    return redirect_url


def _service_ticket_from_redirect(redirect_url: str) -> str:
    tickets = [
        value.strip()
        for value in parse_qs(
            urlsplit(redirect_url).query,
            keep_blank_values=True,
        ).get("ticket", [])
        if value.strip()
    ]
    if not tickets:
        raise XidianAuthUnavailableError("统一认证未返回有效服务票据")
    return tickets[0]


def _validate_password_login_redirect(
    response: Any,
    *,
    requested_student_id: str,
) -> XidianAuthResult:
    redirect_url = _validated_service_ticket_redirect(response, EHALL_SERVICE_URL)
    ticket = _service_ticket_from_redirect(redirect_url)
    result = validate_xidian_service_ticket(ticket, EHALL_SERVICE_URL)
    if result.student_id.strip().lower() != requested_student_id.strip().lower():
        raise XidianAuthPasswordError("统一认证返回的账号与登录学号不一致")
    return result


def login_via_xidian_ids(student_id: str, password: str, *, email_hint: str = "") -> XidianAuthResult:
    requests = _import_requests()
    session = requests.Session()
    session.headers.update(IDS_HEADERS)

    try:
        response = session.get(
            IDS_LOGIN_URL,
            params={"service": EHALL_SERVICE_URL},
            allow_redirects=False,
            timeout=_requests_timeout(),
        )
    except requests.RequestException as exc:
        raise XidianAuthUnavailableError("无法连接西电统一认证，请稍后重试") from exc

    if response.status_code == 401:
        raise XidianAuthPasswordError(_parse_password_error_message(response.text))
    if response.status_code in (301, 302):
        return _validate_password_login_redirect(
            response,
            requested_student_id=student_id,
        )

    if response.status_code != 200:
        raise XidianAuthUnavailableError(f"统一认证服务异常（状态码 {response.status_code}）")

    inputs = _extract_inputs(response.text)
    payload = _build_login_payload(student_id, password, inputs)
    _solve_slider_captcha(session)

    try:
        response = session.post(
            IDS_LOGIN_URL,
            data=payload,
            params={"service": EHALL_SERVICE_URL},
            allow_redirects=False,
            timeout=_requests_timeout(),
        )
    except requests.RequestException as exc:
        raise XidianAuthUnavailableError("统一认证登录请求失败，请稍后重试") from exc

    if response.status_code in (301, 302):
        return _validate_password_login_redirect(
            response,
            requested_student_id=student_id,
        )

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
                params={"service": EHALL_SERVICE_URL},
                allow_redirects=False,
                timeout=_requests_timeout(),
            )
        except requests.RequestException as exc:
            raise XidianAuthUnavailableError("统一认证登录续跳失败，请稍后重试") from exc
        if response.status_code in (301, 302):
            return _validate_password_login_redirect(
                response,
                requested_student_id=student_id,
            )
        if response.status_code == 401:
            raise XidianAuthPasswordError(_parse_password_error_message(response.text))
        error_message = _extract_login_error_message(response.text)
        if error_message:
            raise XidianAuthPasswordError(_parse_password_error_message(response.text))

    raise XidianAuthUnavailableError("统一认证登录失败：未返回登录跳转")


def _xml_local_name(tag: str) -> str:
    if "}" in tag:
        return tag.rsplit("}", 1)[-1]
    return tag


def _parse_service_validate_result(xml_text: str) -> XidianAuthResult:
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
