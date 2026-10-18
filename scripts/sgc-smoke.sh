#!/usr/bin/env bash
# sgc-smoke.sh
# SGC = Stargate Command (SG-1). Post-deployment checkpoint:
# verify safe arrival on the other side of the wormhole before
# reporting success. Exits non-zero on ANY failure.

set -euo pipefail

# --- Configuration ---
BASE_URL="${BASE_URL:-http://localhost:8080}"
EXPECTED_BUILD="${EXPECTED_BUILD:-}"   # Optional: assert specific build number
FAILURES=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "=== SGC Smoke Tests - targeting ${BASE_URL} ==="

# --- Test 1: Health endpoint ---
if curl -sf "${BASE_URL}/health" | grep -q '"status": "healthy"'; then
  pass "health endpoint responsive"
else
  fail "health endpoint not responsive"
fi

# --- Test 2: Comtrya handshake (Altairan greeting via ConfigMap) ---
if curl -sf "${BASE_URL}/" | grep -q '"greeting": "Comtrya!"'; then
  pass "Comtrya handshake verified (dhd-config ConfigMap wiring intact)"
else
  fail "greeting missing - check dhd-config ConfigMap"
fi

# --- Test 3: Build provenance survived deployment ---
VERSION_RESPONSE=$(curl -sf "${BASE_URL}/version" || echo "")
if [ -n "$VERSION_RESPONSE" ]; then
  BUILD_NUM=$(echo "$VERSION_RESPONSE" | jq -r '.build_number')
  if [ -n "$BUILD_NUM" ] && [ "$BUILD_NUM" != "local" ] && [ "$BUILD_NUM" != "null" ]; then
    pass "provenance present (build ${BUILD_NUM})"
  else
    fail "provenance lost in deployment"
  fi

  # --- Test 3b: Assert expected build number when provided ---
  if [ -n "$EXPECTED_BUILD" ] && [ "${BUILD_NUM:-}" != "$EXPECTED_BUILD" ]; then
    fail "build number mismatch: expected ${EXPECTED_BUILD}, got ${BUILD_NUM}"
  else
    [ -n "$EXPECTED_BUILD" ] && pass "deployed build matches expected (${EXPECTED_BUILD})"
  fi

  # --- Test 4: User-Agent instrumentation format ---
  # Contract: <package name>/<build number> (<commit hash>)
  UA=$(echo "$VERSION_RESPONSE" | jq -r '.user_agent')
  if echo "$UA" | grep -qE '^gateway-ops/[0-9a-zA-Z]+ \([0-9a-f]{7,40}\)$'; then
    pass "User-Agent format matches instrumentation contract (${UA})"
  else
    fail "User-Agent malformed: ${UA}"
  fi
else
  fail "/version endpoint unreachable"
fi

# --- Test 5: Correlation-ID propagation ---
CORR=$(curl -sf -H "X-Correlation-ID: sgc-smoke-$$" "${BASE_URL}/echo" 2>/dev/null | jq -r '.correlation_id' || echo "")
if [ "$CORR" == "sgc-smoke-$$" ]; then
  pass "correlation ID propagates end-to-end"
else
  fail "correlation ID dropped"
fi

# --- Summary ---
echo ""
echo "=== SGC Results: $((FAILURES == 0 ? 1 : 0))-line summary ==="
if [ "$FAILURES" -ne 0 ]; then
  echo "::error::${FAILURES} smoke test(s) failed - unscheduled offworld activation"
  exit 1
fi

echo "All SGC smoke tests passed. Comtrya - safe arrival confirmed."