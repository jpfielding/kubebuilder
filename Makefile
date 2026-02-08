SHELL := /bin/bash
SCRIPTS_DIR := $(CURDIR)/scripts

MODULE_NAME = uio.go
REPO_PATH = $(shell git rev-parse --show-toplevel || pwd)
REPO_NAME = $(shell basename $$REPO_PATH)
GIT_SHA = $(shell git rev-parse --short HEAD)
BUILD_DATE = $(shell date +%Y-%m-%d)
BUILD_TIME = $(shell date +%H:%M:%S)

all: test build

help:  ## Prints the help/usage docs.
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST) | sort

nuke:  ## Resets the project to its initial state.
	git clean -ffdqx

clean:  ## Removes build/test outputs.
	rm -rf bin *.test
	go clean

update-deps:  ## Tidies up the go module.
	go get -u ./... && GOPROXY=direct go mod tidy && go mod vendor	

### TEST commands ####
test:  ## Runs short tests.
	go test -short -v ./pkg/...

test-report: ## Runs ALL tests with junit report output
	mkdir -p tmp && gotestsum --junitfile tmp/report.xml --format testname ./pkg/...

.PHONY: integration-test
	go test -v ./pkg/...

lint:  ## Run static code analysis
	golangci-lint run ./pkg/...

lint-report: ## Run golangci-lint report
	mkdir -p tmp && golangci-lint run --issues-exit-code 0 --output.text.path=stdout --output.text.colors=false --output.text.print-issued-lines=false --output.code-climate.path=tmp/gl-code-quality-report.json

vet:  ## Runs Golang's static code analysis
	go vet ./pkg/...

vulnerability: install-govulncheck ## Runs the vulnerability check.
	govulncheck ./pkg/...

vulnerability-report: ## Runs the vulnerability check.
	mkdir -p tmp && govulncheck -json ./pkg/... > tmp/go-vuln-report.json

#### INSTALL TOOLS ####
install-tools: install-claude install-k8s install-cert-tools install-gitlab-cli install-cicd-tools

.PHONY: install-claude
install-claude:
	claude update || \
	curl -fsSL https://claude.ai/install.sh | bash 2>/dev/null || echo "PLEASE NUDGE https://claude.ai Leidos NAUGHTY WARNING" && \
	claude doctor && \
	jq '.hasCompletedOnboarding = true' ${HOME}/.claude.json > ${HOME}/.claude.tmp.json && mv ${HOME}/.claude.tmp.json ${HOME}/.claude.json

install-codex: # opena-ai codex.rs
	ARCH=$(shell arch) && \
	OS=$(shell uname  | sed 's/Darwin/apple-darwin/' | sed 's/Linux/unknown-linux-musl/') && \
	curl -o /tmp/codex.tar.gz -L "https://github.com/openai/codex/releases/download/rust-v0.98.0/codex-$${ARCH}-$${OS}.tar.gz" && \
	tar -xvzf /tmp/codex.tar.gz -C /tmp && \
	mv /tmp/codex-$${ARCH}-$${OS} ${HOME}/bin/codex && \
	chmod +x ${HOME}/bin/codex

install-k8s: install-kubectl install-kind install-k9s install-kubebuilder

.PHONY: install-kubectl
install-kubectl: #
	VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)" && \
	ARCH="$(arch | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')" && \
	curl -o ${HOME}/bin/kubectl -L "https://dl.k8s.io/release/$${VERSION}/bin/linux/$${ARCH}/kubectl" && \
	chmod +x ${HOME}/bin/kubectl

.PHONY: install-kind
install-kind: #
	OS=$(shell uname | tr '[:upper:]' '[:lower:]') && \
	ARCH="$(shell arch | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')" && \
	VERSION="latest" && \
	curl -L -o ${HOME}/bin/kind "https://kind.sigs.k8s.io/dl/$${VERSION}/kind-$${OS}-$${ARCH}" && \
	chmod +x ${HOME}/bin/kind

.PHONY: install-k9s
install-k9s: #
	OS=$(shell uname) && \
	ARCH="$(shell arch | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')" && \
	VERSION="v0.50.18" && \
	curl -L -o /tmp/k9s.tar.gz "https://github.com/derailed/k9s/releases/download/$${VERSION}/k9s_$${OS}_$${ARCH}.tar.gz" && \
	tar -xzf /tmp/k9s.tar.gz -C ${HOME}/bin k9s && \
	chmod +x ${HOME}/bin/k9s

.PHONY: install-kubebuilder
install-kubebuilder: #
	VERSION="latest" && \
	curl -L -o ${HOME}/bin/kubebuilder "https://go.kubebuilder.io/dl/$${VERSION}/$(go env GOOS)/$(go env GOARCH)" && \
	chmod +x ${HOME}/bin/kubebuilder

install-gitlab-cli: # gitlab tools for repo managment
	VERSION="1.80.4" && \
    curl -o /tmp/glab.tar.gz -L "https://gitlab.com/gitlab-org/cli/-/releases/v$${VERSION}/downloads/glab_$${VERSION}_linux_${ARCH}.tar.gz" && \
    tar xzvf /tmp/glab.tar.gz bin/glab && mv bin/glab ${HOME}/bin/

install-cert-tools: install-mkcert install-certigo

install-mkcert: # 
	go install filippo.io/mkcert@latest

install-certigo: #
	go install github.com/square/certigo@latest

install-cicd-tools: install-gotestsum install-govulncheck install-golint

install-gotestsum: #
	go install gotest.tools/gotestsum@latest

install-govulncheck: #
	go install golang.org/x/vuln/cmd/govulncheck@latest

install-golint: #
	go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest

#### BUILD commands ####
build:  ## Build the library
	mkdir -p bin
	CGO_ENABLED=0 go build \
		-trimpath \
		-ldflags "-X 'main.GitSHA=$(GIT_SHA)'" \
		-o bin/dicosctl \
		cmd/ctl/*.go

