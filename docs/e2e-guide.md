# Harbor Benchmark E2E Guide

## Complete Sequence

```
PREREQUISITES
  1. oc login to jeder-evalhub cluster
  2. docker login to cluster registry
  3. Secrets on cluster: gcp-vertex-sa (Vertex AI creds), claude-otel-config (MLflow tracing)

BUILD
  4. ./build-tasks.sh --push odh-operator-3290
     Builds 3 images per task: base (:latest), oracle (:oracle), agent (:agent)
       Base:   UBI9-minimal + Go 1.26 + repo at pre-PR commit
       Oracle: base + solution/solve.sh + tests/
       Agent:  base + Node.js + Claude Code CLI + Python 3.12 + mlflow + instruction.md + tests/
     All linux/amd64, pushed to internal registry

SUBMIT
  5. evalhub eval run --config evalhub-agent-job.yaml
     EvalHub creates provider pod (harbor-bench-provider image)
     Provider pod runs entrypoint.py which calls HarborAdapter._run_k8s()

EXECUTE
  6. Adapter creates K8s Job with agent task image
     Pod mounts gcp-vertex-sa secret (SA key file + env vars for Vertex AI)
     Pod injects claude-otel-config ConfigMap (MLflow tracing env vars)
  7. k8s_runner._agent_script() runs inside the pod:
     a. Creates $HOME/.claude/settings.json with MLflow Stop hook
     b. Runs: claude -p --dangerously-skip-permissions --model claude-sonnet-4-6
        "Read /app/instruction.md and implement the solution..."
     c. Claude Code reads instruction, explores codebase, implements solution,
        runs go test to verify, iterates until tests pass
  8. Claude Code exits, Stop hook fires:
     python3 mlflow.claude_code.hooks.stop_hook_handler()
     Reads session transcript, creates MLflow trace in harbor-rhoai experiment

VERIFY
  9. test.sh runs:
     a. go test on affected packages (regression + agent's new code)
     b. go test -list diffs against baseline-tests.txt (new test function check)
     c. Writes reward (0 or 1) to /logs/verifier/reward.txt
  10. Script emits HARBOR_REWARD=<value> to stdout

COLLECT
  11. Adapter polls K8s Job status until complete, reads pod logs
  12. Parses HARBOR_REWARD= line from stdout
  13. Creates EvaluationResult metrics (reward, duration, num_trials)
  14. EvalHub callbacks save metrics to MLflow experiment harbor-rhoai
  15. Adapter deletes the K8s Job (cleanup)

RESULT
  16. MLflow experiment harbor-rhoai contains:
      - Run with metrics: reward, duration_seconds, mean_reward, num_trials
      - Trace with spans: claude_code interaction, LLM requests, tool executions
```

## Quickstart

```bash
# Login
oc login https://api.jeder-evalhub.uqi3.p3.openshiftapps.com:443
docker login $(oc get route default-route -n openshift-image-registry \
  -o jsonpath='{.spec.host}') --username unused --password "$(oc whoami -t)"

# Build & push (first time or after task/Dockerfile changes)
./build-tasks.sh --push odh-operator-3290

# Oracle smoke-test (validates pipeline, ~3 min)
~/repos/.venv/bin/evalhub \
  --base-url https://evalhub-evalhub.apps.rosa.jeder-evalhub.uqi3.p3.openshiftapps.com \
  --token "$(oc whoami -t)" eval run --config evalhub-smoketest-job.yaml

# Agent run (~40 min, 2h timeout)
~/repos/.venv/bin/evalhub \
  --base-url https://evalhub-evalhub.apps.rosa.jeder-evalhub.uqi3.p3.openshiftapps.com \
  --token "$(oc whoami -t)" eval run --config evalhub-agent-job.yaml

# Monitor
oc get pods -n evalhub --watch

# Results — MLflow UI
# https://rh-ai.apps.rosa.jeder-evalhub.uqi3.p3.openshiftapps.com/mlflow/
# Experiment: harbor-rhoai (metrics + agent traces)

# Local smoke-test (Docker-based, no cluster needed)
./smoketest.sh tasks/odh-operator-3290
```

## Cluster Resources

| Resource | Namespace | Purpose |
|----------|-----------|---------|
| Secret `gcp-vertex-sa` | evalhub | Vertex AI OAuth2 creds + env vars |
| ConfigMap `claude-otel-config` | evalhub | MLflow tracing config for Claude Code |
| ConfigMap `evalhub-provider-harbor-bench` | redhat-ods-applications | Provider spec |
| ClusterPolicy `rewrite-eval-runtime-sidecar` | cluster | Kyverno workaround for EvalHub EA2 sidecar image |
| SCC `anyuid` | evalhub namespace | Task images need root for Go build cache |
