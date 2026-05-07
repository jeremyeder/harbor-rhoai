# Add PreCondition Framework to Reconciler Builder

## Problem

The operator's reconciler builder currently has no mechanism to run checks **before** the action reconciliation pipeline. Dependencies like CRD availability are verified using action-based patterns, which have several weaknesses:

- Actions can be silenced by earlier reconciliation steps failing, masking the dependency check
- Multiple dependencies targeting the same status condition require manual coordination
- There is no standard way for a failed dependency check to halt reconciliation with a clear user-facing message
- API errors during checks are not distinguished from actual missing dependencies

## Requirements

Design and implement a precondition framework for the reconciler builder:

1. **PreCondition type**: A struct that wraps a check function and produces a pass/fail/error result. Use the functional options pattern for configuration:
   - Condition type targeting (e.g., `DependenciesAvailable`)
   - Severity levels (`Error` affects readiness, `Info` is informational)
   - Halt control (whether a failed check should stop reconciliation)
   - Cluster type filtering (restrict checks to OpenShift or Kubernetes)
   - Custom user-facing messages for failed checks

2. **Aggregation**: Multiple preconditions targeting the same condition type should aggregate naturally — the condition is `True` only when all contributing checks pass. Errors (API failures) should set the condition to `Unknown`.

3. **Built-in check types**: Implement `MonitorCRD(gvk)` and `MonitorCRDs(gvks...)` that verify CRD presence using the cluster discovery API.

4. **Builder integration**: Add `WithPreCondition(...)` to the reconciler builder so preconditions are declared alongside actions.

5. **Migration**: Migrate the existing cert-manager CRD monitoring from its current action-based implementation to use the new precondition framework.

## Testing Requirements

- Unit tests for the precondition framework: pass/fail/error aggregation, severity handling, halt control, cluster type filtering
- Unit tests for the MonitorCRD check type
- Unit tests for the reconciler builder integration
- Verify the cert-manager migration produces equivalent behavior
