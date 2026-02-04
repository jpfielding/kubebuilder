#!/bin/bash
# Setup envtest for operator testing

set -e

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup envtest binaries for Kubernetes operator testing.

OPTIONS:
    -v, --version VERSION    Kubernetes version (default: latest)
    -p, --print-path        Print KUBEBUILDER_ASSETS path and exit
    --install-tool          Install setup-envtest tool first
    -h, --help              Show this help message

EXAMPLES:
    # Install setup-envtest tool
    $0 --install-tool

    # Setup latest K8s version
    $0

    # Setup specific K8s version
    $0 -v 1.28.0

    # Print path for shell export
    export KUBEBUILDER_ASSETS=\$($0 -p)

USAGE IN TESTS:
    Add to your test suite setup or Makefile:

    export KUBEBUILDER_ASSETS=\$(setup-envtest use -p path)
EOF
}

VERSION=""
PRINT_PATH=false
INSTALL_TOOL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -p|--print-path)
            PRINT_PATH=true
            shift
            ;;
        --install-tool)
            INSTALL_TOOL=true
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

# Install setup-envtest if requested
if [[ "$INSTALL_TOOL" == true ]]; then
    echo "Installing setup-envtest..."
    go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest
    echo "setup-envtest installed successfully"
    exit 0
fi

# Check if setup-envtest is installed
if ! command -v setup-envtest &> /dev/null; then
    echo "Error: setup-envtest is not installed"
    echo "Run: $0 --install-tool"
    exit 1
fi

# Print path if requested
if [[ "$PRINT_PATH" == true ]]; then
    if [[ -n "$VERSION" ]]; then
        setup-envtest use "$VERSION" -p path
    else
        setup-envtest use -p path
    fi
    exit 0
fi

# Setup envtest
echo "Setting up envtest..."
if [[ -n "$VERSION" ]]; then
    echo "Using Kubernetes version: $VERSION"
    setup-envtest use "$VERSION"
else
    echo "Using latest Kubernetes version"
    setup-envtest use
fi

ASSETS_PATH=$(setup-envtest use -p path)
echo ""
echo "Envtest setup complete!"
echo ""
echo "To use in your shell:"
echo "  export KUBEBUILDER_ASSETS=\"$ASSETS_PATH\""
echo ""
echo "To use in Makefile:"
echo "  ENVTEST = \$(LOCALBIN)/setup-envtest"
echo "  test: envtest"
echo "    KUBEBUILDER_ASSETS=\"\$(shell \$(ENVTEST) use -p path)\" go test ./... -coverprofile cover.out"
echo ""
echo "To use in CI (GitHub Actions):"
echo "  - name: Setup envtest"
echo "    run: |"
echo "      go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest"
echo "      echo \"KUBEBUILDER_ASSETS=\$(setup-envtest use -p path)\" >> \$GITHUB_ENV"
