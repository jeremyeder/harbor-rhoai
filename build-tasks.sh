#!/bin/bash
set -euo pipefail

REGISTRY="${REGISTRY:-default-route-openshift-image-registry.apps.rosa.jeder-evalhub.uqi3.p3.openshiftapps.com}"
NAMESPACE="${NAMESPACE:-evalhub}"
PLATFORM="${PLATFORM:-linux/amd64}"
PUSH="${PUSH:-false}"
TAG="${TAG:-latest}"
ORACLE_TAG="${ORACLE_TAG:-oracle}"

usage() {
    cat <<'USAGE'
Usage: $0 [OPTIONS] [TASK...]

Build Harbor task images for Kubernetes execution.

Arguments:
  TASK    One or more task directory names (e.g. odh-operator-3290).
          If none specified, builds all tasks under tasks/.

Options:
  --push          Push images to registry after building
  --registry URL  Override registry (default: $REGISTRY or cluster internal)
  --tag TAG       Base image tag (default: latest)
  --oracle-tag T  Oracle overlay tag (default: oracle)
  -h, --help      Show this help

Environment:
  REGISTRY    Registry URL
  NAMESPACE   Image namespace (default: evalhub)
  PLATFORM    Build platform (default: linux/amd64)
  PUSH        Set to "true" to push (same as --push)

Examples:
  ./build-tasks.sh odh-operator-3290
  ./build-tasks.sh --push
  ./build-tasks.sh --push odh-operator-3290 odh-operator-3475
USAGE
    exit 0
}

TASKS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --push) PUSH="true"; shift ;;
        --registry) REGISTRY="$2"; shift 2 ;;
        --tag) TAG="$2"; shift 2 ;;
        --oracle-tag) ORACLE_TAG="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) TASKS+=("$1"); shift ;;
    esac
done

if [ ${#TASKS[@]} -eq 0 ]; then
    for d in tasks/*/; do
        name=$(basename "$d")
        if [ -f "$d/environment/Dockerfile" ]; then
            TASKS+=("$name")
        fi
    done
fi

if [ ${#TASKS[@]} -eq 0 ]; then
    echo "No tasks found under tasks/" >&2
    exit 1
fi

echo "Registry:  ${REGISTRY}"
echo "Namespace: ${NAMESPACE}"
echo "Platform:  ${PLATFORM}"
echo "Push:      ${PUSH}"
echo "Tasks:     ${TASKS[*]}"
echo ""

FAILED=()
for task in "${TASKS[@]}"; do
    task_dir="tasks/${task}"
    if [ ! -f "${task_dir}/environment/Dockerfile" ]; then
        echo "SKIP: ${task} — no environment/Dockerfile"
        continue
    fi

    base_image="${REGISTRY}/${NAMESPACE}/harbor-task-${task}:${TAG}"
    oracle_image="${REGISTRY}/${NAMESPACE}/harbor-task-${task}:${ORACLE_TAG}"

    echo "=== Building ${task} ==="

    echo "  Base image: ${base_image}"
    if ! docker build --provenance=false --sbom=false --platform "${PLATFORM}" \
        -t "${base_image}" \
        -f "${task_dir}/environment/Dockerfile" "${task_dir}/environment/"; then
        echo "  FAILED: base image build"
        FAILED+=("${task}:base")
        continue
    fi

    echo "  Oracle image: ${oracle_image}"
    if ! docker build --provenance=false --sbom=false --platform "${PLATFORM}" \
        --build-arg "BASE_IMAGE=${base_image}" \
        -t "${oracle_image}" \
        -f Dockerfile.k8s-task "${task_dir}/"; then
        echo "  FAILED: oracle image build"
        FAILED+=("${task}:oracle")
        continue
    fi

    if [ "${PUSH}" = "true" ]; then
        echo "  Pushing ${base_image}..."
        docker push "${base_image}" || FAILED+=("${task}:push-base")
        echo "  Pushing ${oracle_image}..."
        docker push "${oracle_image}" || FAILED+=("${task}:push-oracle")
    fi

    if [ -f "Dockerfile.agent-task" ]; then
        agent_image="${REGISTRY}/${NAMESPACE}/harbor-task-${task}:agent"
        echo "  Agent image: ${agent_image}"
        if ! docker build --provenance=false --sbom=false --platform "${PLATFORM}" \
            --build-arg "BASE_IMAGE=${base_image}" \
            -t "${agent_image}" \
            -f Dockerfile.agent-task "${task_dir}/"; then
            echo "  WARNING: agent image build failed (non-fatal)"
        elif [ "${PUSH}" = "true" ]; then
            echo "  Pushing ${agent_image}..."
            docker push "${agent_image}" || echo "  WARNING: agent image push failed"
        fi
    fi

    echo "  Done: ${task}"
    echo ""
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "FAILURES:"
    for f in "${FAILED[@]}"; do
        echo "  - ${f}"
    done
    exit 1
fi

echo "All tasks built successfully."
