from flask import Flask, jsonify, request
import os
import socket
import uuid
from datetime import datetime, timezone

import requests

app = Flask(__name__)

# ---- Build provenance: baked at image build time ----
PACKAGE_NAME = os.environ.get("PACKAGE_NAME", "gateway-ops")
BUILD_NUMBER = os.environ.get("BUILD_NUMBER", "local")
COMMIT_SHA   = os.environ.get("COMMIT_SHA", "unknown")


# --- Allowed internal targets for /dial-out ---
# Explicit allowlist. Never accept an arbitrary URL here: an open
# target parameter is a server-side request forgery (SSRF) vector.
ALLOWED_TARGETS = {"/echo", "/health", "/version", "/"}
SELF_BASE_URL = os.environ.get("SELF_BASE_URL", "http://localhost:5000")


# Only these headers are reflected by /echo. Reflecting all request
# headers risks leaking credentials injected by proxies or service meshes.
REFLECTED_HEADERS = {"x-correlation-id", "user-agent"}


def build_user_agent() -> str:
    """<package name>/<build number> (<commit hash>)"""
    return f"{PACKAGE_NAME}/{BUILD_NUMBER} ({COMMIT_SHA})"


USER_AGENT = build_user_agent()


@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "pod": os.environ.get("HOSTNAME", socket.gethostname()),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }), 200


@app.route("/")
def index():
    return jsonify({
        "service": PACKAGE_NAME,
        "version": "1.0.0",
        "environment": os.environ.get("ENVIRONMENT", "local"),
        "greeting": os.environ.get("GREETING", "Comtrya!"),
        "pod": os.environ.get("POD_NAME", socket.gethostname()),
    }), 200


@app.route("/version")
def version():
    """Build provenance - the same metadata carried in outbound User-Agent."""
    return jsonify({
        "package": PACKAGE_NAME,
        "build_number": BUILD_NUMBER,
        "commit_sha": COMMIT_SHA,
        "user_agent": USER_AGENT,
        "pod": os.environ.get("HOSTNAME", socket.gethostname()),
    }), 200


@app.route("/echo")
def echo():
    """Downstream service stub - reflects the headers it was sent."""
    correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))

    received = {
        key: value
        for key, value in request.headers.items()
        if key.lower() in REFLECTED_HEADERS
    }

    return jsonify({
        "correlation_id": correlation_id,
        "received_user_agent": request.headers.get("User-Agent"),
        "received_headers": received,
        "pod": os.environ.get("HOSTNAME", socket.gethostname()),
    }), 200


@app.route("/dial-out")
def dial_out():
    """
    Makes an outbound call carrying the instrumented User-Agent,
    proving the provenance header propagates on egress.

    The target is constrained to a relative path from an allowlist.
    Absolute URLs are rejected - see ALLOWED_TARGETS.
    """
    target_path = request.args.get("target", "/echo")

    if target_path not in ALLOWED_TARGETS:
        return jsonify({
            "error": "target not permitted",
            "allowed_targets": sorted(ALLOWED_TARGETS),
        }), 400

    target = f"{SELF_BASE_URL}{target_path}"

    try:
        resp = requests.get(
            target,
            headers={"User-Agent": USER_AGENT},
            timeout=5,
        )
        resp.raise_for_status()
    except requests.RequestException as exc:
        return jsonify({
            "sent_user_agent": USER_AGENT,
            "target": target,
            "error": f"upstream call failed: {type(exc).__name__}",
        }), 502

    return jsonify({
        "sent_user_agent": USER_AGENT,
        "target": target,
        "response": resp.json(),
    }), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)