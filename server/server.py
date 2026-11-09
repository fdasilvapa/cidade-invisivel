#!/usr/bin/env python3
"""Servidor local do Cidade Invisível: API (SQLite) + app web, no mesmo endereço.

Uso:  python3 server/server.py [--port 8080] [--host 127.0.0.1] [--static build/web]
Dados em server/data/ (cidade.db e photos/).
"""
import argparse
import base64
import json
import os
import re
import sqlite3
import threading
import uuid
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(ROOT, "data")
PHOTOS = os.path.join(DATA, "photos")
DB_PATH = os.path.join(DATA, "cidade.db")
os.makedirs(PHOTOS, exist_ok=True)

CATEGORIES = {"pavimentacao", "acessibilidade", "obstaculos", "sinalizacao",
              "desniveis", "bloqueios"}
SEVERITIES = {"low", "medium", "high"}
MAX_BODY = 12 * 1024 * 1024
MAX_PHOTO = 8 * 1024 * 1024
LOCK = threading.Lock()

SCHEMA = """
CREATE TABLE IF NOT EXISTS issues (
  id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  severity TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_confirmed_at TEXT NOT NULL,
  confirmation_count INTEGER NOT NULL DEFAULT 0,
  resolved INTEGER NOT NULL DEFAULT 0,
  flagged INTEGER NOT NULL DEFAULT 0,
  author_id TEXT NOT NULL,
  ai_confidence REAL,
  photo_mime TEXT
);
CREATE TABLE IF NOT EXISTS confirmations (
  issue_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (issue_id, device_id)
);
"""


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def db():
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    return c


