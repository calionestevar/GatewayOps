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
    """Downstream service stub - reflects headers it receives."""
    correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))
    return jsonify({
        "correlation_id": correlation_id,
        "received_user_agent": request.headers.get("User-Agent"),
        "received_headers": dict(request.headers),
        "pod": os.environ.get("HOSTNAME", socket.gethostname()),
    }), 200


@app.route("/dial-out")
def dial_out():
    """
    Makes an outbound call carrying the instrumented User-Agent.
    Defaults to calling this service's own /echo endpoint, so the
    propagation can be verified hermetically - no external dependency.
    """
    target = request.args.get("target", "http://localhost:5000/echo")
    resp = requests.get(
        target,
        headers={"User-Agent": USER_AGENT},
        timeout=5,
    )
    return jsonify({
        "sent_user_agent": USER_AGENT,
        "target": target,
        "response": resp.json(),
    }), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)