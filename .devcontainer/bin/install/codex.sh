#!/bin/bash

set -euxo pipefail

ARCH="$(uname -m | sed 's/^arm64$/aarch64/' | sed 's/^amd64$/x86_64/')"
OS="$(uname | sed 's/^Darwin$/apple-darwin/' | sed 's/^Linux$/unknown-linux-musl/')"
VERSION="rust-v0.98.0"
ARCHIVE="/tmp/codex-${ARCH}-${OS}.tar.gz"

mkdir -p "${HOME}/bin"
curl -fsSL -o "${ARCHIVE}" "https://github.com/openai/codex/releases/download/${VERSION}/codex-${ARCH}-${OS}.tar.gz"
tar -xzf "${ARCHIVE}" -C /tmp
mv "/tmp/codex-${ARCH}-${OS}" "${HOME}/bin/codex"
chmod +x "${HOME}/bin/codex"
