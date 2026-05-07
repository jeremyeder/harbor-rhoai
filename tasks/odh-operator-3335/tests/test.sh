#!/bin/bash
set -o pipefail
cd /app

mkdir -p /logs/verifier
REWARD=1

# Stage 1: Regression check — run all tests in affected packages
echo "=== Stage 1: Regression check ==="
go test -count=1 -v \
    ./internal/controller/components/dashboard/... \
    ./internal/controller/components/datasciencepipelines/... \
    ./internal/controller/components/feastoperator/... \
    ./internal/controller/components/kserve/... \
    ./internal/controller/components/kueue/... \
    ./internal/controller/components/llamastackoperator/... \
    ./internal/controller/components/mlflowoperator/... \
    ./internal/controller/components/modelcontroller/... \
    ./internal/controller/components/modelregistry/... \
    ./internal/controller/components/modelsasservice/... \
    ./internal/controller/components/ray/... \
    ./internal/controller/components/sparkoperator/... \
    ./internal/controller/components/trainer/... \
    ./internal/controller/components/trainingoperator/... \
    ./internal/controller/components/trustyai/... \
    ./internal/controller/components/workbenches/... \
    ./internal/controller/datasciencecluster/... \
    2>&1 | tee /logs/verifier/stage1_regression.txt
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Stage 1 FAILED: regression detected"
    REWARD=0
fi

# Stage 2: Feature verification — confirm new test functions exist and pass
echo "=== Stage 2: Feature verification ==="
go test -count=1 -v -run "TestComputeComponentsStatus|TestUpdateDSCStatus.*Delet" \
    ./internal/controller/components/dashboard/... \
    ./internal/controller/components/kserve/... \
    ./internal/controller/components/modelcontroller/... \
    ./internal/controller/datasciencecluster/... \
    2>&1 | tee /logs/verifier/stage2_feature.txt
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Stage 2 FAILED: new tests missing or failing"
    REWARD=0
fi

echo $REWARD > /logs/verifier/reward.txt
echo "Final reward: $REWARD"
