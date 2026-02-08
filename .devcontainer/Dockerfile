FROM rockylinux:9 AS base

ARG REPO_NAME=kubebuilder
ARG USERNAME=k8s
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Add ca certs so we can build the image on vpn
COPY cas.pem /etc/pki/ca-trust/source/anchors/cas.pem
RUN update-ca-trust

RUN set -eux -o pipefail && \
    dnf install -y epel-release && \
    dnf -y update
RUN set -eux -o pipefail && \
    dnf install -y ca-certificates curl-minimal git git-lfs iproute jq make msitools ncurses nss-tools procps sudo wget which zsh zip
RUN set -eux -o pipefail && \
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
    dnf install -y docker-ce-cli

FROM base AS user

# Create the user
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
  useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} -s /bin/zsh && \
  echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} && \
  chmod 0440 /etc/sudoers.d/${USERNAME}

RUN usermod -aG docker ${USERNAME} 

########### NON ROOT FROM HERE DOWN ###########
USER ${USERNAME}

RUN set -eux && \
    mkdir -p ${HOME}/bin && \
    sudo mkdir -p /workdir/${REPO_NAME} && \
    sudo chown ${USERNAME}:${USERNAME} /workdir

# envs
ENV HOME="/home/${USERNAME}"
ENV SDK_HOME="${HOME}/sdk"
ENV PATH="${HOME}/bin:${PATH}"

# kind uses our network
ENV KIND_EXPERIMENTAL_DOCKER_NETWORK=${REPO_NAME}
ENV KIND_CLUSTER_NAME=${REPO_NAME}
ENV KUBECONFIG="${HOME}/.kube/config-${REPO_NAME}"
    
# claude code
ENV PATH="${HOME}/bin:${HOME}/.local/bin:${PATH}"
ENV NODE_EXTRA_CA_CERTS="/etc/pki/ca-trust/source/anchors/custom_cas.pem"
RUN echo '{"hasCompletedOnboarding": true}' > ${HOME}/.claude.json

# go
ENV GO_VERSION="1.25.7"
ENV GOPRIVATE="*.psdo.leidos.com"
ENV GOPATH="${SDK_HOME}/go"
ENV PATH="${GOPATH}/bin:${HOME}/sdk/go:${PATH}"
RUN set -eux && \
    export GO_ARCH="$(arch | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')" && \
    cd /tmp && mkdir -p ${SDK_HOME} && \
    curl -k -o go.tar.gz -L https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz && \
    tar xzf go.tar.gz && mv go ${SDK_HOME} && rm /tmp/go.tar.gz && \
    cd ${SDK_HOME} && mv go go${GO_VERSION} && ln -s go${GO_VERSION} go

# pretty bash
COPY --chown=${USERNAME}:${USERNAME} .bash_pretty ${HOME}/.bash_pretty
RUN set -eux && \
    echo "source ${HOME}/.bash_pretty" >> ${HOME}/.bashrc
