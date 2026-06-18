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