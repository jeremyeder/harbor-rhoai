# Session Handoff: harbor-rhoai

**Date:** 2026-05-13
**Author:** Claude Code (Opus 4.6)

## Summary

Extended Harbor/EvalHub integration with real agent support (Claude Code via Vertex AI), secret volume mounts, and agent mode validation. Filed 2 upstream EvalHub bugs. CodeRabbit review clean. Ready for commits and PRs.

## Uncommitted Changes

### harbor-rhoai (`fix/session-gaps` branch)

| File | Change |
|---|---|
| `Dockerfile.agent-task` | Copies instruction.md + tests/ (not solution/), sets HOME=/tmp for writable config |
| `evalhub-agent-job.yaml` | Vertex AI URL, env_from_secrets + secret_volumes for gcp-vertex-sa |
| `docs/execution-flow-comparison.md` | NEW — Mermaid diagrams comparing Harbor native vs K8s runner flows |
| `docs/evalhub-issues-draft.md` | NEW — Draft text for filed upstream issues |

5 prior commits on branch (from previous session), 2 files uncommitted.

### agent-eval-harness (`feat/harbor-provider` branch)

Worktree: `~/repos/agent-eval-harness/.claude/worktrees/feat+harbor-provider/`

| File | Change |
|---|---|
| `agent_eval/harbor/k8s_runner.py` | Agent mode (_oracle_script/_agent_script), secret volume mounts (_build_volumes), agent validation, shlex.quote for model, malformed reward handling |
| `agent_eval/harbor/adapter.py` | Passes agent/model/secret_volumes to runner, mean_reward None warning |
| `tests/test_harbor_adapter.py` | 9 new tests: TestAgentMode (5), TestSecretVolumes (4) — 33 total, all passing |
| `pyproject.toml` | Added `harbor` optional dependency group |

6 prior commits on branch (from previous session), 4 files uncommitted.

## Upstream Issues Filed

- **eval-hub/eval-hub#574** — Sidecar image hardcoded as unqualified `eval-runtime-sidecar:latest`
- **eval-hub/eval-hub#575** — `providers list` crashes on empty `pass_criteria`

## Open Beads

