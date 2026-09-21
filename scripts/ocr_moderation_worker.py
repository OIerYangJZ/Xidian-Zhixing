"""Small local OCR worker used by BACKEND_IMAGE_OCR_URL.

Run from the repository root after installing backend/requirements-moderation.txt:
    python scripts/ocr_moderation_worker.py --port 8092

The endpoint accepts the same JSON envelope as the backend image adapter and
returns extracted text. It intentionally has no public-network behavior.
"""
from __future__ import annotations

import argparse
import base64
import io
import json
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def _flatten(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        for key in ("rec_texts", "text", "texts"):
            if key in value:
                return _flatten(value[key])
        return []
    if isinstance(value, (list, tuple)):
        result: list[str] = []
        for item in value:
            result.extend(_flatten(item))
        return result
    return []


class OcrHandler(BaseHTTPRequestHandler):
    ocr = None

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/ocr":
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(length).decode("utf-8"))
            raw = base64.b64decode(str(body.get("imageBase64", "")), validate=True)
            from PIL import Image

            result = self.ocr.predict(Image.open(io.BytesIO(raw)))
            texts = _flatten(result)
            payload = {"text": " ".join(text.strip() for text in texts if text.strip())}
            encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
        except Exception as error:
            self.send_error(HTTPStatus.BAD_REQUEST, str(error))

    def log_message(self, *_args: object) -> None:
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8092)
    args = parser.parse_args()

    from paddleocr import PaddleOCR

    OcrHandler.ocr = PaddleOCR(lang="ch")
    server = ThreadingHTTPServer((args.host, args.port), OcrHandler)
    print(f"OCR moderation worker listening on http://{args.host}:{args.port}/ocr", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
