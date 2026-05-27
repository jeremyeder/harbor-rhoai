# Cluster Changes — jeder-evalhub

Changes made to `jeder-evalhub` (ROSA HCP, RHOAI 3.4.0-ea.2) on 2026-05-12.

## Image Digest Fixes

All three operators had stale image digests that no longer exist in registry.redhat.io.
Updated to v3.4.0-ea.2 tag-based references.

### MLflow Operator
```bash
oc set env deployment/mlflow-operator-controller-manager \
  MLFLOW_IMAGE="registry.redhat.io/rhoai/odh-mlflow-rhel9@sha256:bdaa81e392689ebe1c77fac0b1dd755463b809b9c9b6fd5e0ba9767bc5cd76a0" \
  -n redhat-ods-applications
```

### MLflow Deployment
```bash
NEW_IMAGE="registry.redhat.io/rhoai/odh-mlflow-rhel9@sha256:bdaa81e392689ebe1c77fac0b1dd755463b809b9c9b6fd5e0ba9767bc5cd76a0"
oc set image deployment/mlflow mlflow=$NEW_IMAGE ca-bundle-watcher=$NEW_IMAGE -n redhat-ods-applications
oc patch deployment/mlflow -n redhat-ods-applications --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/initContainers/0/image","value":"'$NEW_IMAGE'"},
       {"op":"replace","path":"/spec/template/spec/initContainers/1/image","value":"'$NEW_IMAGE'"}]'
```

### EvalHub Deployment
```bash
oc set image deployment/evalhub \
  evalhub="registry.redhat.io/rhoai/odh-eval-hub-rhel9@sha256:c27bfe0140b8072993f09925f5c78bb8cefb6d5adbb9bc4c772e2b0f108a9422" \
  -n evalhub
```

### TrustyAI Operator
```bash
oc set image deployment/trustyai-service-operator-controller-manager \
  manager="registry.redhat.io/rhoai/odh-trustyai-service-operator-rhel9@sha256:e9148ec9da8851f2869a9e69f29d91b6398619ed73a154b7ff41c39504a0b846" \
  -n redhat-ods-applications
```

## Harbor Bench Provider Registration

### ConfigMap (provider spec)
```bash
oc apply -f deploy/harbor/configmap-template.yaml
# Creates: evalhub-provider-harbor-bench in redhat-ods-applications
# Labels: trustyai.opendatahub.io/evalhub-provider-name=harbor-bench
```

### EvalHub CR (add provider)
```bash
oc patch evalhub evalhub -n evalhub --type=json \
  -p '[{"op":"add","path":"/spec/providers/-","value":"harbor-bench"}]'
```

### Kube Auth Proxy (Data Science Gateway)
```bash
oc set image deployment/kube-auth-proxy \
  kube-auth-proxy="registry.redhat.io/rhoai/odh-kube-auth-proxy-rhel9@sha256:50ccc0969cab5197344f19e28e97c3de921733d64ff5356d55565c8f5c6fde84" \
  -n openshift-ingress
```

## Security — anyuid SCC for evalhub namespace

Harbor task images run as root (git operations, Go build cache). The default
OpenShift SCC assigns random UIDs which breaks these operations.

```bash
oc adm policy add-scc-to-user anyuid -z default -n evalhub
```

## Service Account for MLflow access

Created for local testing (not used in final flow — EvalHub handles MLflow auth).

```bash
oc create sa harbor-mlflow -n redhat-ods-applications
oc create clusterrolebinding harbor-mlflow-admin \
  --clusterrole=admin --serviceaccount=redhat-ods-applications:harbor-mlflow
```

## Task Images Pushed to Internal Registry

Built locally with `--platform linux/amd64`, pushed to cluster internal registry:

```bash
# Base environment image
image-registry.openshift-image-registry.svc:5000/evalhub/harbor-task-3290:latest

# Oracle (solution + tests baked in)
image-registry.openshift-image-registry.svc:5000/evalhub/harbor-task-3290:oracle
```

Build commands:
```bash
REGISTRY="default-route-openshift-image-registry.apps.rosa.jeder-evalhub.uqi3.p3.openshiftapps.com"

# Base
docker build --provenance=false --sbom=false --platform linux/amd64 \
  -t "${REGISTRY}/evalhub/harbor-task-3290:latest" \
  -f tasks/odh-operator-3290/environment/Dockerfile tasks/odh-operator-3290/environment/

# Oracle (adds solution/ and tests/)
docker build --provenance=false --sbom=false --platform linux/amd64 \
  --build-arg BASE_IMAGE="${REGISTRY}/evalhub/harbor-task-3290:latest" \
  -t "${REGISTRY}/evalhub/harbor-task-3290:oracle" \
  -f Dockerfile.k8s-task tasks/odh-operator-3290/

docker push "${REGISTRY}/evalhub/harbor-task-3290:latest"
docker push "${REGISTRY}/evalhub/harbor-task-3290:oracle"
```
