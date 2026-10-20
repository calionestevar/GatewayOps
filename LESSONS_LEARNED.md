# Lessons Learned: Gateway Ops Journey

This document captures real failures encountered while building Gateway Ops, ordered chronologically. Each entry includes the symptom, root cause, and fix—along with the diagnostic insight that made the difference.

---

## 1. PowerShell Multiline Command Escaping

**Symptom:** `docker build` failed with `'docker buildx build' requires 1 argument`

```powershell
docker build \
  --build-arg PACKAGE_NAME=gateway-ops \
  ...
```

**Error:** `ERROR: docker: 'docker buildx build' requires 1 argument`

**Root Cause:** PowerShell uses backtick (`) for line continuation , not backslash (\). When I used backslashes, PowerShell treated the first line as complete with no arguments.

**Fix:** Replaced all backslashes with backticks:

```powershell
docker build `
  --build-arg PACKAGE_NAME=gateway-ops `
  --build-arg BUILD_NUMBER=42 `
  --t gateway-ops-app:v1.0.0 .
```

**Takeaway:** Shell syntax matters. Even "universal" tools have platform-specific invocation quirks. When writing documentation or scripts, specify the shell upfront (bash, pwsh, git-bash).

## 2. Kubernetes Namespace Ordering Failure

**Symptom:** `Error from server (NotFound): namespaces "sgc" not found`

Applied manifests in alphabetical order:

dhd-config.yaml       ← d
gate-deployment.yaml  ← g
gate-service.yaml     ← g
sgc-namespace.yaml    ← s  ← applied LAST

Every namespaced resource submitted before the namespace it targeted existed.

**Root Cause:** `kubectl apply -f k8s/` processes files alphabetically, not by dependency.

**Fixes (both work):**

1. **Explicit ordering:** Apply namespace first

```powershell
kubectl apply -f k8s/sgc-namespace.yaml
kubectl apply -f k8s/
```

2. **Kustomize:** Restructured into `k8s/base/` and `k8s/overlays/` with explicit `resources:` list ordering

```powershell
resources:
  - sgc-namespace.yaml
  - dhd-config.yaml
  - gate-deployment.yaml
  - gate-service.yaml
```

Then `kubectl apply -k k8s/overlays/ci/`

**Takeaway:** Dependency ordering is a real concern, not just nice-to-have. Kustomize solves this declaratively rather than requiring manual sequencing.

## 3. Kustomize CRD Not Available in Kind

**Symptom:** `error: resource mapping not found for name: "" namespace: "" from "k8s\\kustomization.yaml": no matches for kind "Kustomization"`

**Root Cause:** Older Kind images (pre-Kubernetes 1.25) don't include the Kustomize CRD by default. The command `kubectl apply -k k8s/` requires `kustomize.config.k8s.io/v1beta1` CRD registration.

**Fixes:**

1. **Recreate cluster with newer image:**

```bash
kind delete cluster --name gateway-ops
kind create cluster --name gateway-ops  # Pulls latest kindest/node
```

2. **Fall back to explicit ordering:** Use `kubectl apply -f` with manual namespace-first step

**Takeaway:** Local dev environment versions matter. "Works on my machine" breaks when the machine has an older Kind image than expected. Document minimum versions explicitly.

## 4. GitHub Actions Artifact Sharing Between `workflow_run` Triggers

**Symptom:** `Error: Unable to download artifact(s): Artifact not found for name: gateway-ops-image-2`

ZPM Build published an artifact; Prometheus Launch couldn't retrieve it despite being triggered by the same workflow run.

**Root Cause:** GitHub Actions `workflow_run` triggers **don't inherit artifacts** from the triggering run. Each run has its own artifact namespace, even when spawned by another.

**Fix:** Changed strategy from artifact handoff to **container registry handoff:**

- ZPM Build: Push image to GHCR (GitHub Container Registry)
- Prometheus Launch: Pull image from GHCR

**Tradeoff:** Registry tags (by run number or SHA) decouple build from deploy. Artifacts expire after 90 days and are scoped per-run; images persist until deleted.

**Takeaway:** When sharing build artifacts across CI stages, prefer container registries over GitHub artifacts for cross-workflow communication.

## 5. Base/Overlays Restructure Broke Workflow Expectations

**Symptom:** `Missing kustomization file 'kustomization.yaml'` + `sed: can't read gate-deployment.yaml: No such file or directory`

Refactored manifests from flat `k8s/` into `k8s/base/` and `k8s/overlays/` structure, but the workflow still pointed at `k8s/`.

**Root Cause:** The workflow's `cd k8s` assmed files lived directly in `k8s/`, not `k8s/base/`. The `sed` fallback tried to edit a file that didn't exist at the expected path.

**Fix:** Updated workflow references to `k8s/overlays/ci/`:

```yaml
- name: Patch image tag for CI deploy
  run: |
    cd k8s/overlays/ci
    kustomize edit set image gateway-ops-app=${{ env.IMAGE_NAME }}:${{ github.event.workflow_run.run_number }}
```

**Takeaway:** Infrastructure restructures break automation silently. The `sed` fallback masked the real error by failing on the wrong assumption. Always log intermediate state (`cat kustomization.yaml` after edits).

## 6. Smoke Tests Asserted Raw JSON Whitespace

**Symptom:** SGC Smoke Tests failed on `/health` and `/` endpoints, but `/version` and `/echo` passed against the same pod.

```bash
{"greeting":"Comtrya!"}  # actual (compact)
{"greeting": "Comtrya!"} # asserted (spaced)
```

**Root Cause:** Assertions matched literal strings (`grep -q '"greeting": "Comtrya!"'`) against compact JSON output. Flask serializes without spaces after colons. `jq` parsers work correctly because they're structural, not byte-matching.

**Fix:** Replaced all raw-string matching with `jq` field extraction:

```bash
GREETING=$(curl -sf "#{BASE_URL}/" | jq -r '.greeting // ""')
if [ "$GREETING" == "Comtrya!" ]; then pass "greeting verified"; fi
```

**Diagnosis Insight:** Half-the-tests-passed pattern ruled out infrastructure immediately. If ConfigMap or port mapping were broken, every test would fail. Partial failure across a shared resource means the tests disagree with each other, not with the system.

**Secondary Lesson:** The original failure message guessed at a cause ("check dhd-config ConfigMap") and sent debugging in the wrong direction. Assertions should report **observed values**, not hypothesized causes.

## Design Patterns Emerged

1. **Declarative over imperative:** Kustomize `images:` stanza beats `sed` regex replacements
2. **Parse, never grep:** Structured data must be parsed, not matched on raw bytes
3. **One suite, two entry points:** Shared smoke script runs identical in CI and locally
4. **Registry handoff beats artifact handoff:** Cross-workflow sharing via container registries, not GitHub artifacts
5. **Base/overlays structure:** Environment variance lives in overlays, base stays stable