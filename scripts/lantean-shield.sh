#!/usr/bin/env bash
# lantean-shield.sh
# Atlantis's gate shield (Ancient energy barrier) - stricter than the Iris.
# The Iris inspects source files; the Lantean shield inspects RENDERED
# manifests, which is what actually reaches the cluster.
#
# Includes a "backdoor audit": the shield verifies the pipeline still
# invokes it. McKay's hidden override worked because nobody audited the
# gate itself.
#
# Prerequisites: kubectl, yq (v4+), jq
#
# Env vars:
#   OVERLAY     - Path to kustomize overlay (default: k8s/overlays/ci)
#   ALLOWED_REGISTRIES - Approved image registry prefix (default: ghcr.io/)
#   DEBUG       - Set to "1" for verbose diagnostic output

set -euo pipefail

OVERLAY="${OVERLAY:-k8s/overlays/ci}"
ALLOWED_REGISTRIES="${ALLOWED_REGISTRIES:-ghcr.io/}"
FAILURES=0
DEBUG="${DEBUG:-0}" # Set DEBUG=1 for verbose output

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES + 1)); }
require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "::error::missing prerequisite '$1' - install it or run in CI"
    exit 2
  }
}

require kubectl
require yq
require jq

echo "=== Lantean Shield - inspecting rendered manifests from ${OVERLAY} ==="

if [ "$DEBUG" == "1" ]; then
  echo "[DEBUG] Rendering kustomization..."
fi

if ! RENDERED=$(kubectl kustomize "$OVERLAY" 2>&1); then
  echo "::error::kustomize render failed:"
  echo "$RENDERED"
  exit 2
fi

if [ "$DEBUG" == "1" ]; then
  echo "[DEBUG] Rendered YAML (first 50 lines):"
  echo "$RENDERED" | head -50 | sed 's/^/[YAML] /'
fi

# Convert YAML to JSON stream
JSON=$(echo "$RENDERED" | yq -o=json '.')

if [ "$DEBUG" == "1" ]; then
  echo "[DEBUG] JSON conversion successful"
  echo "[DEBUG] Deployment container securityContext:"
  echo "$JSON" | jq -r 'select(.kind=="Deployment") | .spec.template.spec.containers[] | "\(.name): allowPrivilegeEscalation=\(.securityContext.allowPrivilegeEscalation // "NULL")"' | sed 's/^/[JSON] /'
fi

# Define the workload selector (Deployment, StatefulSet, DaemonSet)
WORKLOAD='select(.kind | test("^(Deployment|StatefulSet|DaemonSet)$"))'

