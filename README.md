# Kubebuilder Learning Lab

A minimal testbed for building, testing, and deploying Kubernetes operators using Kubebuilder.

## Prerequisites

- VS Code with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- Docker Desktop
- Access to a Kubernetes cluster (local or remote)
- kubectl configured on your host machine

## Quick Start

### Open in Dev Container

1. Open this project in VS Code
2. When prompted, click "Reopen in Container" (or use Command Palette: `Dev Containers: Reopen in Container`)
3. Wait for the container to build (includes Go 1.25.6, git, make, and all dependencies)

The dev container provides a complete development environment with all tools pre-configured.

### Install Kubebuilder (inside container)

```bash
# Install kubebuilder
curl -L -o kubebuilder "https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)"
chmod +x kubebuilder && mv kubebuilder ~/bin/

# Install kubectl
curl -L -o ~/bin/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$(go env GOARCH)/kubectl"
chmod +x ~/bin/kubectl
```

### Create Your First Operator

All commands below are run inside the dev container terminal.

```bash
# Create operator directory
mkdir -p operators/my-operator
cd operators/my-operator

# Initialize operator project
kubebuilder init --domain example.com --repo github.com/myorg/my-operator

# Create an API (Custom Resource)
kubebuilder create api --group apps --version v1 --kind MyResource
```

### Build and Test

```bash
# Generate manifests and code
make manifests generate

# Run tests
make test

# Build the operator
make build

# Build and push container image
make docker-build docker-push IMG=<registry>/my-operator:tag
```

### Deploy to Cluster

```bash
# Install CRDs
make install

# Deploy operator
make deploy IMG=<registry>/my-operator:tag

# Run locally for development (outside cluster)
make run
```

## Project Structure

```
operators/
├── operator-1/     # First operator project
│   ├── api/        # CRD definitions
│   ├── controllers/# Reconciliation logic
│   └── config/     # Kubernetes manifests
└── operator-2/     # Additional operators as needed
```

## Common Tasks

All commands run inside the dev container.

### Create a new operator

```bash
mkdir -p operators/<name>
cd operators/<name>
kubebuilder init --domain example.com --repo github.com/myorg/<name>
```

### Watch logs

```bash
kubectl logs -n <namespace> deployment/<operator>-controller-manager -f
```

### Cleanup

```bash
make undeploy  # Remove operator from cluster
make uninstall # Remove CRDs
```

## Dev Container Features

The development container includes:
- Rocky Linux 9
- Go 1.25.6
- Git, make, and build tools
- VS Code Go extension
- Persistent bash history per project
- Git credentials and SSH keys mounted from host

## Learning Path

1. Start with the [Kubebuilder Book](https://book.kubebuilder.io/)
2. Build a simple operator that manages a single custom resource
3. Add validation, defaulting, and webhooks
4. Implement status conditions and events
5. Add RBAC and security configurations

## Extending

- Add operators under `operators/` directory
- Use `config/samples/` for example custom resources
- Modify `controllers/` for business logic
- Update `api/` for resource schema changes

## Resources

- [Kubebuilder Book](https://book.kubebuilder.io/)
- [Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
- [controller-runtime](https://pkg.go.dev/sigs.k8s.io/controller-runtime)