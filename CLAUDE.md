# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Harbor benchmark dataset for evaluating agentic coding on real-world Red Hat OpenShift AI operator tasks. 3 tasks derived from merged PRs in opendatahub-io/opendatahub-operator. Each task presents the codebase at the state just before a PR was merged, with instructions describing what to build or fix. Measures **value-per-token (VPT)** — the ratio of evaluation score to tokens consumed.

## Commands

```bash
# Local smoketest (runs oracle agent against a task via Docker)
./smoketest.sh tasks/odh-operator-3290

# Build task images for K8s execution (must be linux/amd64)
./build-tasks.sh odh-operator-3290
./build-tasks.sh --push                    # all tasks, push to cluster registry
./build-tasks.sh --push odh-operator-3290  # single task, push

# Run via EvalHub on cluster
evalhub --base-url https://evalhub-evalhub.apps.rosa.jeder-evalhub.uqi3.p3.openshiftapps.com \
  --token $(oc whoami -t) eval run --config evalhub-smoketest-job.yaml
```

## Architecture

### Task Structure

Each task under `tasks/<name>/` follows the Harbor task format:
- `task.toml` — Harbor config (timeouts, resource limits, metadata, source PR reference)
- `instruction.md` — Problem statement given to the agent
- `environment/Dockerfile` — UBI9-minimal + Go 1.26, repo checked out at pre-PR state
- `solution/solve.sh` + `pr-NNNN.patch` — Oracle solution (applies the actual PR diff)
- `tests/test.sh` — Two-stage verification: regression check (existing tests) then feature verification (new tests from PR)

### Image Layering (K8s Execution)

Three image types built from each task, layered via `--build-arg BASE_IMAGE`:

1. **Base** (`Dockerfile` in `environment/`) — Go toolchain + repo source at pre-PR state
2. **Oracle** (`Dockerfile.k8s-task`) — Adds solution + tests on top of base
3. **Agent** (`Dockerfile.agent-task`) — Adds Claude Code CLI + instruction + tests on top of base (no solution)

### EvalHub Integration

EvalHub job configs (`evalhub-*.yaml`) define benchmark runs. The HarborAdapter in `agent-eval-harness` repo orchestrates K8s Jobs using these pre-built images. Results flow: K8s Job → pod logs → EvalHub sidecar → MLflow.

The adapter code lives in a separate repo: `~/repos/agent-eval-harness` (branch `feat/harbor-provider`).

### Execution Modes

- **Local** (`harbor run`): Docker-based, uses Harbor CLI directly
- **K8s oracle** (`evalhub-smoketest-job.yaml`): Pre-built oracle image runs solve.sh + test.sh as a Job
- **K8s agent** (`evalhub-agent-job.yaml`): Agent image with Claude Code CLI, needs GCP Vertex AI secret for model access

## Cluster Context

Target cluster is `jeder-evalhub` (ROSA HCP). Task images push to the internal OpenShift registry at `image-registry.openshift-image-registry.svc:5000/evalhub/`. The Kyverno policy `rewrite-eval-runtime-sidecar` works around EvalHub EA2's hardcoded unqualified sidecar image reference.

## Conventions

- Task images MUST be built with `--platform linux/amd64` (handled by `build-tasks.sh`)
- Task names match the source PR number: `odh-operator-NNNN`
- Local job output goes to `jobs/` (gitignored)
- Use `docker` (not `podman`) and `uv` (not `pip`)


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:7510c1e2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
