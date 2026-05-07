# Detect and Report Failed ImageStream Tag Imports

## Problem

The operator deploys notebook ImageStreams as part of the Workbenches component, but never checks whether the image imports actually succeeded. On disconnected clusters or after network failures, ImageStream tag imports fail permanently with `ImportSuccess: False` in the tag's import status conditions.

The operator continues to report `Ready: True` despite these broken ImageStreams, and users receive no indication of why workbench creation fails. OpenShift does not automatically retry failed imports — re-applying an unchanged spec is a no-op.

## Requirements

Implement a new status action for the Workbenches reconciliation pipeline that:

1. **Detects failed imports**: Lists ImageStreams managed by the Workbenches component and checks each tag for failed import conditions (empty `items` list combined with `ImportSuccess: False`)
2. **Surfaces through status conditions**: Sets an `ImageStreamsAvailable` condition on the Workbenches CR with details about which tags failed and why
3. **Propagates to DSC**: Appends a warning message to the `WorkbenchesReady` condition on the DataScienceCluster so the information is visible at the cluster level
4. **Detection only**: This is an informational warning, not a readiness gate. The `WorkbenchesReady` condition should remain `True` because some upstream notebook images (CUDA/ROCm variants) are not always published. The warning is surfaced through the condition message.
5. **Security**: Error messages from the image registry should be truncated to a reasonable length per tag to avoid leaking excessive internal details (CWE-209)

## Implementation Guidance

- Follow the same pattern as existing status actions (e.g., `deployments.NewAction()`)
- The action should list ImageStreams by component label in the applications namespace
- Use the existing status condition infrastructure for setting conditions on the CR

## Testing Requirements

- Unit tests for the detection logic: failed imports detected correctly, successful imports produce no warning, multiple failed tags aggregated properly, message truncation works
- E2E tests verifying the condition appears on the Workbenches CR when ImageStream imports fail