| Bead | P | Status | Title |
|---|---|---|---|
| AEH-khe | P1 | open | PR harbor-rhoai and agent-eval-harness harbor provider changes |
| AEH-7m2 | P1 | open | EvalHub EA2 hardcodes unqualified sidecar image (filed as #574) |
| AEH-l5k | P2 | open | EvalHub providers list crashes (filed as #575) |
| AEH-3vi | P2 | open | Extend harbor-bench provider to support Ambient Code Platform |
| AEH-4hy | P3 | open | Create EvalHub provider scaffold for new benchmark adapters |
| AEH-98q | — | CLOSED | Extend Harbor to support K8s Jobs (delivered via k8s_runner.py) |

## Next Session Focus: AEH-4hy then AEH-3vi

### AEH-4hy: EvalHub Provider Scaffold

**Goal:** Extract a reusable scaffold from the harbor-bench provider so new benchmark providers can be created quickly.

**What exists today (harbor-bench as the reference implementation):**

```
agent_eval/harbor/
├── __init__.py
├── adapter.py          # HarborAdapter(FrameworkAdapter) — 3 modes: harbor, k8s, import
├── k8s_runner.py       # K8s Job lifecycle (create, poll, collect, cleanup)
└── results_parser.py   # Parse Harbor JSON → EvalHub metrics

deploy/harbor/
├── Containerfile       # UBI9 provider image
├── entrypoint.py       # Container entrypoint
├── provider.yaml       # EvalHub provider spec (benchmarks, metrics, runtime)
├── configmap-template.yaml
└── generate-configmap.sh

tests/
└── test_harbor_adapter.py  # 33 unit tests
```

**The scaffold should generate for a new provider `<name>`:**

1. `agent_eval/<name>/__init__.py`
2. `agent_eval/<name>/adapter.py` — with `<Name>Adapter(FrameworkAdapter)` skeleton, `run_benchmark_job()` with mode dispatch
3. `agent_eval/<name>/results_parser.py` — skeleton for parsing benchmark-specific results
4. `deploy/<name>/Containerfile` — UBI9 base, pip install
5. `deploy/<name>/entrypoint.py` — with experiment name warning pattern
6. `deploy/<name>/provider.yaml` — with placeholder benchmarks, metrics, runtime config
7. `deploy/<name>/generate-configmap.sh`
8. `tests/test_<name>_adapter.py` — test skeleton using the mock patterns from harbor tests

**Key patterns to preserve:**
- `FrameworkAdapter` base class from `agent_eval.evalhub.types`
- `_framework_adapter_init()` wrapper (avoids import failure when SDK not installed)
- Conditional SDK imports via `agent_eval/evalhub/types.py`
- `_report_status()` callback pattern
- `EvaluationResult` metric mapping
- `_setup_k8s_mocks()` test helper pattern

**Implementation approach:** A script or CLI command (`python -m agent_eval scaffold <name>`) that creates the directory structure and fills in templates. NOT a cookiecutter/copier dependency — just string templates in Python.

### AEH-3vi: Ambient Code Platform Integration

**Goal:** Let Ambient Code Platform run Harbor benchmark tasks and push results to EvalHub/MLflow.

**What the bead says:** "Ambient handles Docker-based execution; results are pushed to EvalHub/MLflow post-session. Investigate using EvalHub local runtime mode."

**The provider.yaml already has local mode:**
```yaml
runtime:
  local:
    command: python3 deploy/harbor/entrypoint.py
```

**The adapter already has import mode** (`_import_results()`) that parses pre-existing Harbor results without running Harbor.

**Likely approach:**
1. Ambient runs `harbor run -p tasks/foo -a claude-code` (Docker-based, local)
2. Results land in `jobs/` directory as `result.json` + trial subdirectories
3. A post-run script calls the adapter in import mode to push to EvalHub/MLflow
4. Or: Ambient calls `evalhub eval run` with a local-mode config that uses the import path

**Platform repo:** `~/repos/platform` — investigate how Ambient dispatches benchmark runs and where results land.

**Dependencies:** The scaffold (AEH-4hy) should be done first so the Ambient integration can follow the established provider pattern if it needs a separate provider, or extend harbor-bench if it's just a new execution mode.

## Key Commands

```bash
# Run tests (agent-eval-harness)
cd ~/repos/agent-eval-harness/.claude/worktrees/feat+harbor-provider
python -m pytest tests/test_harbor_adapter.py -v

# Local smoketest (harbor-rhoai)
./smoketest.sh tasks/odh-operator-3290

# Build task images
./build-tasks.sh odh-operator-3290

# CodeRabbit review
coderabbit review --agent --base main        # harbor-rhoai
coderabbit review --agent --type committed   # agent-eval-harness
```

## Cluster State: jeder-evalhub

- **API:** `https://api.jeder-evalhub.uqi3.p3.openshiftapps.com:443`
- **EvalHub:** Running, harbor-bench provider loaded
- **MLflow:** Running, harbor-rhoai experiment has 1 run (oracle, reward=1.0)
- **Kyverno policy:** `rewrite-eval-runtime-sidecar` active (workaround for #574)
- **Task images:** OLD (built as root). Need rebuild+push with `./build-tasks.sh --push`
- **gcp-vertex-sa secret:** NOT YET CREATED
- **Still broken:** RHOAI dashboard, notebooks, kserve (stale catalog source)

## Context for Resumption

- The `feat/harbor-provider` worktree is at `~/repos/agent-eval-harness/.claude/worktrees/feat+harbor-provider/`
- agent-eval-harness installed in dev mode: `uv pip install -e .` from the worktree
- The `kubernetes` Python package is installed in the venv at `~/repos/.venv/`
- Memory files at `~/.claude/projects/-Users-jeder-repos-harbor-rhoai/memory/`
- GCP SA key for Vertex AI: `~/.config/gcloud/jeder-sa-kind.json` (project: gcp-jboyer-san-gemini, region: us-east5)
- Task images MUST be built with `--platform linux/amd64` — `build-tasks.sh` handles this
- Full session report at `docs/session-report-2026-05-12.md`
- Execution flow comparison at `docs/execution-flow-comparison.md`
