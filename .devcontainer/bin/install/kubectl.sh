#!/bin/bash

set -eux && \
	VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)" && \
	ARCH="$(arch | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')" && \
	curl -L -o ${HOME}/bin/kubectl "https://dl.k8s.io/release/${VERSION}/bin/linux/${ARCH}/kubectl" && \
	chmod +x ${HOME}/bin/kubectl