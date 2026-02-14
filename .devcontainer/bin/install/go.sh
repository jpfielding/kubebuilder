#!/bin/bash


set -eux && \
    export VERSION="1.25.7"
    export ARCH="$(arch | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')" && \
    cd /tmp && mkdir -p ${SDK_HOME} && \
    curl -k -o /tmp/go.tar.gz -L https://go.dev/dl/go${VERSION}.linux-${ARCH}.tar.gz && \
    tar xzf /tmp/go.tar.gz -C /tmp/ && mv /tmp/go ${SDK_HOME} && rm /tmp/go.tar.gz && \
    cd ${SDK_HOME} && mv go go${VERSION} && ln -s go${VERSION} go