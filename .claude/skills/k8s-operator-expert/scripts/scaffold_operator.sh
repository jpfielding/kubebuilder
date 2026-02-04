#!/bin/bash
# Scaffold a new Kubernetes operator with common setup

set -e

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Scaffold a new Kubernetes operator project with best practices.

OPTIONS:
    -n, --name NAME          Operator name (required)
    -d, --domain DOMAIN      API domain (default: example.com)
    -r, --repo REPO          Go module repo path (required)
    -g, --group GROUP        API group (default: apps)
    -k, --kind KIND          Resource kind (required)
    -v, --version VERSION    API version (default: v1)
    --webhook               Enable webhook scaffolding
    -h, --help              Show this help message

EXAMPLES:
    # Basic operator
    $0 -n my-operator -r github.com/myorg/my-operator -k MyResource

    # With custom domain and webhooks
    $0 -n my-operator -d mycompany.com -r github.com/myorg/my-operator -k MyResource --webhook

    # Custom API group and version
    $0 -n my-operator -r github.com/myorg/my-operator -g cache -k Redis -v v1alpha1
EOF
}

# Default values
DOMAIN="example.com"
GROUP="apps"
VERSION="v1"
WEBHOOK=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            NAME="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -g|--group)
            GROUP="$2"
            shift 2
            ;;
        -k|--kind)
            KIND="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        --webhook)
            WEBHOOK=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$NAME" ]]; then
    echo "Error: Operator name is required"
    usage
    exit 1
fi

if [[ -z "$REPO" ]]; then
    echo "Error: Repository path is required"
    usage
    exit 1
fi

if [[ -z "$KIND" ]]; then
    echo "Error: Resource kind is required"
    usage
    exit 1
fi

echo "Scaffolding operator: $NAME"
echo "  Domain: $DOMAIN"
echo "  Repo: $REPO"
echo "  API: $GROUP/$VERSION"
echo "  Kind: $KIND"
echo "  Webhook: $WEBHOOK"
echo ""

# Check if kubebuilder is installed
if ! command -v kubebuilder &> /dev/null; then
    echo "Error: kubebuilder is not installed"
    echo "Install from: https://book.kubebuilder.io/quick-start.html#installation"
    exit 1
fi

# Create directory
mkdir -p "$NAME"
cd "$NAME"

# Initialize project
echo "Initializing project..."
kubebuilder init --domain "$DOMAIN" --repo "$REPO"

# Create API
echo "Creating API..."
kubebuilder create api --group "$GROUP" --version "$VERSION" --kind "$KIND" --resource --controller

# Create webhook if requested
if [[ "$WEBHOOK" == true ]]; then
    echo "Creating webhook..."
    kubebuilder create webhook --group "$GROUP" --version "$VERSION" --kind "$KIND" --defaulting --programmatic-validation
fi

# Generate manifests and code
echo "Generating manifests and code..."
make manifests generate

echo ""
echo "Operator scaffolded successfully!"
echo ""
echo "Next steps:"
echo "  1. cd $NAME"
echo "  2. Implement reconciliation logic in controllers/${KIND,,}_controller.go"
echo "  3. Update API types in api/$VERSION/${KIND,,}_types.go"
if [[ "$WEBHOOK" == true ]]; then
    echo "  4. Implement webhook logic in api/$VERSION/${KIND,,}_webhook.go"
fi
echo "  5. Run tests: make test"
echo "  6. Run locally: make run"
echo "  7. Deploy: make docker-build docker-push IMG=<registry>/<image>:tag && make deploy IMG=<registry>/<image>:tag"
