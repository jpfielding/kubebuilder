#!/bin/bash

set -eux && \
	OS=$(uname | tr '[:upper:]' '[:lower:]') && \
	ARCH="$(arch | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')" && \
	VERSION="latest" && \
	curl -L -o ${HOME}/bin/kind "https://kind.sigs.k8s.io/dl/${VERSION}/kind-${OS}-${ARCH}" && \
	chmod +x ${HOME}/bin/kind