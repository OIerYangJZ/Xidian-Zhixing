#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 6:
        print(
            "usage: render_nginx_https.py TEMPLATE DOMAIN CERTIFICATE PRIVATE_KEY OUTPUT",
            file=sys.stderr,
        )
        return 2
    template_path, domain, certificate, private_key, output_path = sys.argv[1:]
    if not re.fullmatch(r"(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}", domain):
        print("[nginx] invalid domain", file=sys.stderr)
        return 1
    for label, value in (("certificate", certificate), ("private key", private_key)):
        if not value.startswith("/") or any(char.isspace() for char in value):
            print(f"[nginx] {label} path must be an absolute path without whitespace", file=sys.stderr)
            return 1
    template = Path(template_path).read_text(encoding="utf-8")
    for marker in ("__DOMAIN__", "__CERTIFICATE__", "__PRIVATE_KEY__"):
        if marker not in template:
            print(f"[nginx] template is missing {marker}", file=sys.stderr)
            return 1
    rendered = (
        template.replace("__DOMAIN__", domain)
        .replace("__CERTIFICATE__", certificate)
        .replace("__PRIVATE_KEY__", private_key)
    )
    Path(output_path).write_text(rendered, encoding="utf-8")
    print(f"[nginx] wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
