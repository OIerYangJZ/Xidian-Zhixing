#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


PLACEHOLDER_MARKERS = (
    "REPLACE_WITH_",
    "REPLACE-WITH-",
    "CHANGE_ME",
    "CHANGEME",
    "YOUR_",
)


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ValueError(f"line {line_number} is not KEY=VALUE")
        key, value = line.split("=", 1)
        key = key.strip()
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise ValueError(f"line {line_number} has an invalid key")
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        values[key] = value
    return values


def is_placeholder(value: str) -> bool:
    upper = value.strip().upper()
    return not upper or any(marker in upper for marker in PLACEHOLDER_MARKERS)


def validate(values: dict[str, str]) -> list[str]:
    errors: list[str] = []

    def require(key: str) -> str:
        value = values.get(key, "").strip()
        if is_placeholder(value):
            errors.append(f"{key} is missing or still a placeholder")
        return value

    if values.get("BACKEND_ENV", "").strip().lower() != "production":
        errors.append("BACKEND_ENV must be production")
    if values.get("BACKEND_HOST", "").strip() != "127.0.0.1":
        errors.append("BACKEND_HOST must be 127.0.0.1 behind Nginx")
    try:
        port = int(values.get("BACKEND_PORT", ""))
        if not 1 <= port <= 65535:
            raise ValueError
    except ValueError:
        errors.append("BACKEND_PORT must be an integer from 1 to 65535")

    require("BACKEND_ADMIN_USERNAME")
    admin_password = require("BACKEND_ADMIN_PASSWORD")
    if admin_password and len(admin_password) < 12:
        errors.append("BACKEND_ADMIN_PASSWORD must contain at least 12 characters")

    for key in ("BACKEND_DB_FILE", "BACKEND_STORAGE_DIR", "BACKEND_WEB_ROOT"):
        value = require(key)
        if value and not value.startswith("/home/ubuntu/treehole/"):
            errors.append(f"{key} must be inside /home/ubuntu/treehole")

    storage_backend = require("BACKEND_OBJECT_STORAGE_BACKEND").lower()
    if storage_backend not in {"local", "s3", "oss", "s3_compat"}:
        errors.append("BACKEND_OBJECT_STORAGE_BACKEND has an unsupported value")
    if storage_backend in {"s3", "oss", "s3_compat"}:
        for key in (
            "BACKEND_S3_BUCKET",
            "BACKEND_S3_ENDPOINT",
            "BACKEND_S3_ACCESS_KEY_ID",
            "BACKEND_S3_SECRET_ACCESS_KEY",
        ):
            require(key)

    for key in (
        "BACKEND_SMTP_HOST",
        "BACKEND_SMTP_USERNAME",
        "BACKEND_SMTP_PASSWORD",
        "BACKEND_SMTP_FROM_EMAIL",
    ):
        require(key)

    for key in (
        "BACKEND_ALLOW_DEBUG_VERIFY_CODE",
        "BACKEND_INCLUDE_DEBUG_CODE",
        "BACKEND_SEED_DEMO_DATA",
    ):
        if values.get(key, "").strip().lower() != "false":
            errors.append(f"{key} must be false in production")

    public_origin = values.get("BACKEND_XIDIAN_PUBLIC_ORIGIN", "").strip()
    if public_origin and not public_origin.startswith("https://"):
        errors.append("BACKEND_XIDIAN_PUBLIC_ORIGIN must use HTTPS when configured")

    ai_base_url = values.get("BACKEND_AI_BASE_URL", "").strip()
    ai_api_key = values.get("BACKEND_AI_API_KEY", "").strip()
    if ai_base_url or ai_api_key:
        if not ai_base_url.startswith("https://"):
            errors.append("BACKEND_AI_BASE_URL must use HTTPS when AI is enabled")
        require("BACKEND_AI_API_KEY")
        require("BACKEND_AI_MODEL")
    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_production_env.py /path/to/backend.env", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"[env] file not found: {path}", file=sys.stderr)
        return 1
    try:
        values = load_env(path)
    except (OSError, UnicodeError, ValueError) as error:
        print(f"[env] invalid environment file: {error}", file=sys.stderr)
        return 1
    errors = validate(values)
    if errors:
        for error in errors:
            print(f"[env] {error}", file=sys.stderr)
        return 1
    print("[env] production environment validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
