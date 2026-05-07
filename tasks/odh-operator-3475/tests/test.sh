#!/bin/bash
set -o pipefail
cd /app

mkdir -p /logs/verifier
REWARD=1

# Stage 1: Regression check — run all tests in affected packages
echo "=== Stage 1: Regression check ==="
go test -count=1 -v \
    ./pkg/controller/precondition/... \
    ./pkg/controller/reconciler/... \
    ./pkg/controller/actions/dependency/certmanager/... \
    2>&1 | tee /logs/verifier/stage1_regression.txt
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Stage 1 FAILED: regression detected"
    REWARD=0
fi

# Stage 2: Feature verification — confirm precondition test functions exist and pass
echo "=== Stage 2: Feature verification ==="
STAGE2_OUTPUT=$(go test -count=1 -v -run "TestPreCondition|TestMonitorCRD|TestRunAll" \
    ./pkg/controller/precondition/... \
    ./pkg/controller/reconciler/... 2>&1)
STAGE2_EXIT=$?
echo "$STAGE2_OUTPUT" | tee /logs/verifier/stage2_feature.txt
if [ $STAGE2_EXIT -ne 0 ]; then
    echo "Stage 2 FAILED: new tests failing"
    REWARD=0
elif echo "$STAGE2_OUTPUT" | grep -q "no tests to run"; then
    echo "Stage 2 FAILED: new test functions not found"
    REWARD=0
fi

echo $REWARD > /logs/verifier/reward.txt
echo "Final reward: $REWARD"
