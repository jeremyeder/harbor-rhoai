# Refactoring Recommendations

Issues found during e2e flow review, prioritized by impact.

## P1 — Do First

### Secret/ConfigMap manifests

The `gcp-vertex-sa` secret and `claude-otel-config` ConfigMap were created ad-hoc via `oc create`. No manifest files exist — if the namespace is wiped, they must be manually recreated from memory. Create declarative YAML templates under `deploy/k8s/` with placeholder values and a setup script.

### Capture test output as MLflow artifact

Pod logs are read by the adapter but only the `HARBOR_REWARD=` line is extracted. The full test output (which tests passed/failed, compiler errors, Claude Code's implementation summary) is discarded when the Job is deleted. Persist `stdout` as an MLflow artifact so failed runs can be debugged without re-running.

The `run_task_job()` return already includes `stdout` — the adapter just doesn't save it.

### Partial reward scoring

`test.sh` gives reward=1 (all pass) or reward=0 (any failure). A partial reward would be far more informative for model comparison. For example:

- Regression tests pass: +0.5
- New test functions found: +0.25
- New tests pass: +0.25

Or: `reward = (tests_passed / tests_total)` across both stages. This lets you see that Model A got 0.8 and Model B got 0.3, instead of both getting 0.

## P2 — Important

### Centralize cluster config

Registry URL, EvalHub base URL, and MLflow URI are hardcoded in `build-tasks.sh`, job YAMLs, and the ConfigMap. A single `cluster.env` file sourced by all scripts would eliminate the URL sprawl and make it possible to target a different cluster.

### Image versioning

Images use only `:latest`, `:oracle`, `:agent` tags. No way to roll back or correlate a benchmark run with the exact image that produced it. Tag with `git rev-parse --short HEAD` in addition to the semantic tags.

### Slim down agent image

The agent image installs the full `mlflow` package (~200+ deps) just for one Stop hook function. Options:
- Use `mlflow[skinny]` (fewer deps, still has the hooks module — verify)
- Extract just `mlflow.claude_code.hooks` and its transitive imports as a vendored module
- Accept the size and move on (it only affects build time, not runtime)

## P3 — Nice to Have

### Templatize agent script

`k8s_runner._agent_script()` generates a bash script via Python f-string with escaped JSON inside a heredoc. This is fragile and hard to test. Options:
- Move the script to a file mounted via ConfigMap
- Use a Jinja2 template
- At minimum, extract the settings.json creation into a separate function

### Integrate provider build

`build-tasks.sh` only builds task images. The provider image (`harbor-bench-provider`) is built separately from the agent-eval-harness worktree via manual `docker build`. Either add a `--provider` flag to `build-tasks.sh` or create a parallel `build-provider.sh`.

### Docker login check

The oc token-based docker login expires silently after ~24h. `build-tasks.sh` proceeds to build, then fails only at push time. Add a `docker login` check at the start of the script, or re-authenticate automatically using `oc whoami -t`.

## Summary

| # | Issue | Priority | Impact | Effort |
|---|-------|----------|--------|--------|
| 2 | Secret/ConfigMap manifests | P1 | Reproducibility | Low |
| 9 | Capture test output in MLflow | P1 | Debuggability | Low |
| 8 | Partial reward scoring | P1 | Benchmark quality | Medium |
| 1 | Centralize cluster config | P2 | Maintainability | Low |
| 5 | Image versioning | P2 | Reproducibility | Low |
| 4 | Slim down agent image | P2 | Build speed | Medium |
| 7 | Templatize agent script | P3 | Code quality | Medium |
| 6 | Integrate provider build | P3 | DX | Medium |
| 10 | Docker login check | P3 | Robustness | Low |
