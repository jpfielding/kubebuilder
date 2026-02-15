#!/bin/bash

# Allows us to create a kind cluster that can be accessed via host.docker.internal

REPO_PATH=$(git rev-parse --show-toplevel || pwd)
REPO_NAME=$(basename $REPO_PATH)

NAME=${1:-$REPO_NAME}

kind create cluster --name "${NAME}" --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      certSANs:
        - "host.docker.internal"
        - "${NAME}-control-plane"
        - "127.0.0.1"
        - "localhost"
EOF

kubectl config set-cluster kind-${NAME} --server=https://${NAME}-control-plane:6443