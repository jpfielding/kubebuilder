#!/bin/bash

# Allows us to create a kind cluster that can be accessed via host.docker.internal

NAME=${1:-"kind"}

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
        - "127.0.0.1"
        - "localhost"
EOF

kubectl config \
  set-cluster kind-${NAME} --server=https://host.docker.internal:$(kubectl \
  config view -o jsonpath='{.clusters[?(@.name=="kind-kind")].cluster.server}' | cut -d: -f3)