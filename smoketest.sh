#!/bin/bash
set -euo pipefail

TASK="${1:-tasks/odh-operator-3475}"
JOBS_DIR="jobs/smoketest"

echo "Harbor smoketest: ${TASK}"
echo "Jobs dir: ${JOBS_DIR}"
echo ""

harbor run \
    -p "${TASK}" \
    -a oracle \
    --jobs-dir "${JOBS_DIR}" \
    --n-concurrent 1 \
    --job-name smoketest

echo ""
echo "Results in ${JOBS_DIR}/"

# Push to EvalHub/MLflow via HarborAdapter (import mode)
if python3 -c "from agent_eval.harbor.adapter import HarborAdapter" 2>/dev/null; then
    echo ""
    echo "Pushing results to EvalHub/MLflow..."
    python3 -c "
from agent_eval.harbor.adapter import HarborAdapter
from agent_eval.evalhub.stubs import JobSpec, JobCallbacks, ModelConfig

adapter = HarborAdapter(
    task_path='${TASK}',
    jobs_dir='${JOBS_DIR}',
)

spec = JobSpec(
    id='smoketest',
    provider_id='harbor-bench',
    benchmark_id='harbor-task',
    model=ModelConfig(name='oracle'),
    parameters={'agent': 'oracle', 'task_path': '${TASK}'},
    experiment_name='harbor-rhoai',
)

callbacks = JobCallbacks()
results = adapter.run_benchmark_job(spec, callbacks)

print(f'  Trials: {results.num_examples_evaluated}')
print(f'  Overall score: {results.overall_score}')
for r in results.results:
    print(f'    {r.metric_name}: {r.metric_value}')

try:
    rid = callbacks.mlflow.save(results, spec)
    if rid:
        results.mlflow_run_id = rid
        print(f'  MLflow run: {rid}')
    else:
        print('  MLflow: save returned None (stubs mode — install evalhub SDK for real persistence)')
except Exception as e:
    print(f'  MLflow save failed (non-fatal): {e}')
"
else
    echo ""
    echo "agent-eval-harness not installed, skipping EvalHub push"
    echo "  Install: pip install -e ~/repos/agent-eval-harness"
fi
