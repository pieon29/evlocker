import base64
import io
import os
import sys

import psycopg
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))

DSN = os.environ.get("TEST_DATABASE_URL", "host=/tmp/pgtest port=55432 user=evl_app dbname=evlocker")
OWNER_DSN = os.environ.get("TEST_OWNER_DATABASE_URL", "host=/tmp/pgtest port=55432 user=postgres dbname=evlocker")
INV = "inv-token-for-tests"
AUD = "aud-token-for-tests"


@pytest.fixture(scope="module")
def client():
    os.environ.update(
        {
            "DATABASE_URL": DSN,
            "APP_ENC_KEY": base64.b64encode(b"k" * 32).decode(),
            "TOKEN_INVESTIGATOR": INV,
            "TOKEN_AUDITOR": AUD,
            "NODE_NAME": "test01",
        }
    )
    os.environ.pop("PROMETHEUS_MULTIPROC_DIR", None)
    from evlocker import create_app

    app = create_app()
    app.testing = True
    with app.test_client() as c:
        yield c
    app.extensions["pool"].close()


def auth(token):
    return {"Authorization": f"Bearer {token}"}


def register(client, payload=b"dummy disk image bytes", case="CASE-TEST-001"):
    return client.post(
        "/api/evidence",
        headers=auth(INV),
        data={"case_no": case, "title": "test image", "file": (io.BytesIO(payload), "image.dd")},
        content_type="multipart/form-data",
    )


def test_health_and_ready(client):
    assert client.get("/healthz").status_code == 200
    assert client.get("/readyz").status_code == 200


def test_rejects_missing_and_wrong_token(client):
    assert client.get("/api/evidence").status_code == 401
    assert client.get("/api/evidence", headers=auth("wrong")).status_code == 401
    metrics = client.get("/metrics").data.decode()
    assert 'evl_auth_failures_total{node="test01"}' in metrics


def test_auditor_cannot_register_or_download(client):
    r = client.post("/api/evidence", headers=auth(AUD), data={"case_no": "x", "title": "y"})
    assert r.status_code == 401
    eid = register(client).get_json()["id"]
    assert client.get(f"/api/evidence/{eid}/download", headers=auth(AUD)).status_code == 401


def test_register_download_roundtrip_and_chain(client):
    payload = b"\x00\x01forensic-sample" * 100
    r = register(client, payload)
    assert r.status_code == 201
    body = r.get_json()
    eid = body["id"]
    assert client.get(f"/api/evidence/{eid}", headers=auth(AUD)).status_code == 200
    assert client.get(f"/api/evidence/{eid}", headers=auth(INV)).status_code == 200
    d = client.get(f"/api/evidence/{eid}/download", headers=auth(INV))
    assert d.status_code == 200 and d.data == payload
    c = client.get(f"/api/evidence/{eid}/custody", headers=auth(AUD)).get_json()
    assert c["chain_valid"] is True
    assert [e["action"] for e in c["events"]] == ["register", "view", "view", "download"]
    v = client.get("/api/audit/verify", headers=auth(AUD)).get_json()
    assert v["ok"] is True and v["events"] >= 4


def test_ciphertext_at_rest_is_not_plaintext(client):
    payload = b"PLAINTEXT-MARKER-1234567890"
    eid = register(client, payload).get_json()["id"]
    with psycopg.connect(DSN) as conn:
        stored = conn.execute("SELECT ciphertext FROM evidence WHERE id = %s", (eid,)).fetchone()[0]
    assert payload not in bytes(stored)


def test_app_role_cannot_tamper(client):
    eid = register(client).get_json()["id"]
    with psycopg.connect(DSN) as conn:
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            conn.execute("UPDATE custody_events SET actor = 'mallory' WHERE evidence_id = %s", (eid,))


def test_owner_cannot_tamper_either():
    with psycopg.connect(OWNER_DSN) as conn:
        with pytest.raises(psycopg.errors.RaiseException):
            conn.execute("DELETE FROM custody_events")


def test_cache_hit_metric(client):
    eid = register(client).get_json()["id"]
    client.get(f"/api/evidence/{eid}", headers=auth(INV))
    client.get(f"/api/evidence/{eid}", headers=auth(INV))
    metrics = client.get("/metrics").data.decode()
    assert 'evl_cache_requests_total{node="test01",result="hit"}' in metrics
