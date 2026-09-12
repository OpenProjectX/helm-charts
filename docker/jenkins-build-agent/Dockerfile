# syntax=docker/dockerfile:1
# All-in-one Jenkins build agent.
#
# Runs as the pod's jnlp container, replacing the per-tool sidecars:
#   - JDK 25 from the base image (JAVA_HOME, default java on PATH)
#   - JDK 17 / 21 under /usr/lib/jvm, where Gradle toolchain auto-detection
#     finds them (projects with jvmToolchain(17|21) need no extra config)
#   - Node.js 22 (default on PATH) and 24, switch with:
#       export PATH="$NODE24_HOME/bin:$PATH"
#   - Bun 1.4 (default on PATH)
#   - Docker 29 daemon/CLI + Buildx for privileged Docker-in-Docker builds and Testcontainers tests
#   - Helm 3 + kubectl + helmfile for in-cluster Kubernetes deployments
#   - Ansible (ansible-core) + openssh-client + gh for VM deploys and
#     GitHub release publishing
#
# Gradle and Maven are intentionally NOT installed: repos bring their own
# wrapper (./gradlew, ./mvnw), cached on the gradle-cache PVC.
#
# Downloads go through the /var/cache/downloads cache mount so rebuilds skip
# them; in CI the mount is persisted across runs (see .github/workflows/
# docker-bump.yml). Files are fetched to *.part then renamed, so an
# interrupted download never poisons the cache.
ARG BUILDX_VERSION=0.35.0
ARG HELM_VERSION=3.21.0
ARG KUBECTL_VERSION=1.36.1
ARG HELMFILE_VERSION=1.7.4
ARG HELM_DIFF_VERSION=3.15.13
ARG ANSIBLE_CORE_VERSION=2.21.4
ARG GH_VERSION=2.100.0

FROM docker/buildx-bin:${BUILDX_VERSION} AS buildx

FROM jenkins/inbound-agent:trixie-jdk25

ARG TARGETARCH=amd64
ARG BUILDX_VERSION=0.35.0
ARG HELM_VERSION=3.21.0
ARG KUBECTL_VERSION=1.36.1
ARG HELMFILE_VERSION=1.7.4
ARG ANSIBLE_CORE_VERSION=2.21.4
ARG GH_VERSION=2.100.0
ARG NODE22_VERSION=22.23.1
ARG NODE24_VERSION=24.18.0
ARG BUN_VERSION=1.4.1
ARG DOCKER_VERSION=29.6.1
ARG DIND_COMMIT=8d9e3502aba39127e4d12196dae16d306f76993d

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
        btrfs-progs \
        ca-certificates \
        curl \
        e2fsprogs \
        git-lfs \
        iproute2 \
        iptables \
        jq \
        kmod \
        openssh-client \
        openssl \
        pigz \
        python3 \
        python3-venv \
        uidmap \
        unzip \
        xfsprogs \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# JDK 17 & 21 (Temurin, latest GA patch at first download)
RUN --mount=type=cache,target=/var/cache/downloads,sharing=locked \
    set -eux; \
    case "${TARGETARCH}" in \
        amd64) JDK_ARCH=x64 ;; \
        arm64) JDK_ARCH=aarch64 ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    for v in 17 21; do \
        f="/var/cache/downloads/temurin-${v}-linux-${JDK_ARCH}.tar.gz"; \
        if [ ! -s "$f" ]; then \
            curl -fsSL -o "$f.part" \
                "https://api.adoptium.net/v3/binary/latest/${v}/ga/linux/${JDK_ARCH}/jdk/hotspot/normal/eclipse"; \
            mv "$f.part" "$f"; \
        fi; \
        mkdir -p "/usr/lib/jvm/temurin-${v}"; \
        tar -xzf "$f" -C "/usr/lib/jvm/temurin-${v}" --strip-components=1; \
    done

ENV JAVA17_HOME=/usr/lib/jvm/temurin-17 \
    JAVA21_HOME=/usr/lib/jvm/temurin-21 \
    JAVA25_HOME=/opt/java/openjdk

