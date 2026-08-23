# syntax=docker/dockerfile:1
# Wren AI Core (OSS) CLI image.
#
# Upstream publishes NO image for the current product: `docker/` exists only on
# the frozen `legacy/v1` branch, and every ghcr.io/canner/* image (wren-ui,
# wren-ai-service, wren-engine) belongs to the sunset "GenBI Classic" stack.
# The current OSS product is the `wrenai` PyPI package — hence this image.
#
# Contents:
#   - Python 3.12 + the `wren` CLI in an isolated venv on PATH
#   - Temurin JDK 21 (JAVA_HOME) for JVM/JDBC tooling
#   - Node.js 22 (node/npm/npx) for GenBI apps: wren-core-wasm, wrangler, vercel
#   - Warehouse connector extras (postgres, mysql, bigquery, snowflake, ...)
#
# IMPORTANT — the mcp pin. wrenai declares `mcp[cli]>=1.19` with no upper
# bound, but mcp 2.0 removed `mcp.server.fastmcp`, which wren/mcp_server.py
# imports. Installing `wrenai[mcp]` alone yields a server that dies with
# ModuleNotFoundError. `mcp[cli]<2` below is what keeps `wren serve mcp`
# working; do not drop it without re-testing.
#
# Downloads go through the /var/cache/downloads cache mount so rebuilds skip
# them (persisted across CI runs by .github/workflows/docker-bump.yml). Files
# are fetched to *.part then renamed, so an interrupted download never poisons
# the cache.
ARG PYTHON_VERSION=3.12
ARG UV_VERSION=0.9.28

FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

FROM python:${PYTHON_VERSION}-slim-trixie

ARG TARGETARCH=amd64
ARG WRENAI_VERSION=0.13.3
ARG JDK_VERSION=21
ARG NODE_VERSION=22.23.1
# Connector extras. `memory` is deliberately excluded: it pulls LanceDB and an
# embedding model (~800 MB) and is only worth it past ~200 models.
ARG WREN_EXTRAS=postgres,mysql,oracle,bigquery,snowflake,redshift,clickhouse,trino,athena,databricks,spark,main,mcp

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        libmariadb3 \
        jq \
        less \
        netcat-openbsd \
        procps \
        tar \
        unzip \
        vim-tiny \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Temurin JDK (latest GA patch for the major at first download)
RUN --mount=type=cache,target=/var/cache/downloads,sharing=locked \
    set -eux; \
    case "${TARGETARCH}" in \
        amd64) JDK_ARCH=x64 ;; \
        arm64) JDK_ARCH=aarch64 ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    f="/var/cache/downloads/temurin-${JDK_VERSION}-linux-${JDK_ARCH}.tar.gz"; \
    if [ ! -s "$f" ]; then \
        curl -fsSL -o "$f.part" \
            "https://api.adoptium.net/v3/binary/latest/${JDK_VERSION}/ga/linux/${JDK_ARCH}/jdk/hotspot/normal/eclipse"; \
        mv "$f.part" "$f"; \
    fi; \
    mkdir -p /usr/lib/jvm/temurin; \
    tar -xzf "$f" -C /usr/lib/jvm/temurin --strip-components=1

ENV JAVA_HOME=/usr/lib/jvm/temurin

# Node.js
RUN --mount=type=cache,target=/var/cache/downloads,sharing=locked \
    set -eux; \
    case "${TARGETARCH}" in \
        amd64) NODE_ARCH=x64 ;; \
        arm64) NODE_ARCH=arm64 ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    f="/var/cache/downloads/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"; \
    if [ ! -s "$f" ]; then \
        curl -fsSL -o "$f.part" \
            "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"; \
        mv "$f.part" "$f"; \
    fi; \
    mkdir -p /opt/node; \
    tar -xJf "$f" -C /opt/node --strip-components=1

ENV NODE_HOME=/opt/node

# Wren CLI, isolated venv so it never collides with system or app packages.
COPY --from=uv /uv /usr/local/bin/uv
# `mysqlclient` is a C extension: it needs a toolchain and MySQL/MariaDB
# headers to build. Both are purged in the same layer so they never ship;
# libmariadb3 (installed above) is what the built extension links against.
RUN --mount=type=cache,target=/root/.cache/uv \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        default-libmysqlclient-dev \
        pkg-config; \
    uv venv /opt/wren/venv; \
    VIRTUAL_ENV=/opt/wren/venv uv pip install \
        "wrenai[${WREN_EXTRAS}]==${WRENAI_VERSION}" \
        "mcp[cli]<2"; \
    apt-get purge -y --auto-remove build-essential default-libmysqlclient-dev pkg-config; \
    rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/opt/wren/venv \
    WREN_PROJECT_HOME=/project \
    PATH="/opt/wren/venv/bin:${JAVA_HOME}/bin:${NODE_HOME}/bin:${PATH}"

# A login shell (`bash -l`, `docker exec -it ... bash -l`) re-reads
# /etc/profile and overwrites PATH, losing the venv, JDK and Node. Restore it
# there too so interactive debugging behaves like the default CMD.
RUN printf '%s\n' \
    'export JAVA_HOME=/usr/lib/jvm/temurin' \
    'export NODE_HOME=/opt/node' \
    'export VIRTUAL_ENV=/opt/wren/venv' \
    'export PATH="/opt/wren/venv/bin:$JAVA_HOME/bin:$NODE_HOME/bin:$PATH"' \
    > /etc/profile.d/10-wren.sh

# Non-root. Project and wren home are writable so `context build`, `memory
# index` and `profile add` work when those paths are mounted.
RUN set -eux; \
    useradd --create-home --uid 10001 --shell /bin/bash wren; \
    mkdir -p /project /home/wren/.wren; \
    chown -R wren:wren /project /home/wren

# sanity check
RUN set -eux; \
    python --version; \
    java -version; \
    node --version; npm --version; \
    wren --version; \
    wren docs connection-info postgres > /dev/null; \
    python -c "from mcp.server.fastmcp import FastMCP; import mcp; print('mcp fastmcp import OK')"

USER wren
WORKDIR /project

# Override freely: `wren --sql ...`, `wren context build`, or a shell.
CMD ["wren", "serve", "mcp"]
