#!/bin/bash

set -eux && \
	VERSION="latest" && \
	curl -L -o ${HOME}/bin/kubebuilder "https://go.kubebuilder.io/dl/${VERSION}/$(go env GOOS)/$(go env GOARCH)" && \
	chmod +x ${HOME}/bin/kubebuilder