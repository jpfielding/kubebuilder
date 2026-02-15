#!/bin/bash

set -eux && \
	OS=$(uname) && \
	ARCH="$(arch | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')" && \
	VERSION="v0.50.18" && \
	curl -L -o /tmp/k9s.tar.gz "https://github.com/derailed/k9s/releases/download/${VERSION}/k9s_${OS}_${ARCH}.tar.gz" && \
	tar -xzf /tmp/k9s.tar.gz -C ${HOME}/bin k9s && \
	chmod +x ${HOME}/bin/k9s