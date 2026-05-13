# EvalHub Issue Drafts

## Issue 1: Sidecar image reference is hardcoded and unqualified

**Title:** Provider pod uses hardcoded unqualified sidecar image `eval-runtime-sidecar:latest` instead of configured value

**Labels:** bug, deployment

**Body:**

### Description

The EvalHub server hardcodes `eval-runtime-sidecar:latest` as the sidecar container image when creating provider Job pods. This unqualified image reference bypasses the `eval_sidecar_image` value from `config.yaml` and fails on clusters where CRI-O's `unqualified-search-registries` don't include a registry hosting this image.

### Steps to Reproduce

1. Deploy EvalHub server on an OpenShift cluster (tested with RHOAI 3.4.0-ea.2)
2. Configure `config.yaml` with `eval_sidecar_image` pointing to the correct fully-qualified image (e.g., `registry.redhat.io/rhoai/...`)
3. Register a provider and run `evalhub eval run --config job.yaml`
4. Observe the provider pod's sidecar container fails with `ImagePullBackOff`

### Expected Behavior

The sidecar container image should use the value from `eval_sidecar_image` in the server config, or at minimum use a fully-qualified default (e.g., `registry.redhat.io/rhoai/eval-runtime-sidecar:v0.3.0`).

### Actual Behavior

The K8s runtime code uses a compiled-in default of `eval-runtime-sidecar:latest`. CRI-O resolves this through `unqualified-search-registries` (typically `registry.access.redhat.com`, `docker.io`), where the image doesn't exist.

### Workaround

Deploy a Kyverno mutating policy to rewrite the sidecar image in provider pods:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: rewrite-eval-runtime-sidecar
spec:
  rules:
    - name: rewrite-sidecar-image
      match:
        resources:
          kinds: [Pod]
          namespaces: [evalhub]
      mutate:
        patchStrategicMerge:
          spec:
            containers:
              - (name): sidecar
                image: "image-registry.openshift-image-registry.svc:5000/evalhub/eval-runtime-sidecar:latest"
```

### Environment

- EvalHub server: v0.3.0
- RHOAI: 3.4.0-ea.2
- Platform: ROSA HCP (OpenShift 4.17)

---

## Issue 2: `providers list` crashes on malformed pass_criteria

**Title:** `evalhub providers list` crashes with ValidationError when a provider has empty `pass_criteria`

**Labels:** bug, sdk

**Body:**

### Description

`evalhub providers list` fails with a Pydantic `ValidationError` when any registered provider has a benchmark with `pass_criteria: {}` (empty dict). The SDK expects `pass_criteria.threshold` to be present if `pass_criteria` exists, but doesn't handle the case where the server returns an empty object.

### Steps to Reproduce

1. Register a provider that has a benchmark with `pass_criteria: {}` (or where the server stores an empty pass_criteria object)
2. Run `evalhub providers list`

### Expected Behavior

The command should list all providers, treating empty `pass_criteria` as "no pass criteria defined" (equivalent to `pass_criteria: null`).

### Actual Behavior

```
pydantic.ValidationError: 1 validation error for ...
items.5.benchmarks.22.pass_criteria.threshold
  Field required [type=missing, ...]
```

### Suggested Fix

In the SDK's Pydantic model for `PassCriteria`, make `threshold` optional:

```python
class PassCriteria(BaseModel):
    threshold: float | None = None
```

Or add a validator that treats `{}` as `None` before parsing.

### Environment

- eval-hub-sdk: 0.1.5 and 0.1.7 (both affected)
- Python: 3.14
