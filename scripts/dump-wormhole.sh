#!/usr/bin/env bash
# dump-wormhole.sh
# Collapses the wormhole: full teardown of local and/or cloud resources.
# Named for the emergency wormhole discharge - use when costs threaten
# to accumulate or when resetting the local environment.
#
# Modes:
#   local  (default) - delete Kind cluster + local containers
#   cloud           - terraform destroy (requires AWS backend configured)

set -euo pipefail

MODE="${1:-local}"

case "$MODE" in
  local)
    echo "=== Dumping local wormhole ==="
    docker rm -f gateway-ops-test 2>/dev/null || true
    kind delete cluster --name gateway-ops 2>/dev/null || \
      echo "No local cluster named gateway-ops found"
    echo "Local environment collapsed. Rebuild with:"
    echo "  kind create cluster --name gateway-ops && kind load docker-image gateway-ops-app:v1.0.0 --name gateway-ops && kubectl apply -k k8s/"
    ;;

  cloud)
    echo "=== Dumping cloud wormhole (terraform destroy) ==="
    if [ ! -d "infra" ]; then
      echo "No infra/ directory - nothing to destroy"
      exit 0
    fi
    # Safety: require explicit confirmation
    read -p "This destroys all AWS resources managed by this project. Type 'DESTROY' to confirm: " CONFIRM
    if [ "$CONFIRM" != "DESTROY" ]; then
      echo "Aborted. The gate remains open."
      exit 1
    fi
    terraform -chdir=infra destroy
    ;;

  *)
    echo "Usage: $0 [local|cloud]"
    echo "  local - teardown Kind cluster and local containers (default)"
    echo "  cloud - terraform destroy against AWS backend"
    exit 1
    ;;
esac