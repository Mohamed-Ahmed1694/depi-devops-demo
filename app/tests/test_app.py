import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app  # noqa: E402


def client():
    app.config["TESTING"] = True
    return app.test_client()


def test_home_page():
    res = client().get("/")
    assert res.status_code == 200
    assert b"DEPI" in res.data


def test_api():
    res = client().get("/api")
    assert res.status_code == 200
    assert "DEPI" in res.get_json()["message"]


def test_health():
    res = client().get("/health")
    assert res.status_code == 200
    assert res.get_json()["status"] == "ok"


def test_metrics():
    c = client()
    c.get("/")
    res = c.get("/metrics")
    assert res.status_code == 200
    assert b"demo_app_requests_total" in res.data
