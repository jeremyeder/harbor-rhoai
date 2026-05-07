FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

RUN microdnf install -y git make gcc gcc-c++ tar gzip && microdnf clean all

RUN curl -fsSL https://go.dev/dl/go1.26.3.linux-amd64.tar.gz | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:/root/go/bin:${PATH}"

WORKDIR /app
RUN git clone https://github.com/opendatahub-io/opendatahub-operator.git . && \
    git checkout 8b90fc6f2ee1c414bfab4bf06dfaf125520f6488

RUN go mod download