def sniff_mime(b):
    if b[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if b[:4] == b"RIFF" and b[8:12] == b"WEBP":
        return "image/webp"
    return None


def issue_json(row, device_id, confirmed_ids):
    return {
        "id": row["id"],
        "category": row["category"],
        "description": row["description"],
        "latitude": row["latitude"],
        "longitude": row["longitude"],
        "severity": row["severity"],
        "createdAt": row["created_at"],
        "lastConfirmedAt": row["last_confirmed_at"],
        "confirmationCount": row["confirmation_count"],
        "resolved": bool(row["resolved"]),
        "flagged": bool(row["flagged"]),
        "mine": bool(device_id) and row["author_id"] == device_id,
        "confirmedByMe": row["id"] in confirmed_ids,
        "aiConfidence": row["ai_confidence"],
        "photoUrl": f"/api/photos/{row['id']}" if row["photo_mime"] else None,
    }


class Handler(SimpleHTTPRequestHandler):
    static_dir = "."

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=Handler.static_dir, **kw)

    # ---------- util ----------
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers",
                         "Content-Type, ngrok-skip-browser-warning")

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n > MAX_BODY:
            raise ValueError("Corpo da requisição grande demais.")
        raw = self.rfile.read(n) if n else b"{}"
        return json.loads(raw or b"{}")

    def log_message(self, fmt, *args):
        if self.path.startswith("/api/"):
            super().log_message(fmt, *args)

    # ---------- métodos ----------
    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        u = urlparse(self.path)
        if u.path.startswith("/api/"):
            return self._api("GET", u)
        # arquivos estáticos (com fallback para o index.html)
        fs = self.translate_path(u.path)
        if not os.path.exists(fs) or os.path.isdir(fs) and not os.path.exists(
                os.path.join(fs, "index.html")):
            self.path = "/index.html"
        return super().do_GET()

    def do_POST(self):
        u = urlparse(self.path)
        if not u.path.startswith("/api/"):
            return self._json(404, {"error": "não encontrado"})
        self._api("POST", u)

    def end_headers(self):
        if not self.path.startswith("/api/"):
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    # ---------- API ----------
    def _api(self, method, u):
        try:
            parts = [p for p in u.path.split("/") if p][1:]  # sem "api"
            q = parse_qs(u.query)
            if method == "GET" and parts == ["health"]:
                return self._json(200, {"ok": True})
            if method == "GET" and parts == ["issues"]:
                return self._list(q.get("deviceId", [""])[0])
            if method == "GET" and len(parts) == 2 and parts[0] == "photos":
                return self._photo(parts[1])
            if method == "POST" and parts == ["issues"]:
                return self._create(self._body())
            if method == "POST" and len(parts) == 3 and parts[0] == "issues":
                return self._action(parts[1], parts[2], self._body())
            self._json(404, {"error": "rota inexistente"})
        except (ValueError, KeyError, TypeError, json.JSONDecodeError) as e:
            self._json(400, {"error": f"requisição inválida: {e}"})
        except Exception as e:  # noqa: BLE001
            self._json(500, {"error": f"erro interno: {e}"})

    def _list(self, device_id):
        with LOCK, db() as c:
            rows = c.execute(
                "SELECT * FROM issues ORDER BY created_at DESC").fetchall()
            conf = {r["issue_id"] for r in c.execute(
                "SELECT issue_id FROM confirmations WHERE device_id=?",
                (device_id,))} if device_id else set()
        self._json(200, [issue_json(r, device_id, conf) for r in rows])

    def _photo(self, issue_id):
        if not re.fullmatch(r"[0-9a-f]{32}", issue_id):
            return self._json(404, {"error": "foto inexistente"})
        with LOCK, db() as c:
            row = c.execute("SELECT photo_mime FROM issues WHERE id=?",
                            (issue_id,)).fetchone()
        path = os.path.join(PHOTOS, issue_id + ".bin")
        if not row or not row["photo_mime"] or not os.path.exists(path):
            return self._json(404, {"error": "foto inexistente"})
        data = open(path, "rb").read()
        self.send_response(200)
        self.send_header("Content-Type", row["photo_mime"])
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "public, max-age=86400")
        self._cors()
        self.end_headers()
        self.wfile.write(data)

    def _create(self, b):
        cat, sev = b["category"], b.get("severity", "medium")
        if cat not in CATEGORIES or sev not in SEVERITIES:
            raise ValueError("categoria ou gravidade inválida")
        lat, lng = float(b["latitude"]), float(b["longitude"])
        if not (-90 <= lat <= 90 and -180 <= lng <= 180):
            raise ValueError("coordenadas inválidas")
        author = str(b["authorId"])[:64]
        if not author:
            raise ValueError("authorId obrigatório")
        desc = (str(b.get("description") or "").strip() or cat)[:500]

        mime, photo = None, None
        if b.get("photoBase64"):
            photo = base64.b64decode(b["photoBase64"])
            if len(photo) > MAX_PHOTO:
                raise ValueError("foto grande demais")
            mime = sniff_mime(photo)
            if not mime:
                raise ValueError("formato de imagem não suportado")

        iid, t = uuid.uuid4().hex, now()
        with LOCK, db() as c:
            c.execute(
                "INSERT INTO issues (id,category,description,latitude,longitude,"
                "severity,created_at,last_confirmed_at,author_id,photo_mime) "
                "VALUES (?,?,?,?,?,?,?,?,?,?)",
                (iid, cat, desc, lat, lng, sev, t, t, author, mime))
            if photo:
                with open(os.path.join(PHOTOS, iid + ".bin"), "wb") as f:
                    f.write(photo)
            row = c.execute("SELECT * FROM issues WHERE id=?", (iid,)).fetchone()
        self._json(201, issue_json(row, author, set()))

    def _action(self, issue_id, action, b):
        device = str(b.get("deviceId") or "")[:64]
        if not device:
            raise ValueError("deviceId obrigatório")
        with LOCK, db() as c:
            row = c.execute("SELECT * FROM issues WHERE id=?",
                            (issue_id,)).fetchone()
            if not row:
                return self._json(404, {"error": "registro inexistente"})
            if action == "confirm":
                cur = c.execute(
                    "INSERT OR IGNORE INTO confirmations VALUES (?,?,?)",
                    (issue_id, device, now()))
                if cur.rowcount:
                    c.execute(
                        "UPDATE issues SET confirmation_count=confirmation_count+1,"
                        "last_confirmed_at=?, resolved=0 WHERE id=?",
                        (now(), issue_id))
            elif action == "resolve":
                c.execute("UPDATE issues SET resolved=1 WHERE id=?", (issue_id,))
            elif action == "flag":
                c.execute("UPDATE issues SET flagged=1 WHERE id=?", (issue_id,))
            else:
                return self._json(404, {"error": "ação inexistente"})
            row = c.execute("SELECT * FROM issues WHERE id=?",
                            (issue_id,)).fetchone()
            conf = {r["issue_id"] for r in c.execute(
                "SELECT issue_id FROM confirmations WHERE device_id=?", (device,))}
        self._json(200, issue_json(row, device, conf))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--static", default=os.path.join(ROOT, "..", "build", "web"))
    a = ap.parse_args()
    with db() as c:
        c.executescript(SCHEMA)
    Handler.static_dir = os.path.abspath(a.static)
    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    print(f"Cidade Invisível em http://{a.host}:{a.port}  (estáticos: {Handler.static_dir})")
    srv.serve_forever()


if __name__ == "__main__":
    main()
