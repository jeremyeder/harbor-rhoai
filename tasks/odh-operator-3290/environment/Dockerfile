FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

RUN microdnf install -y git make gcc gcc-c++ tar gzip && microdnf clean all

RUN curl -fsSL https://go.dev/dl/go1.26.3.linux-amd64.tar.gz | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:/root/go/bin:${PATH}"

WORKDIR /app
RUN git clone https://github.com/opendatahub-io/opendatahub-operator.git . && \
    git checkout 115ed0a225131c6d1e23ad09c2aa347862dbf20f

RUN go mod download
