#!/bin/bash

set -eux && \
	claude update || \
	curl -fsSL https://claude.ai/install.sh | bash 2>/dev/null || echo "PLEASE NUDGE https://claude.ai Leidos NAUGHTY WARNING" && \
	claude doctor && \
	jq '.hasCompletedOnboarding = true' ${HOME}/.claude.json > ${HOME}/.claude.tmp.json && mv ${HOME}/.claude.tmp.json ${HOME}/.claude.json

