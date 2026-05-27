FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

RUN microdnf install -y git make gcc gcc-c++ tar gzip findutils shadow-utils && microdnf clean all

RUN ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/') && \
    curl -fsSL https://go.dev/dl/go1.26.3.linux-${ARCH}.tar.gz | tar -C /usr/local -xz

RUN useradd -m -u 1001 -s /bin/bash harbor
ENV HOME=/home/harbor
ENV GOPATH=/home/harbor/go
ENV GOCACHE=/home/harbor/.cache/go-build
ENV PATH="/usr/local/go/bin:${GOPATH}/bin:${PATH}"

WORKDIR /app
RUN git clone https://github.com/opendatahub-io/opendatahub-operator.git . && \
    git checkout 115ed0a225131c6d1e23ad09c2aa347862dbf20f

RUN go mod download

RUN make generate manifests

RUN go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest && \
    ENVTEST_PATH=$(setup-envtest use --bin-dir /usr/local/kubebuilder/bin -p path) && \
    ln -sf ${ENVTEST_PATH}/* /usr/local/kubebuilder/bin/

RUN chown -R harbor:harbor /app /home/harbor /usr/local/kubebuilder
RUN mkdir -p /logs && chown -R harbor:harbor /logs

USER 1001
