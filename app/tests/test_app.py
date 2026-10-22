"""Unit tests for gateway-ops endpoints.

The /dial-out allowlist is the security-critical surface: an open
target parameter is an SSRF vector. These tests pin the contract.
"""
import pytest


@pytest.fixture
def client(monkeypatch):
    """Flask test client with controlled env for instrumentation."""
    monkeypatch.setenv("PACKAGE_NAME", "gateway-ops")
    monkeypatch.setenv("BUILD_NUMBER", "99")
    monkeypatch.setenv("COMMIT_SHA", "abc1234")
    monkeypatch.setenv("GREETING", "Comtrya!")

    # Import after env is set so module-level constants capture it
    if "app.app" in __import__("sys").modules:
        del __import__("sys").modules["app.app"]
    from app import app as app_module

    app_module.app.config["TESTING"] = True
    with app_module.app.test_client() as client:
        yield client


class TestHealth:
    def test_health_returns_healthy(self, client):
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.get_json()["status"] == "healthy"


class TestDialOutAllowlist:
    """SSRF regression tests - see security audit, /dial-out."""

    def test_default_target_is_echo(self, client):
        resp = client.get("/dial-out")
        assert resp.status_code == 200

    @pytest.mark.parametrize("path", ["/echo", "/health", "/version", "/"])
    def test_allowlisted_paths_accepted(self, client, path):
        resp = client.get(f"/dial-out?target={path}")
        assert resp.status_code == 200
        assert resp.get_json()["target"].endswith(path)

    def test_absolute_url_rejected(self, client):
        resp = client.get("/dial-out?target=http://169.254.169.254/latest/meta-data/")
        assert resp.status_code == 400

    def test_nonallowlisted_relative_rejected(self, client):
        resp = client.get("/dial-out?target=/admin")
        assert resp.status_code == 400
        body = resp.get_json()
        assert "error" in body
        assert "/admin" not in str(body.get("allowed_targets", ""))