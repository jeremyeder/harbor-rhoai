#!/bin/bash
set -o pipefail
cd /app

mkdir -p /logs/verifier
REWARD=1

# Stage 1: Regression check — run all tests in affected packages
echo "=== Stage 1: Regression check ==="
go test -count=1 -v \
    ./internal/controller/components/workbenches/... \
    ./pkg/controller/actions/status/imagestreams/... \
    2>&1 | tee /logs/verifier/stage1_regression.txt
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Stage 1 FAILED: regression detected"
    REWARD=0
fi

# Stage 2: Feature verification — confirm imagestream action test functions exist and pass
echo "=== Stage 2: Feature verification ==="
go test -count=1 -v -run "TestImageStreamsAvailable|TestAction" \
    ./pkg/controller/actions/status/imagestreams/... \
    2>&1 | tee /logs/verifier/stage2_feature.txt
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Stage 2 FAILED: new tests missing or failing"
    REWARD=0
fi

echo $REWARD > /logs/verifier/reward.txt
echo "Final reward: $REWARD"
