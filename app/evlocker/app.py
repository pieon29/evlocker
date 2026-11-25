import hmac
import io
import logging
import os
import socket
import time
from collections import OrderedDict
from datetime import datetime, timezone
from threading import Lock

import psycopg
from flask import Flask, Response, g, jsonify, request, send_file
from psycopg_pool import ConnectionPool
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    CollectorRegistry,
    Counter,
    Histogram,
    generate_latest,
    multiprocess,
)

from .crypto import GENESIS, EvidenceCipher, chain_hash, sha256_hex

NODE = os.environ.get("NODE_NAME", socket.gethostname())
VERSION = os.environ.get("APP_VERSION", "1.0.0")

REQUESTS = Counter(
    "evl_http_requests_total", "HTTP requests", ["method", "endpoint", "status", "node"]
)
LATENCY = Histogram(
    "evl_http_request_duration_seconds",
    "HTTP request latency",
    ["endpoint", "node"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 1.0, 2.5, 5.0),
)
AUTH_FAILURES = Counter("evl_auth_failures_total", "Rejected tokens", ["node"])
DB_ERRORS = Counter("evl_db_errors_total", "Database errors", ["node"])
CACHE = Counter("evl_cache_requests_total", "Metadata cache lookups", ["result", "node"])

log = logging.getLogger("evlocker")


class MetadataCache:
    def __init__(self, capacity: int):
        self._capacity = capacity
        self._items: OrderedDict = OrderedDict()
        self._lock = Lock()

    def get(self, key):
        with self._lock:
            if key in self._items:
                self._items.move_to_end(key)
                CACHE.labels("hit", NODE).inc()
                return self._items[key]
        CACHE.labels("miss", NODE).inc()
        return None

    def put(self, key, value):
        with self._lock:
            self._items[key] = value
            self._items.move_to_end(key)
            while len(self._items) > self._capacity:
                self._items.popitem(last=False)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds")


