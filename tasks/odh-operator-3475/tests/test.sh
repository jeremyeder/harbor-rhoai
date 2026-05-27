#!/bin/bash
set -o pipefail
cd /app

mkdir -p /logs/verifier
REWARD=1
TEST_PACKAGES="./pkg/controller/precondition/... ./pkg/controller/reconciler/... ./pkg/controller/actions/dependency/certmanager/..."

# Run all tests in affected packages
echo "=== Running tests ==="
go test -count=1 -v \
    $TEST_PACKAGES \
    2>&1 | tee /logs/verifier/test_output.txt
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "FAILED: tests did not pass"
    REWARD=0
fi

# Verify new test functions were added
echo "=== Checking for new test functions ==="
CURRENT_TESTS=$(go test -list '.*' $TEST_PACKAGES 2>/dev/null | grep '^Test' | sort)
BASELINE_TESTS=$(cat /tests/baseline-tests.txt 2>/dev/null | sort)
NEW_TESTS=$(comm -23 <(echo "$CURRENT_TESTS") <(echo "$BASELINE_TESTS"))
NEW_COUNT=$(echo "$NEW_TESTS" | grep -c '^Test' || true)

echo "Baseline test functions: $(echo "$BASELINE_TESTS" | grep -c '^Test' || true)"
echo "Current test functions:  $(echo "$CURRENT_TESTS" | grep -c '^Test' || true)"
echo "New test functions:      $NEW_COUNT"

if [ "$NEW_COUNT" -eq 0 ]; then
    echo "FAILED: no new test functions found"
    REWARD=0
else
    echo "New test functions:"
    echo "$NEW_TESTS"
fi

echo $REWARD > /logs/verifier/reward.txt
echo "Final reward: $REWARD"
