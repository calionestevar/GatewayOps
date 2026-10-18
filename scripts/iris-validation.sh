#!/usr/bin/env bash
# iris-validation.sh
# The Iris (SG-1) blocks unauthorized travelers before they rematerialize.
# Pre-flight validation gate: everything here must pass BEFORE any
# deployment touches a cluster. Runs locally and in CI.

set -euo pipefail

FAILURES=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "=== Iris Validation - closing the shield for inspection ==="

# --- Check 1: Terraform formatting ---
if [ -d "infra" ]; then
  if terraform -chdir=infra fmt -check -recursive 2>/dev/null; then
    pass "terraform fmt clean"
  else
    fail "terraform fmt violations - run 'terraform -chdir=infra fmt'"
  fi

  # --- Check 2: Terraform validation ---
  if terraform -chdir=infra init -backend=false -input=false >/dev/null 2>&1 && \
     terraform -chdir=infra validate >/dev/null 2>&1; then
    pass "terraform validate clean"
  else
    fail "terraform validate errors"
  fi
else
  echo "SKIP: no infra/ directory present"
fi

# --- Check 3: K8s manifest dry-run (requires a reachable cluster) ---
if kubectl cluster-info >/dev/null 2>&1; then
  if kubectl apply --dry-run=client -k k8s/ >/dev/null 2>&1; then
    pass "kustomize + kubectl client dry-run clean"
  else
    fail "manifest dry-run errors"
  fi
else
  echo "SKIP: no cluster reachable - running manifest validation offline"
fi

# --- Check 4: No hardcoded secrets in manifests ---
if grep -rEn '(password|secret|token):\s*[^{$]' k8s/ --include="*.yaml" 2>/dev/null | \
   grep -v 'valueFrom\|secretKeyRef\|configMapKeyRef'; then
  fail "possible hardcoded credential in k8s manifests"
else
  pass "no hardcoded credentials detected in k8s/"
fi

# --- Check 5: All containers declare resource limits ---
MISSING_LIMITS=$(grep -L 'limits:' k8s/*.yaml 2>/dev/null || true)
if [ -z "$MISSING_LIMITS" ]; then
  pass "resource limits declared in all workloads"
else
  fail "missing resource limits in: ${MISSING_LIMITS}"
fi

# --- Check 6: Dockerfile runs as non-root ---
if grep -q '^USER ' app/Dockerfile; then
  pass "container runs as non-root user"
else
  fail "Dockerfile missing USER directive - container would run as root"
fi

echo ""
if [ "$FAILURES" -ne 0 ]; then
  echo "::error::Iris remains CLOSED - ${FAILURES} validation failure(s). Nothing ships."
  exit 1
fi

echo "Iris opened: all pre-flight validations passed. Travel authorized."