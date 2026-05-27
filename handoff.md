# Session Handoff: harbor-rhoai → agent-eval-harness

**Date:** 2026-05-27
**Author:** Claude Code (Opus 4.6)

## Summary

This session was a strategic pivot. Started with cleanup of harbor-rhoai uncommitted changes, discovered that `rhai-datasets` supersedes harbor-rhoai's task authoring, reviewed agent-eval-harness PR #30 (merged EvalHub provider), filed 6 bugs from the review, then shifted focus entirely to agent-eval-harness for the **Model Picker** initiative: sweeping model/config variants across RFE Creator skill evaluations, scoring against a baseline, and comparing in MLflow dashboards.

## Key Decision

**harbor-rhoai is being archived.** Its roles are split:
- **Task generation** → `rhai-datasets` (already has harbor factory)
- **Build/runtime infra** → `agent-eval-harness` (future migration)
- **3 worked-example tasks** → `rhai-datasets/examples/` (future migration)

**The real work is now in agent-eval-harness.** Next session should `cd ~/repos/agent-eval-harness`.

## What Was Done This Session

1. Reviewed harbor-rhoai uncommitted changes (README, handoff, cluster-changes.md, .gitignore)
2. Updated .gitignore to exclude local artifacts — **NOT YET COMMITTED**
3. Reviewed [PR #30](https://github.com/opendatahub-io/agent-eval-harness/pull/30) (already merged, approved by @astefanutti)
4. Created 6 bug-fix beads in agent-eval-harness from PR #30 review
5. Created 6 future-work beads for the Model Picker initiative
6. Read the [Model Picker Google Doc](https://docs.google.com/document/d/1CgSJeIgXE9w3bVMq46BDL2-w1uUVPkB1ORJt46eNCgw) — full factorial sweep matrix (6 axes, 15+ configs)
7. Read [agentskills.io eval docs](https://agentskills.io/skill-creation/evaluating-skills) — with/without skill comparison pattern, marketplace concepts

## Uncommitted Changes (harbor-rhoai)

| File | Change |
|---|---|
| `.gitignore` | Added .DS_Store, .claude/mlflow/, docs/plans/, docs/superpowers/, stop-hook/ |
| `README.md` | Fixed task count 5→3, removed deleted tasks, updated examples |
| `handoff.md` | This file |
| `docs/cluster-changes.md` | NEW — cluster setup runbook for jeder-evalhub (decided to commit) |

## Beads Created (agent-eval-harness)

### PR #30 Bug Fixes

| ID | P | Title |
|---|---|---|
| SWP-9cu | P1 | Add timeout protection to direct LLM mode |
| SWP-lcj | P2 | Fix aggregate exit code logic in EvalHub adapter |
| SWP-atg | P2 | Surface judge scoring failures in results |
| SWP-g25 | P2 | Handle non-text LLM response content blocks |
| SWP-l6z | P3 | Validate case inputs upfront before execution loop |
| SWP-m4z | P3 | Prevent judge metric name collisions with built-in metrics |

### Model Picker Initiative

| ID | P | Title |
|---|---|---|
| SWP-bf7 | P1 | Run baseline RFE Creator eval through EvalHub |
| SWP-yrg | P2 | Design skill marketplace packaging abstraction |
| SWP-0li | P2 | Build sweep orchestrator for parametric model evaluation |
| SWP-xp1 | P3 | Add multi-runner support for non-Claude LLMs |
| SWP-kho | P3 | Add with/without skill comparison mode |
| SWP-nim | P3 | Build comparative scorecard from MLflow sweep results |

## Next Session: Get the Baseline Run (SWP-bf7)

**Repo:** `~/repos/agent-eval-harness` (main branch, PR #30 already merged)

**Goal:** Run RFE Creator eval through EvalHub on jeder-evalhub cluster, get scored results in MLflow. This is the prerequisite for all sweep/comparison work.

### Steps

1. **Build provider image:**
   ```bash
   docker build --platform linux/amd64 -f deploy/evalhub/Containerfile -t agent-eval-provider:latest .
   ```

2. **Push to cluster registry:**
   ```bash
   REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')
   docker login $REGISTRY
   docker tag agent-eval-provider:latest $REGISTRY/evalhub/agent-eval-provider:latest
   docker push $REGISTRY/evalhub/agent-eval-provider:latest
   ```

3. **Register provider** (if not already done from PR #30 dev):
   ```bash
   oc apply -f deploy/evalhub/configmap-template.yaml
   # Add agent-eval to EvalHub CR spec.providers[] if needed
   ```

4. **Create Vertex AI secret** (if not already done):
   ```bash
   oc create secret generic gcp-vertex-sa \
     --from-file=sa-key.json=$HOME/.config/gcloud/jeder-sa-kind.json \
     --from-literal=CLAUDE_CODE_USE_VERTEX=1 \
     --from-literal=ANTHROPIC_VERTEX_PROJECT_ID=gcp-jboyer-san-gemini \
     --from-literal=CLOUD_ML_REGION=us-east5 \
     --from-literal=GOOGLE_APPLICATION_CREDENTIALS=/secrets/gcp/sa-key.json \
     -n evalhub
   ```

5. **Submit job:**
   ```bash
   evalhub --base-url https://evalhub-evalhub.apps.rosa.jeder-evalhub.uqi3.p3.openshiftapps.com \
     --token $(oc whoami -t) eval run --config deploy/evalhub/evalhub-job.yaml
   ```

6. **Verify in MLflow:** Check that the run appears with judge scores and metrics.

### What the provider already has baked in

- RFE assess rubric at `deploy/evalhub/rfe-assess/rubric.md`
- Test case RHAIRFE-2048 at `deploy/evalhub/rfe-assess/cases/RHAIRFE-2048/input.yaml`
- 5 judges: has_scoring_table, has_verdict, has_feedback, scores_valid, rubric_score
- Direct LLM mode (no Claude Code CLI needed for rubric-based assessment)

## Architecture Context

**The full vision (Model Picker doc):**

Sweep orchestrator submits EvalHub jobs for each config in a matrix:
- Planner model + tuning (Sonnet/Opus/Haiku, base/RL-tuned)
- Planner context window
- Planner thinking (default/ITS/extended)
- Judge model + tuning
- Judge context window
- Agent (skill variant from marketplace)

All runs land in one MLflow experiment for comparison dashboards. Start small (single-axis model sweep), build confidence, expand to full factorial.

**Marketplace concept:** Skills packaged as installable units, swappable in eval runtimes. Even a single skill goes through the marketplace. Open question: portability to non-Claude LLMs (skills use Claude Code-specific features).

## Cluster State: jeder-evalhub

- **API:** `https://api.jeder-evalhub.uqi3.p3.openshiftapps.com:443`
- **EvalHub:** Running, harbor-bench provider loaded (agent-eval provider may need re-registration after PR #30 merge)
- **MLflow:** Running
- **Kyverno policy:** `rewrite-eval-runtime-sidecar` active (workaround for upstream #574)
- **gcp-vertex-sa secret:** Status unknown — check with `oc get secret gcp-vertex-sa -n evalhub`

## Key References

- [Model Picker Google Doc](https://docs.google.com/document/d/1CgSJeIgXE9w3bVMq46BDL2-w1uUVPkB1ORJt46eNCgw)
- [agentskills.io eval docs](https://agentskills.io/skill-creation/evaluating-skills)
- [PR #30](https://github.com/opendatahub-io/agent-eval-harness/pull/30) — merged EvalHub provider
- [EvalHub architecture spec](https://github.com/opendatahub-io/architecture-context/blob/main/architecture/rhoai-3.4/eval-hub.md)
- Plan file: `~/.claude/plans/thinking-out-loud-1-graceful-kay.md`