# --- 1: No floating :latest tags ---
LATEST=$(echo "$JSON" | jq -r "$WORKLOAD | .spec.template.spec.containers[]
  | select(.image | endswith(\":latest\")) | .image")
if [ -z "$LATEST" ]; then pass "no floating ':latest' image tags"
else fail "floating ':latest' tag(s): ${LATEST}"; fi

# --- 2: Images come from approved registries ---
BAD_REG=$(echo "$JSON" | jq -r --arg allowed "$ALLOWED_REGISTRIES" "$WORKLOAD
  | .spec.template.spec.containers[]
  | select(.image | startswith(\$allowed) | not) | .image")
if [ -z "$BAD_REG" ]; then pass "all images from approved registry (${ALLOWED_REGISTRIES})"
else fail "image(s) outside approved registry: ${BAD_REG}"; fi

# --- 3: No privileged containers ---
PRIV=$(echo "$JSON" | jq -r "$WORKLOAD | .spec.template.spec.containers[]
  | select(.securityContext.privileged == true) | .name")
if [ -z "$PRIV" ]; then pass "no privileged containers"
else fail "privileged container(s): ${PRIV}"; fi

# --- 4: Pod-level runAsNonRoot ---
NOT_ROOT=$(echo "$JSON" | jq -r "$WORKLOAD
  | select((.spec.template.spec.securityContext.runAsNonRoot // false) != true)
  | .metadata.name")
if [ -z "$NOT_ROOT" ]; then pass "all workloads declare runAsNonRoot: true"
else fail "missing runAsNonRoot: ${NOT_ROOT}"; fi

# --- 5: Privilege escalation disabled ---
if [ "$DEBUG" == "1" ]; then
  echo "[DEBUG] Checking allowPrivilegeEscalation..."
  echo "[DEBUG] Container specs:"
  echo "$JSON" | jq -r "$WORKLOAD"' | .spec.template.spec.containers[]
    | "\(.name): allowPrivilegeEscalation=\(.securityContext.allowPrivilegeEscalation)"' \
    2>&1 || echo "[DEBUG] jq extraction failed"
fi

# NOTE: do NOT use jq's alternative operator (//) here. jq treats BOTH
# null and false as "empty", so `false // true` evaluates to `true`,
# collapsing a correctly-set false into the fallback value. Compare
# directly against false: an absent field yields null, which is
# != false and therefore correctly flagged as a violation.
ESC=$(echo "$JSON" | jq -r "$WORKLOAD | .spec.template.spec.containers[]
  | select(.securityContext.allowPrivilegeEscalation != false) | .name")

if [ "$DEBUG" == "1" ]; then
  echo "[DEBUG] ESC variable content: '$ESC'"
  if [ -n "$ESC" ]; then
    echo "[DEBUG] Containers with privilege escalation: ${ESC}"
  else
    echo "[DEBUG] No containers flagged for privilege escalation"
  fi
fi

if [ -z "$ESC" ]; then pass "allowPrivilegeEscalation disabled on all containers"
else fail "privilege escalation permitted: ${ESC}"; fi

# --- 6: Read-only root filesystem ---
RW=$(echo "$JSON" | jq -r "$WORKLOAD | .spec.template.spec.containers[]
  | select((.securityContext.readOnlyRootFilesystem // false) != true) | .name")
if [ -z "$RW" ]; then pass "root filesystem read-only on all containers"
else fail "writable root filesystem: ${RW}"; fi

# --- 7: All capabilities dropped ---
CAPS=$(echo "$JSON" | jq -r "$WORKLOAD | .spec.template.spec.containers[]
  | select(((.securityContext.capabilities.drop // []) | index(\"ALL\")) == null)
  | .name")
if [ -z "$CAPS" ]; then pass "capabilities dropped (ALL) on all containers"
else fail "capabilities not dropped: ${CAPS}"; fi

# --- 8: No hostPath volumes ---
HOSTPATH=$(echo "$JSON" | jq -r "$WORKLOAD
  | select([.spec.template.spec.volumes[]? | select(.hostPath != null)] | length > 0)
  | .metadata.name")
if [ -z "$HOSTPATH" ]; then pass "no hostPath volumes"
else fail "hostPath volume(s) in: ${HOSTPATH}"; fi

# --- 9: Resource limits on every container ---
NOLIMITS=$(echo "$JSON" | jq -r "$WORKLOAD | .spec.template.spec.containers[]
  | select(.resources.limits == null) | .name")
if [ -z "$NOLIMITS" ]; then pass "resource limits declared on all containers"
else fail "missing resource limits: ${NOLIMITS}"; fi

# --- 10: Probes on every container ---
NOPROBE=$(echo "$JSON" | jq -r "$WORKLOAD | .spec.template.spec.containers[]
  | select(.livenessProbe == null or .readinessProbe == null) | .name")
if [ -z "$NOPROBE" ]; then pass "liveness + readiness probes on all containers"
else fail "missing probes: ${NOPROBE}"; fi

# --- 11: NetworkPolicy present ---
NP=$(echo "$JSON" | jq -r 'select(.kind == "NetworkPolicy") | .metadata.name')
if [ -n "$NP" ]; then pass "NetworkPolicy declared: ${NP}"
else fail "no NetworkPolicy in rendered output"; fi

# --- 12: Backdoor audit - is the shield still wired into the pipeline? ---
WF=".github/workflows/prometheus-launch.yml"
if [ -f "$WF" ] && grep -q 'lantean-shield.sh' "$WF"; then
  pass "backdoor audit: shield is invoked by prometheus-launch.yml"
else
  fail "backdoor audit: shield NOT invoked by pipeline - gate may be bypassed"
fi

echo ""
if [ "$FAILURES" -ne 0 ]; then
  echo "=== Lantean Shield: ${FAILURES} violation(s) - barrier holds ==="
  echo "::error::${FAILURES} hardening violation(s) detected"
  exit 1
fi
echo "=== Lantean Shield: all checks passed - barrier intact ==="