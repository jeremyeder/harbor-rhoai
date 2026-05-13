# harbor-rhoai: Session Report — 2026-05-12

## What We Built

A benchmark dataset for evaluating agentic coding tools on real-world Kubernetes operator tasks, with full integration into Red Hat's EvalHub/MLflow evaluation infrastructure.

**Starting point:** 5 tasks derived from merged PRs in the opendatahub-operator, designed to measure value-per-token (VPT) across different coding agents.

**What we added:** End-to-end pipeline from Harbor benchmark execution → EvalHub → MLflow, running natively on Kubernetes without Docker-in-Docker. Then fixed 9 gaps/sharp edges from the initial implementation.

## Architecture Flows

### Flow 1: Local Development (Docker)

```
Developer laptop
┌─────────────────────────────────────────────┐
│                                             │
│  ./smoketest.sh tasks/odh-operator-3290     │
│       │                                     │
│       ▼                                     │
│  harbor run -p tasks/... -a oracle          │
│       │                                     │
│       ├── Docker build (UBI9 + Go + repo)   │
│       ├── Apply PR patch (solve.sh)         │
│       ├── Run tests (test.sh)               │
│       │    ├── Stage 1: regression check    │
│       │    └── Stage 2: feature verify      │
│       └── reward.txt → result.json          │
│                                             │
│  Output: jobs/smoketest/result.json         │
│  (local files only, no MLflow)              │
└─────────────────────────────────────────────┘
```

### Flow 2: Kubernetes via EvalHub → MLflow (Production)

```
                        evalhub eval run --config job.yaml
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────┐
│  EvalHub Server (evalhub namespace)                          │
│                                                              │
│  Accepts job → creates provider pod                          │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Provider Pod (2 containers)                           │  │
│  │                                                        │  │
│  │  ┌─────────────────┐    ┌───────────────────────────┐  │  │
│  │  │  adapter         │    │  sidecar (EvalHub)        │  │  │
│  │  │  (Python)        │    │  (Go binary)              │  │  │
│  │  │                  │    │                           │  │  │
│  │  │  HarborAdapter   │    │  callbacks.mlflow.save() │  │  │
│  │  │  ._run_k8s()    │───▶│  callbacks.report_results│  │  │
│  │  │       │          │    │       │                   │  │  │
│  │  └───────┼──────────┘    └───────┼───────────────────┘  │  │
│  │          │                       │                      │  │
│  └──────────┼───────────────────────┼──────────────────────┘  │
│             │                       │                          │
│             ▼                       ▼                          │
│  ┌──────────────────┐    ┌─────────────────────────────────┐  │
│  │  K8s Job          │    │  MLflow (redhat-ods-apps)       │  │
│  │  (task workload)  │    │                                 │  │
│  │                   │    │  Experiment: harbor-rhoai        │  │
│  │  Pre-built image  │    │  Run: reward=1.0                │  │
│  │  ├── solve.sh     │    │  Metrics: duration, reward, ... │  │
│  │  ├── test.sh      │    │                                 │  │
│  │  └── reward=1.0   │    │  Visible in RHOAI Dashboard     │  │
│  └──────────────────┘    └─────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Flow 3: Import Mode (parse existing results)

```
  Harbor ran elsewhere        HarborAdapter
  (Ambient, CI, local)       (import mode)
         │                        │
         ▼                        ▼
  jobs/smoketest/         jobs_dir parameter
  └── result.json    ──▶  _import_results()
  └── trial/              parse_job()
      └── result.json  ──▶  JobResults
                              │
                              ▼
                        callbacks.mlflow.save()
