#!/bin/bash

set -eux && \
	ARCH="$(shell arch | sed 's/arm64/aarch64/' | sed 's/amd64/x86_64/')" && \
	OS=$(shell uname  | sed 's/Darwin/apple-darwin/' | sed 's/Linux/unknown-linux-musl/') && \
	curl -o /tmp/codex.tar.gz -L "https://github.com/openai/codex/releases/download/rust-v0.98.0/codex-$${ARCH}-$${OS}.tar.gz" && \
	tar -xvzf /tmp/codex.tar.gz -C /tmp && \
	mv /tmp/codex-$${ARCH}-$${OS} ${HOME}/bin/codex && \
	chmod +x ${HOME}/bin/codex

