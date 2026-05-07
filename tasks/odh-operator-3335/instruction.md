# Fix DataScienceCluster ComponentsReady Status During Deletion

## Problem

The `DataScienceCluster` (DSC) custom resource incorrectly reports `ComponentsReady: True` even when component CRs are stuck in deletion — for example, when finalizers or other blocking conditions prevent a component from being fully removed.

This causes misleading status for cluster administrators and any automated systems that rely on DSC readiness to make decisions.

## Root Causes

There are two independent bugs that combine to produce this behavior:

1. **Aggregation logic bug**: The function that computes the overall `ComponentsReady` condition from individual component statuses only treats an explicit "False" condition as not-ready. If a component reports an "Unknown" status (which is what happens during deletion), the aggregation logic incorrectly treats it as ready.

2. **Component handler bug**: When a component CR has a `deletionTimestamp` set (meaning Kubernetes is trying to delete it), the component's status update method returns an "Unknown" condition instead of explicitly reporting that the component is not ready. This affects all component handlers in the operator.

## Expected Behavior

- When any component CR has a `deletionTimestamp`, the DSC should report `ComponentsReady: False`
- The aggregation logic should treat any status that is NOT explicitly "True" as not-ready
- This applies to all managed components: Dashboard, DataSciencePipelines, FeastOperator, KServe, Kueue, LlamaStackOperator, MLFlowOperator, ModelController, ModelRegistry, ModelsAsService, Ray, SparkOperator, Trainer, TrainingOperator, TrustyAI, and Workbenches

## Testing Requirements

- Unit tests for the aggregation logic fix, covering:
  - Components with "Unknown" status are treated as not-ready
  - Disabled-but-stuck components are surfaced correctly
  - The no-managed-components edge case
- Unit tests for the component handler deletion scenario, verifying that handlers return a "False" (not "Unknown") condition when the CR has a `deletionTimestamp`
- Tests should cover at least a few representative component handlers (not necessarily all 16, but enough to validate the pattern)

## Constraints

- The codegen template for future components should also be updated to include the deletion check
- Existing automation that expects `True` during deletion was relying on buggy behavior — the fix is intentionally a behavior change
