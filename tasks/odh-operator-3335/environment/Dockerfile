FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

RUN microdnf install -y git make gcc gcc-c++ tar gzip findutils && microdnf clean all

RUN ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/') && \
    curl -fsSL https://go.dev/dl/go1.26.3.linux-${ARCH}.tar.gz | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:/root/go/bin:${PATH}"

WORKDIR /app
RUN git clone https://github.com/opendatahub-io/opendatahub-operator.git . && \
    git checkout 8b90fc6f2ee1c414bfab4bf06dfaf125520f6488

RUN go mod download

RUN make generate manifests

RUN go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest && \
    ENVTEST_PATH=$(setup-envtest use --bin-dir /usr/local/kubebuilder/bin -p path) && \
    ln -sf ${ENVTEST_PATH}/* /usr/local/kubebuilder/bin/
