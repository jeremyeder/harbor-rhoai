# Add Monitoring Label Injector Mutation Webhook

## Problem

The ODH monitoring stack requires that `PodMonitor` and `ServiceMonitor` resources carry a specific monitoring scrape label to be discovered by the metrics collection pipeline. Currently, users must manually add this label to every monitoring resource they create, which is error-prone and creates a gap when third-party operators deploy their own monitors without the label.

## Requirements

Implement a mutating admission webhook that automatically injects the ODH monitoring label on `PodMonitor` and `ServiceMonitor` resources:

1. **Namespace opt-in**: The webhook should only inject labels on resources in namespaces that have opted into ODH monitoring (via a namespace-level annotation or label)
2. **Preserve user values**: If a user has explicitly set the monitoring label on a resource, the webhook must not override their value
3. **Handle create and update**: Label injection should occur on both resource creation and updates
4. **Idempotency**: Applying the webhook multiple times to the same resource should produce the same result

## Implementation Guidance

- Follow the existing webhook patterns in the operator's webhook infrastructure
- The webhook should be registered as a `MutatingWebhookConfiguration`
- Use the admission webhook handler interface from `sigs.k8s.io/controller-runtime`

## Testing Requirements

- **Unit tests**: Test the mutation logic directly — verify label injection on create, preservation of user-defined labels, no-op when namespace is not opted in, idempotent behavior on updates
- **Integration tests**: Use envtest to verify the webhook is correctly registered and handles admission requests end-to-end
- **E2E tests**: Verify webhook behavior in a running cluster context — label injection on opted-in namespaces, no injection on opted-out namespaces
