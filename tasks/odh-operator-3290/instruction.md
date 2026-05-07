# Wire Garbage Collection into CCM Pipeline

## Problem

The Cloud Configuration Manager (CCM) reconciliation pipeline has no garbage collection step. When resources are no longer part of the desired state (e.g., after a configuration change or when a dependency transitions to unmanaged), stale and orphaned resources remain in the cluster indefinitely.

The operator has an existing generic GC action, but two problems prevent directly reusing it in the CCM context:

1. **Namespace lookup failure**: The generic GC action uses a cluster initialization function to discover the operator namespace, but this initialization is never called in the CCM context, causing a runtime failure
2. **Annotation mismatch**: The generic GC predicate expects `PlatformType` and `PlatformVersion` annotations on managed resources, but the CCM deploy action does not stamp these annotations (they are empty). The CCM needs its own predicate that uses `InstanceUID` and `InstanceGeneration` annotations instead

## Requirements

1. **CCM-specific GC action**: Create a GC action that works in the CCM context by accepting the operator namespace explicitly through configuration rather than relying on cluster initialization
2. **CCM-specific GC predicate**: Implement a predicate that identifies stale resources by comparing `InstanceUID` and `InstanceGeneration` annotations against the current reconciler state. Resources with mismatched generation or UID should be collected.
3. **Protected resources**: The GC action must support a list of protected resources that are never collected regardless of annotation state (e.g., cert-manager PKI resources that are created but not managed by the CCM)
4. **Wire into pipeline**: Integrate the GC action into both the Azure and CoreWeave CCM controller reconciliation pipelines
5. **Namespace exclusion**: Namespaces themselves should never have owner references set and should be excluded from GC

## Testing Requirements

- Unit tests for the GC predicate: missing/empty annotations, UID mismatch, generation mismatch, protected object handling, namespace boundaries, malformed annotations
- Unit tests for the GC action constructor validation: empty resourceID, empty operatorNamespace, invalid protected objects
- Integration tests: GC deletes stale resources, GC preserves protected resources, GC handles dependency transitions to unmanaged, namespace exclusion
