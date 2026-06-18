FROM mariadb:10.6.24-ubi9

# Need root to install packages (base image runs as the mysql user)
USER root

RUN microdnf install -y \
        # OpenJDK 17 (use -devel instead if you need javac/jar/etc.)
        java-17-openjdk-headless \
        # process / system inspection
        procps-ng \
        util-linux \
        lsof \
        # networking
        iproute \
        iputils \
        net-tools \
        bind-utils \
        nmap-ncat \
        # transfer / download
        curl \
        wget \
        # archive / compression
        tar \
        gzip \
        bzip2 \
        unzip \
        xz \
        # editors / pagers / misc
        vim \
        less \
        which \
        findutils \
        hostname \
        ca-certificates \
    && microdnf clean all \
    && rm -rf /var/cache/yum

# Make JAVA_HOME available
ENV JAVA_HOME=/usr/lib/jvm/jre-17 \
    PATH="/usr/lib/jvm/jre-17/bin:${PATH}"

# Restore the non-root user used by the MariaDB entrypoint
USER mysql