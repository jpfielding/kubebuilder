FROM rockylinux/rockylinux:10 AS base

ARG REPO_NAME=kubebuilder
ARG USERNAME=k8s
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Add ca certs so we can build the image on vpn
COPY cas.pem /etc/pki/ca-trust/source/anchors/custom_cas.pem
RUN update-ca-trust

RUN dnf install -y epel-release && dnf -y update
RUN dnf install -y curl-minimal git iproute iputils jq make sudo wget which zip zsh
RUN dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
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

# pretty bash
COPY --chown=${USERNAME}:${USERNAME} .bash_pretty ${HOME}/.bash_pretty
RUN echo "source ${HOME}/.bash_pretty" >> ${HOME}/.bashrc

# our dev tools
COPY --chown=${USERNAME}:${USERNAME} bin ${HOME}/bin 

#kind 
ENV KIND_CLUSTER_NAME=${REPO_NAME}
ENV KIND_EXPERIMENTAL_DOCKER_NETWORK=${REPO_NAME}

# claude code
ENV PATH="${HOME}/bin:${HOME}/.local/bin:${PATH}"
ENV NODE_EXTRA_CA_CERTS="/etc/pki/ca-trust/source/anchors/custom_cas.pem"
RUN echo '{"hasCompletedOnboarding": true}' > ${HOME}/.claude.json

# go
ENV GOPRIVATE="*.psdo.leidos.com,*-leidos.com"
ENV GOPATH="${SDK_HOME}/go"
ENV PATH="${GOPATH}/bin:${HOME}/sdk/go:${PATH}"

# installs
RUN bash ${HOME}/bin/install/go.sh
RUN bash ${HOME}/bin/install/kubectl.sh
RUN bash ${HOME}/bin/install/kind.sh
RUN	bash ${HOME}/bin/install/kubebuilder.sh