# Node.js 22 & 24
RUN --mount=type=cache,target=/var/cache/downloads,sharing=locked \
    set -eux; \
    case "${TARGETARCH}" in \
        amd64) NODE_ARCH=x64 ;; \
        arm64) NODE_ARCH=arm64 ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    for v in "${NODE22_VERSION}" "${NODE24_VERSION}"; do \
        f="/var/cache/downloads/node-v${v}-linux-${NODE_ARCH}.tar.xz"; \
        if [ ! -s "$f" ]; then \
            curl -fsSL -o "$f.part" "https://nodejs.org/dist/v${v}/node-v${v}-linux-${NODE_ARCH}.tar.xz"; \
            mv "$f.part" "$f"; \
        fi; \
        mkdir -p "/opt/node-${v%%.*}"; \
        tar -xJf "$f" -C "/opt/node-${v%%.*}" --strip-components=1; \
    done; \
    for bin in node npm npx corepack; do \
        ln -s "/opt/node-22/bin/${bin}" "/usr/local/bin/${bin}"; \
    done; \
    corepack enable --install-directory /usr/local/bin

ENV NODE22_HOME=/opt/node-22 \
    NODE24_HOME=/opt/node-24

# Bun (single binary; bunx is a symlink to bun). Global installs
# (bun add -g) stay per-user in ~/.bun, so the agent runs unprivileged.
RUN --mount=type=cache,target=/var/cache/downloads,sharing=locked \
    set -eux; \
    case "${TARGETARCH}" in \
        amd64) BUN_ARCH=x64 ;; \
        arm64) BUN_ARCH=aarch64 ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    f="/var/cache/downloads/bun-v${BUN_VERSION}-linux-${BUN_ARCH}.zip"; \
    if [ ! -s "$f" ]; then \
        curl -fsSL -o "$f.part" "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${BUN_ARCH}.zip"; \
        mv "$f.part" "$f"; \
    fi; \
    unzip -q "$f" -d /tmp/bun; \
    mkdir -p /opt/bun/bin; \
    install -m 0755 "/tmp/bun/bun-linux-${BUN_ARCH}/bun" /opt/bun/bin/bun; \
    rm -rf /tmp/bun; \
    ln -sf /opt/bun/bin/bun /usr/local/bin/bun; \
    ln -sf /opt/bun/bin/bun /usr/local/bin/bunx

# Docker CLI/daemon/runtime, adapted from the official docker:dind image.
RUN set -eux; \
    groupadd -g 2375 -r docker || true; \
    usermod -aG docker jenkins || true; \
    groupadd -r dockremap || true; \
    useradd -r -g dockremap dockremap || true; \
    echo 'dockremap:165536:65536' >> /etc/subuid; \
    echo 'dockremap:165536:65536' >> /etc/subgid

RUN set -eux; \
    mkdir -p /usr/local/sbin/.iptables-legacy; \
    for pair in \
        iptables:iptables-legacy \
        iptables-save:iptables-legacy-save \
        iptables-restore:iptables-legacy-restore \
        ip6tables:ip6tables-legacy \
        ip6tables-save:ip6tables-legacy-save \
        ip6tables-restore:ip6tables-legacy-restore \
    ; do \
        f="${pair%%:*}"; legacy="${pair#*:}"; \
        if command -v "$legacy" > /dev/null 2>&1; then \
            b="$(command -v "$legacy")"; \
            "$b" --version; \
            ln -svT "$b" "/usr/local/sbin/.iptables-legacy/$f"; \
        fi; \
    done

RUN --mount=type=cache,target=/var/cache/downloads,sharing=locked \
    set -eux; \
    case "${TARGETARCH}" in \
        amd64) DOCKER_ARCH=x86_64 ;; \
        arm64) DOCKER_ARCH=aarch64 ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    f="/var/cache/downloads/docker-${DOCKER_VERSION}-linux-${DOCKER_ARCH}.tgz"; \
    if [ ! -s "$f" ]; then \
        curl -fsSL -o "$f.part" "https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz"; \
        mv "$f.part" "$f"; \
    fi; \
    tar -xzf "$f" -C /usr/local/bin --strip-components=1 --no-same-owner; \
    dockerd --version; \
    docker --version; \
    containerd --version; \
    ctr --version; \
    runc --version; \
    docker-init --version

COPY --from=buildx /buildx /usr/local/lib/docker/cli-plugins/docker-buildx
RUN chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx; \
    docker buildx version

