FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    KRB5_REALM=EXAMPLE.COM \
    KRB5_DOMAIN=example.com \
    KRB5_KDC_HOST=kerberos.example.com \
    KRB5_ADMIN_SERVER=kerberos.example.com \
    KRB5_KEYTAB_DIR=/shared/keytabs \
    KRB5_EXPORT_CONFIG_DIR=/shared/config \
    KRB5_CLIENT_PRINCIPALS= \
    KRB5_SERVICE_PRINCIPALS= \
    KRB5_ADMIN_PRINCIPAL=admin/admin \
    KRB5_ADMIN_PASSWORD=admin \
    KRB5_DEFAULT_PASSWORD=changeme \
    KRB5_CLIENT_PASSWORD= \
    KRB5_SERVICE_PASSWORD= \
    KRB5_PASSWORD_MAP= \
    KRB5_GENERATE_COMBINED_KEYTAB=true

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gettext-base \
        krb5-admin-server \
        krb5-kdc \
        krb5-user \
        procps \
    && rm -rf /var/lib/apt/lists/*

COPY krb5.conf.template /opt/kerberos/templates/krb5.conf.template
COPY kdc.conf.template /opt/kerberos/templates/kdc.conf.template
COPY entrypoint.sh /usr/local/bin/kerberos-entrypoint

RUN chmod +x /usr/local/bin/kerberos-entrypoint \
    && mkdir -p /shared/keytabs /shared/config /etc/krb5kdc

VOLUME ["/shared"]

EXPOSE 88/tcp 88/udp 749/tcp

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
    CMD pgrep krb5kdc >/dev/null && pgrep kadmind >/dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/kerberos-entrypoint"]