def create_app(pool: ConnectionPool | None = None) -> Flask:
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = 10 * 1024 * 1024

    tokens = {
        "investigator": os.environ.get("TOKEN_INVESTIGATOR", ""),
        "auditor": os.environ.get("TOKEN_AUDITOR", ""),
    }
    cipher = EvidenceCipher(os.environ["APP_ENC_KEY"])
    cache = MetadataCache(int(os.environ.get("CACHE_SIZE", "2048")))

    if pool is None:
        pool = ConnectionPool(
            os.environ["DATABASE_URL"],
            min_size=1,
            max_size=int(os.environ.get("DB_POOL_MAX", "5")),
            timeout=5,
            check=ConnectionPool.check_connection,
            open=False,
        )
    app.extensions["pool"] = pool

    def get_pool() -> ConnectionPool:
        p = app.extensions["pool"]
        if getattr(p, "closed", False):
            p.open(wait=False)
        return p

    def authorize(*roles):
        header = request.headers.get("Authorization", "")
        presented = header[7:] if header.startswith("Bearer ") else ""
        for role in roles:
            expected = tokens.get(role, "")
            if expected and presented and hmac.compare_digest(presented, expected):
                g.actor = role
                return None
        AUTH_FAILURES.labels(NODE).inc()
        log.warning(
            "auth_failed node=%s path=%s remote=%s", NODE, request.path, request.headers.get("X-Real-IP", request.remote_addr)
        )
        return jsonify(error="unauthorized"), 401

    def append_event(cur, evidence_id: int, action: str, detail: str | None = None) -> None:
        cur.execute("SELECT pg_advisory_xact_lock(%s)", (evidence_id,))
        cur.execute(
            "SELECT event_hash FROM custody_events WHERE evidence_id = %s ORDER BY id DESC LIMIT 1",
            (evidence_id,),
        )
        row = cur.fetchone()
        prev = row[0] if row else GENESIS
        created = _now()
        digest = chain_hash(prev, evidence_id, action, g.actor, created)
        cur.execute(
            "INSERT INTO custody_events (evidence_id, action, actor, node, detail, prev_hash, event_hash, created_at)"
            " VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            (evidence_id, action, g.actor, NODE, detail, prev, digest, created),
        )

    def load_metadata(cur, evidence_id: int):
        cached = cache.get(evidence_id)
        if cached is not None:
            return cached
        cur.execute(
            "SELECT id, case_no, title, filename, size_bytes, sha256, registered_by, created_at"
            " FROM evidence WHERE id = %s",
            (evidence_id,),
        )
        row = cur.fetchone()
        if row is None:
            return None
        meta = {
            "id": row[0],
            "case_no": row[1],
            "title": row[2],
            "filename": row[3],
            "size_bytes": row[4],
            "sha256": row[5],
            "registered_by": row[6],
            "created_at": row[7].isoformat(),
        }
        cache.put(evidence_id, meta)
        return meta

    @app.before_request
    def start_timer():
        g.start = time.perf_counter()
        g.actor = "anonymous"

    @app.after_request
    def record(response):
        endpoint = request.url_rule.rule if request.url_rule else "unmatched"
        if endpoint != "/metrics":
            REQUESTS.labels(request.method, endpoint, str(response.status_code), NODE).inc()
            LATENCY.labels(endpoint, NODE).observe(time.perf_counter() - g.start)
        response.headers["X-Served-By"] = NODE
        return response

    @app.errorhandler(psycopg.OperationalError)
    def db_down(exc):
        DB_ERRORS.labels(NODE).inc()
        log.error("db_error node=%s err=%s", NODE, exc.__class__.__name__)
        return jsonify(error="database unavailable"), 503

    @app.get("/")
    def index():
        return Response(
            "<!doctype html><meta charset='utf-8'><title>evlocker</title>"
            f"<h1>evlocker 디지털 증거 보관함</h1><p>node {NODE} · version {VERSION}</p>",
            mimetype="text/html",
        )

    @app.get("/healthz")
    def healthz():
        return jsonify(status="ok")

    @app.get("/readyz")
    def readyz():
        with get_pool().connection() as conn:
            conn.execute("SELECT 1")
        return jsonify(status="ready", node=NODE)

    @app.get("/version")
    def version():
        return jsonify(version=VERSION, node=NODE)

    @app.get("/metrics")
    def metrics():
        if "PROMETHEUS_MULTIPROC_DIR" in os.environ:
            registry = CollectorRegistry()
            multiprocess.MultiProcessCollector(registry)
            return Response(generate_latest(registry), mimetype=CONTENT_TYPE_LATEST)
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

    @app.post("/api/evidence")
    def register():
        denied = authorize("investigator")
        if denied:
            return denied
        upload = request.files.get("file")
        case_no = request.form.get("case_no", "").strip()
        title = request.form.get("title", "").strip()
        if upload is None or not case_no or not title:
            return jsonify(error="case_no, title and file are required"), 400
        data = upload.read()
        digest = sha256_hex(data)
        nonce, ciphertext = cipher.encrypt(data, digest)
        with get_pool().connection() as conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO evidence (case_no, title, filename, size_bytes, sha256, nonce, ciphertext, registered_by)"
                " VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING id",
                (case_no, title, upload.filename or "unnamed", len(data), digest, nonce, ciphertext, g.actor),
            )
            evidence_id = cur.fetchone()[0]
            append_event(cur, evidence_id, "register", f"sha256={digest}")
        return jsonify(id=evidence_id, sha256=digest, node=NODE), 201

    @app.get("/api/evidence")
    def list_evidence():
        denied = authorize("investigator", "auditor")
        if denied:
            return denied
        case_no = request.args.get("case_no")
        with get_pool().connection() as conn, conn.cursor() as cur:
            if case_no:
                cur.execute(
                    "SELECT id, case_no, title, sha256, created_at FROM evidence WHERE case_no = %s ORDER BY id DESC LIMIT 50",
                    (case_no,),
                )
            else:
                cur.execute("SELECT id, case_no, title, sha256, created_at FROM evidence ORDER BY id DESC LIMIT 50")
            rows = cur.fetchall()
        return jsonify(
            items=[
                {"id": r[0], "case_no": r[1], "title": r[2], "sha256": r[3], "created_at": r[4].isoformat()}
                for r in rows
            ]
        )

    @app.get("/api/evidence/<int:evidence_id>")
    def get_evidence(evidence_id: int):
        denied = authorize("investigator", "auditor")
        if denied:
            return denied
        with get_pool().connection() as conn, conn.cursor() as cur:
            meta = load_metadata(cur, evidence_id)
            if meta is None:
                return jsonify(error="not found"), 404
            append_event(cur, evidence_id, "view")
        return jsonify(meta)

    @app.get("/api/evidence/<int:evidence_id>/download")
    def download(evidence_id: int):
        denied = authorize("investigator")
        if denied:
            return denied
        with get_pool().connection() as conn, conn.cursor() as cur:
            cur.execute(
                "SELECT filename, sha256, nonce, ciphertext FROM evidence WHERE id = %s", (evidence_id,)
            )
            row = cur.fetchone()
            if row is None:
                return jsonify(error="not found"), 404
            filename, digest, nonce, ciphertext = row
            data = cipher.decrypt(bytes(nonce), bytes(ciphertext), digest)
            if sha256_hex(data) != digest:
                append_event(cur, evidence_id, "integrity_failure")
                return jsonify(error="integrity check failed"), 500
            append_event(cur, evidence_id, "download")
        return send_file(io.BytesIO(data), download_name=filename, as_attachment=True)

    @app.get("/api/evidence/<int:evidence_id>/custody")
    def custody(evidence_id: int):
        denied = authorize("investigator", "auditor")
        if denied:
            return denied
        with get_pool().connection() as conn, conn.cursor() as cur:
            cur.execute(
                "SELECT id, action, actor, node, prev_hash, event_hash, created_at FROM custody_events"
                " WHERE evidence_id = %s ORDER BY id",
                (evidence_id,),
            )
            rows = cur.fetchall()
        valid, events, prev = True, [], GENESIS
        for r in rows:
            created = r[6].astimezone(timezone.utc).isoformat(timespec="microseconds")
            ok = r[4] == prev and r[5] == chain_hash(prev, evidence_id, r[1], r[2], created)
            valid = valid and ok
            prev = r[5]
            events.append({"id": r[0], "action": r[1], "actor": r[2], "node": r[3], "at": created, "ok": ok})
        return jsonify(evidence_id=evidence_id, chain_valid=valid, events=events)

    @app.get("/api/audit/verify")
    def verify_all():
        denied = authorize("auditor")
        if denied:
            return denied
        broken, total = [], 0
        with get_pool().connection() as conn, conn.cursor() as cur:
            cur.execute(
                "SELECT evidence_id, action, actor, prev_hash, event_hash, created_at FROM custody_events"
                " ORDER BY evidence_id, id"
            )
            last = {}
            for evidence_id, action, actor, prev_hash, event_hash, created_at in cur:
                total += 1
                expected_prev = last.get(evidence_id, GENESIS)
                created = created_at.astimezone(timezone.utc).isoformat(timespec="microseconds")
                if prev_hash != expected_prev or event_hash != chain_hash(prev_hash, evidence_id, action, actor, created):
                    broken.append(evidence_id)
                last[evidence_id] = event_hash
        return jsonify(ok=not broken, events=total, broken_evidence=sorted(set(broken)))

    return app