# Helm and kubectl for Kubernetes deployment stages.
RUN --mount=type=cache,target=/var/cache/downloads,sharing=locked \
    set -eux; \
    case "${TARGETARCH}" in \
        amd64) TOOL_ARCH=amd64 ;; \
        arm64) TOOL_ARCH=arm64 ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    helm_f="/var/cache/downloads/helm-v${HELM_VERSION}-linux-${TOOL_ARCH}.tar.gz"; \
    if [ ! -s "$helm_f" ]; then \
        curl -fsSL -o "$helm_f.part" "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TOOL_ARCH}.tar.gz"; \
        mv "$helm_f.part" "$helm_f"; \
    fi; \
    tar -xzf "$helm_f" -C /tmp "linux-${TOOL_ARCH}/helm"; \
    mv "/tmp/linux-${TOOL_ARCH}/helm" /usr/local/bin/helm; \
    rm -rf "/tmp/linux-${TOOL_ARCH}"; \
    kubectl_f="/var/cache/downloads/kubectl-v${KUBECTL_VERSION}-linux-${TOOL_ARCH}"; \
    if [ ! -s "$kubectl_f" ]; then \
        curl -fsSL -o "$kubectl_f.part" "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TOOL_ARCH}/kubectl"; \
        mv "$kubectl_f.part" "$kubectl_f"; \
    fi; \
    install -m 0755 "$kubectl_f" /usr/local/bin/kubectl; \
    helmfile_f="/var/cache/downloads/helmfile_${HELMFILE_VERSION}_linux_${TOOL_ARCH}.tar.gz"; \
    if [ ! -s "$helmfile_f" ]; then \
        curl -fsSL -o "$helmfile_f.part" "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_${TOOL_ARCH}.tar.gz"; \
        mv "$helmfile_f.part" "$helmfile_f"; \
    fi; \
    tar -xzf "$helmfile_f" -C /tmp helmfile; \
    install -m 0755 /tmp/helmfile /usr/local/bin/helmfile; \
    rm -f /tmp/helmfile; \
    helm version --client; \
    kubectl version --client=true; \
    helmfile --version; \
    helm plugin install "https://github.com/databus23/helm-diff" --version "v${HELM_DIFF_VERSION}"; \
    helm diff version

# Ansible (in an isolated venv) + gh CLI for VM deploys and GitHub releases.
RUN --mount=type=cache,target=/var/cache/downloads,sharing=locked \
    set -eux; \
    python3 -m venv /opt/ansible; \
    /opt/ansible/bin/pip install --no-cache-dir "ansible-core==${ANSIBLE_CORE_VERSION}"; \
    for bin in ansible ansible-playbook ansible-galaxy ansible-vault ansible-config ansible-inventory; do \
        ln -sf "/opt/ansible/bin/${bin}" "/usr/local/bin/${bin}"; \
    done; \
    case "${TARGETARCH}" in \
        amd64) GH_ARCH=linux_amd64 ;; \
        arm64) GH_ARCH=linux_arm64 ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    gh_f="/var/cache/downloads/gh_${GH_VERSION}_${GH_ARCH}.tar.gz"; \
    if [ ! -s "$gh_f" ]; then \
        curl -fsSL -o "$gh_f.part" "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION#v}_${GH_ARCH}.tar.gz"; \
        mv "$gh_f.part" "$gh_f"; \
    fi; \
    tar -xzf "$gh_f" -C /tmp --strip-components=2 "gh_${GH_VERSION#v}_${GH_ARCH}/bin/gh"; \
    install -m 0755 /tmp/gh /usr/local/bin/gh; \
    rm -f /tmp/gh; \
    ansible --version | head -1; \
    gh --version | head -1

RUN --mount=type=cache,target=/var/cache/downloads,sharing=locked \
    set -eux; \
    f="/var/cache/downloads/dind-${DIND_COMMIT}"; \
    if [ ! -s "$f" ]; then \
        curl -fsSL -o "$f.part" "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind"; \
        mv "$f.part" "$f"; \
    fi; \
    cp "$f" /usr/local/bin/dind; \
    chmod +x /usr/local/bin/dind

COPY modprobe.sh /usr/local/bin/modprobe
COPY dockerd-entrypoint.sh /usr/local/bin/
COPY jenkins-dind-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/modprobe /usr/local/bin/dockerd-entrypoint.sh /usr/local/bin/jenkins-dind-entrypoint.sh

ENV DOCKER_HOST=unix:///var/run/docker.sock \
    DOCKER_TLS_CERTDIR= \
    TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock

VOLUME /var/lib/docker

# sanity check
RUN set -eux; \
    java -version; \
    "${JAVA17_HOME}/bin/java" -version; \
    "${JAVA21_HOME}/bin/java" -version; \
    node --version; npm --version; \
    "${NODE24_HOME}/bin/node" --version; \
    bun --version; bunx --version; \
    git lfs version; \
    docker --version; \
    docker buildx version; \
    dockerd --version; \
    helm version --client; \
    kubectl version --client=true; \
    helmfile --version; \
    helm diff version; \
    ansible --version | head -1; \
    gh --version | head -1

ENTRYPOINT ["jenkins-dind-entrypoint.sh"]
