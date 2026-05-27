# harbor-rhoai

Harbor benchmark dataset for evaluating agentic coding on real-world Red Hat OpenShift AI operator tasks.

## Overview

3 tasks derived from merged PRs in [opendatahub-io/opendatahub-operator](https://github.com/opendatahub-io/opendatahub-operator). Each task presents the codebase at the state just before the PR was merged, with instructions describing what needs to be built or fixed.

Designed for measuring **value-per-token (VPT)** — the ratio of evaluation score to tokens consumed — across different coding agents and models.

## Tasks

| Task | Source PR | Difficulty | Lines | Description |
|------|-----------|------------|-------|-------------|
| `odh-operator-3475` | [#3475](https://github.com/opendatahub-io/opendatahub-operator/pull/3475) | Medium | 1,117 | Add WithPreCondition to reconciler builder |
| `odh-operator-3343` | [#3343](https://github.com/opendatahub-io/opendatahub-operator/pull/3343) | Medium | 895 | Report failed ImageStream tag imports |
| `odh-operator-3290` | [#3290](https://github.com/opendatahub-io/opendatahub-operator/pull/3290) | Medium | 1,255 | Wire GC action into CCM pipeline |

## Usage

```bash
# Run a single task with the oracle (solution) agent
harbor run -p tasks/odh-operator-3290 -a oracle

# Run with a real agent
harbor run -p tasks/odh-operator-3290 -a claude-code -m anthropic/claude-sonnet-4-6

# Run all tasks
harbor run -p tasks/ -a claude-code -m anthropic/claude-sonnet-4-6
```

## Task Structure

Each task follows the Harbor task format:

```
tasks/odh-operator-NNNN/
├── task.toml              # Harbor configuration and metadata
├── instruction.md         # Problem statement for the agent
├── environment/
│   └── Dockerfile         # UBI9-minimal + Go 1.26, repo at pre-PR state
├── solution/
│   ├── solve.sh           # Applies the PR diff (oracle solution)
│   └── pr-NNNN.patch      # The actual PR diff
└── tests/
    └── test.sh            # Two-stage verification (regression + feature)
```

## Verification

Each task uses two-stage verification:

1. **Stage 1 — Regression check**: Runs all tests in affected packages to ensure the agent's changes don't break existing functionality
2. **Stage 2 — Feature verification**: Runs only the specific test functions introduced by the PR to confirm the feature was actually implemented

Both stages must pass for reward = 1.

## Environment

All tasks use UBI9-minimal base images with Go 1.26.3, targeting the opendatahub-operator codebase (Go/Kubernetes operator).