```

## Task Detail: odh-operator-3290

**Source:** [PR #3290](https://github.com/opendatahub-io/opendatahub-operator/pull/3290) — Wire GC action into CCM pipeline

The Cloud Configuration Manager (CCM) reconciliation pipeline had no garbage collection step. When resources were no longer part of the desired state, stale and orphaned resources remained indefinitely. The task requires building a CCM-specific GC predicate (using `InstanceUID`/`InstanceGeneration` annotations), a GC action that accepts operator namespace explicitly, protected resource support, and wiring it into both Azure and CoreWeave controller pipelines.

```
┌─────────────────────────────────────────────────────────┐
│              CCM Reconciliation Pipeline                │
│                                                         │
│  ┌──────────┐   ┌──────────┐   ┌──────────────────────┐ │
│  │  Deploy  │──▶│  Hooks   │──▶│  GC Action (NEW)     │ │
│  │  Action  │   │          │   │                      │ │
│  └──────────┘   └──────────┘   │  ┌────────────────┐  │ │
│       │                        │  │  GC Predicate   │  │ │
│       │ stamps resources       │  │  (NEW)          │  │ │
│       │ with InstanceUID +     │  │                 │  │ │
│       │ InstanceGeneration     │  │  Compares:      │  │ │
│       ▼                        │  │  • InstanceUID  │  │ │
│  ┌──────────┐                  │  │  • Generation   │  │ │
│  │ Cluster  │◀── collects ────▶│  └────────────────┘  │ │
│  │Resources │    stale objs    │                      │ │
│  │          │    (mismatch)    │  Skips:              │ │
│  │ ✅ current│                  │  • Protected objects │ │
│  │ ❌ stale  │◀── deletes      │  • Namespaces        │ │
│  └──────────┘                  └──────────────────────┘ │
│                                                         │
│  Applied to: Azure AKS + CoreWeave controllers          │
└─────────────────────────────────────────────────────────┘
```

## What's Proven

| Milestone | Status | Evidence |
|---|---|---|
| Harbor oracle on Docker (local) | DONE | 3290 + 3475 reward=1.0 |
| HarborAdapter → EvalHub JobResults | DONE | 24 unit tests passing |
| K8s Job on OCP (no Docker) | DONE | reward=1.0 via k8s_runner |
| EvalHub provider registered | DONE | `harbor-bench` in provider list |
| `evalhub eval run` end-to-end | DONE | Job completed, score=1.0 |
| Results in MLflow | DONE | Run `545ce39c...` in harbor-rhoai experiment |
| MLflow UI visible | DONE | Evaluations tab in RHOAI dashboard |
| Non-root containers (UID 1001) | DONE | All 3 task Dockerfiles + Dockerfile.k8s-task |
| Configurable runAsUser | DONE | k8s_runner defaults to 1001, overridable |
| Pinned provider image versions | DONE | Containerfile pins base image + kubernetes pkg |
| ConfigMap generated from provider.yaml | DONE | generate-configmap.sh eliminates duplication |
| Experiment name validation | DONE | WARNING logged when missing |
| Build automation | DONE | build-tasks.sh handles all tasks + platform flag |
| Batch mode | DONE | evalhub-batch-job.yaml runs all 3 tasks |
| Real agent support | DONE | Dockerfile.agent-task + env_from_secrets |

## Remaining Gaps

### Blocking real use

1. **Real agent not yet tested end-to-end.** The infrastructure is in place (Dockerfile.agent-task, env_from_secrets, evalhub-agent-job.yaml), but no actual claude-code run has been executed on the cluster. Needs: cluster auth, API key secret created, agent image built+pushed.

2. **Task images not rebuilt.** The Dockerfiles were updated for non-root but images haven't been pushed to the cluster registry yet. Run `./build-tasks.sh --push` after authenticating.

### EvalHub/cluster issues

3. **EvalHub EA2 sidecar bug (AEH-7m2).** Hardcoded unqualified `eval-runtime-sidecar:latest` — requires Kyverno workaround (already deployed).

4. **Stale RHOAI catalog images.** Widespread `ImagePullBackOff` across the cluster. Dashboard, notebooks, kserve, model serving all down.

5. **EvalHub SDK bug (AEH-l5k).** `providers list` crashes on malformed `pass_criteria.threshold`.

### Architecture

6. **Harbor doesn't support K8s natively (AEH-98q).** We bypassed Harbor's execution layer entirely. Upstream has related issues (#1516 Argo, #1522 sidecars). Contributing a K8s Jobs backend would make this cleaner.

7. **No Ambient Code Platform integration (AEH-3vi).** The adapter supports import mode for post-hoc result pushing, but no automated pipeline from Ambient → EvalHub.

8. **No VPT (value-per-token) metric.** The benchmark is designed to measure VPT but we only log reward and duration. Token counts and cost are null for oracle, and not yet wired for real agents.

## Building a Larger Task Corpus

The current 3 tasks (3290, 3343, 3475) come from opendatahub-operator PRs. Here's how to scale:

### Source: More opendatahub-operator PRs

The operator has ~200 merged PRs per release cycle. Good candidates:
- PRs that add new features with tests (not refactors or docs)
- PRs with clear before/after state (single commit or squash-merged)
- PRs touching self-contained packages (not cross-cutting changes)

**Process:**
1. Pick a merged PR
2. Find the parent commit (pre-PR state)
3. Extract the diff as a patch
4. Identify affected test packages
5. Write `instruction.md` describing the task without revealing the solution
6. Create `task.toml`, `Dockerfile`, `solve.sh`, `test.sh`

### Source: Other RHOAI operators

Same pattern applies to any Go/K8s operator:
- `opendatahub-io/kserve` — model serving
- `opendatahub-io/model-registry` — model registry
- `opendatahub-io/trustyai-explainability` — TrustyAI
- `opendatahub-io/data-science-pipelines-operator` — pipelines

### Source: Non-Go codebases

Harbor tasks aren't Go-specific. Any codebase with a Dockerfile + test suite works:
- Python ML packages (pytest-based verification)
- TypeScript/React frontends (jest/vitest)
- Rust crates (cargo test)

### Scaling automation

For building the corpus at scale:
1. **PR scraper** — scan GitHub for merged PRs with test additions, filter by diff size (500-2000 lines is the sweet spot)
2. **Task generator** — given a PR URL, auto-generate the task structure (checkout parent, extract patch, identify test packages, write instruction.md draft)
3. **Quality filter** — run oracle to verify the task is solvable, run without the patch to verify it's not trivially passing
4. **Difficulty calibration** — run with multiple agents/models to estimate difficulty before publishing

The Harbor framework has `harbor check` for task quality rubrics — use that to validate generated tasks before adding them to the dataset.

## Open Beads

| Bead | Priority | Title |
|---|---|---|
| AEH-khe | P1 | PR harbor-rhoai and agent-eval-harness harbor provider changes |
| AEH-98q | P1 | Extend Harbor to support Kubernetes Jobs as execution backend |
| AEH-7m2 | P1 | EvalHub EA2 hardcodes unqualified sidecar image |
| AEH-3vi | P2 | Extend harbor-bench provider to support Ambient Code Platform |
| AEH-l5k | P2 | EvalHub providers list crashes: malformed pass_criteria |
| AEH-4hy | P3 | Create EvalHub provider scaffold for new benchmark adapters |

## Code Locations

### agent-eval-harness (feat/harbor-provider branch)

| File | Purpose |
|---|---|
| `agent_eval/harbor/__init__.py` | Package init |
| `agent_eval/harbor/adapter.py` | `HarborAdapter(FrameworkAdapter)` — harbor, k8s, import modes |
| `agent_eval/harbor/results_parser.py` | Parse Harbor JSON → EvalHub metrics |
| `agent_eval/harbor/k8s_runner.py` | Run tasks as K8s Jobs (configurable runAsUser, env_from_secrets) |
| `agent_eval/evalhub/types.py` | Centralized conditional SDK imports |
| `deploy/harbor/entrypoint.py` | Container entrypoint (warns on missing experiment name) |
| `deploy/harbor/Containerfile` | UBI9 provider image (pinned base + kubernetes versions) |
| `deploy/harbor/provider.yaml` | EvalHub provider spec (authoritative source) |
| `deploy/harbor/configmap-template.yaml` | K8s ConfigMap (auto-generated from provider.yaml) |
| `deploy/harbor/generate-configmap.sh` | Script to regenerate ConfigMap from provider.yaml |
| `tests/test_harbor_adapter.py` | 24 unit tests |

### harbor-rhoai (fix/session-gaps branch)

| File | Purpose |
|---|---|
| `smoketest.sh` | Local Harbor run + EvalHub adapter import |
| `build-tasks.sh` | Automated multi-arch task image builds (base + oracle + agent) |
| `Dockerfile.k8s-task` | Overlay Dockerfile for baking solution+tests (non-root, UID 1001) |
| `Dockerfile.agent-task` | Overlay Dockerfile adding Claude Code CLI for real agent runs |
| `evalhub-smoketest-job.yaml` | EvalHub job config (single task, oracle) |
| `evalhub-batch-job.yaml` | EvalHub job config (all 3 tasks, oracle) |
| `evalhub-agent-job.yaml` | EvalHub job config (single task, claude-code agent) |
| `tasks/odh-operator-*/environment/Dockerfile` | Task environment images (non-root, UID 1001) |
| `docs/session-report-2026-05-12.md` | This report |

## Cluster Details

- **Cluster:** `jeder-evalhub` (ROSA HCP)
- **RHOAI:** 3.4.0-ea.2
- **EvalHub:** `https://evalhub-evalhub.apps.rosa.jeder-evalhub.uqi3.p3.openshiftapps.com`
- **MLflow UI:** `https://rh-ai.apps.rosa.jeder-evalhub.uqi3.p3.openshiftapps.com/mlflow/` → harbor-rhoai → Evaluations
- **MLflow run:** `545ce39c3d7644f6a40f1221b6ba74af` (reward=1.0, 130.6s)

## Issues Fixed This Session

| Issue | Commit (harbor-rhoai) | Commit (eval-harness) |
|---|---|---|
| Sharp Edge 1: anyuid SCC required | `a3b126f` | — |
| Sharp Edge 2: runAsUser hardcoded | — | `4e45e02` |
| Sharp Edge 3: unpinned versions | — | `d80be9d` |
| Sharp Edge 4: ConfigMap duplication | — | `4cc8bc3` |
| Sharp Edge 6: silent MLflow skip | — | `b8fb2ca` |
| Sharp Edge 7: arch mismatch | `1f2fb94` | — |
| Gap 1: no real agent | `3788be9` | `50d3b79` |
| Gap 2: single-task only | `72ae4c4` | — |
| Gap 3: manual image builds | `1f2fb94` | — |
| Cleanup: unused imports, test DRY | — | `bd84f27` |
| Housekeeping: .gitignore | `f9f06e9` | — |
