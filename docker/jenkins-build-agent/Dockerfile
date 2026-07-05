# syntax=docker/dockerfile:1
# All-in-one Jenkins build agent.
#
# Runs as the pod's jnlp container, replacing the per-tool sidecars:
#   - JDK 25 from the base image (JAVA_HOME, default java on PATH)
#   - JDK 17 / 21 under /usr/lib/jvm, where Gradle toolchain auto-detection
#     finds them (projects with jvmToolchain(17|21) need no extra config)
#   - Node.js 22 (default on PATH) and 24, switch with:
#       export PATH="$NODE24_HOME/bin:$PATH"
#   - Docker 29 daemon/CLI for privileged Docker-in-Docker Testcontainers tests
#
# Gradle and Maven are intentionally NOT installed: repos bring their own
# wrapper (./gradlew, ./mvnw), cached on the gradle-cache PVC.
#
# Downloads go through the /var/cache/downloads cache mount so rebuilds skip
# them; in CI the mount is persisted across runs (see .github/workflows/
# docker-bump.yml). Files are fetched to *.part then renamed, so an
# interrupted download never poisons the cache.
FROM jenkins/inbound-agent:trixie-jdk25

ARG TARGETARCH=amd64
ARG NODE22_VERSION=22.23.1
ARG NODE24_VERSION=24.18.0
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
        openssl \
        pigz \
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
    git lfs version; \
    docker --version; \
    dockerd --version

ENTRYPOINT ["jenkins-dind-entrypoint.sh"]
