# MIT Kerberos Docker Image

Ubuntu 24.04 based MIT Kerberos KDC image with configurable client principals, service principals, passwords, and generated keytabs on a shared volume.

## Build

```bash
docker build -t openprojectx/mit-kerberos:ubuntu-24.04 .
```

## Run with Docker Compose

```bash
docker compose up --build
```

The included `docker-compose.yml` creates:

- realm `EXAMPLE.COM`
- client principals `alice`, `bob`, and `analytics@EXAMPLE.COM`
- service principals `HTTP/web.example.com`, `hive/hive-server.example.com`, and `spark/history.example.com`
- keytabs under the `kerberos-shared` volume at `/shared/keytabs`
- rendered Kerberos configs under `/shared/config`

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `KRB5_REALM` | `EXAMPLE.COM` | Kerberos realm. Use uppercase by convention. |
| `KRB5_DOMAIN` | `example.com` | DNS domain mapped to the realm in `krb5.conf`. |
| `KRB5_KDC_HOST` | `kerberos.example.com` | KDC hostname written to `krb5.conf`. |
| `KRB5_ADMIN_SERVER` | `kerberos.example.com` | Admin server hostname written to `krb5.conf`. |
| `KRB5_ADMIN_PRINCIPAL` | `admin/admin` | Admin principal. Realm is appended if omitted. |
| `KRB5_ADMIN_PASSWORD` | `admin` | Admin principal password. Also used as the master password unless `KRB5_MASTER_PASSWORD` is set. |
| `KRB5_MASTER_PASSWORD` | unset | KDC database master password. Defaults to `KRB5_ADMIN_PASSWORD`. |
| `KRB5_DEFAULT_PASSWORD` | `changeme` | Fallback password for generated principals. |
| `KRB5_CLIENT_PASSWORD` | unset | Shared fallback password for client principals. |
| `KRB5_SERVICE_PASSWORD` | unset | Shared fallback password for service principals. |
| `KRB5_CLIENT_PRINCIPALS` | unset | Comma-separated users, for example `alice,bob,analytics@EXAMPLE.COM`. |
| `KRB5_SERVICE_PRINCIPALS` | unset | Comma-separated service principals, for example `HTTP/web.example.com,hive/server.example.com`. |
| `KRB5_PASSWORD_MAP` | unset | Newline-separated `principal=password` overrides. Keys may include or omit the realm. |
| `KRB5_RESET_EXISTING_PASSWORDS` | `false` | When `true`, reset passwords for principals that already exist in the persisted KDC database. |
| `KRB5_KEYTAB_DIR` | `/shared/keytabs` | Directory where generated keytabs are written. |
| `KRB5_EXPORT_CONFIG_DIR` | `/shared/config` | Directory where rendered `krb5.conf` and `kdc.conf` are copied. |
| `KRB5_GENERATE_COMBINED_KEYTAB` | `true` | Also write all generated principals to `all.keytab`. |

## Password Selection

For each generated principal, the entrypoint chooses the password in this order:

1. Matching entry in `KRB5_PASSWORD_MAP`
2. `KRB5_CLIENT_PASSWORD` for client principals
3. `KRB5_SERVICE_PASSWORD` for service principals
4. `KRB5_DEFAULT_PASSWORD`

Example:

```yaml
environment:
  KRB5_CLIENT_PRINCIPALS: alice,bob
  KRB5_SERVICE_PRINCIPALS: HTTP/web.example.com,hive/hive-server.example.com
  KRB5_DEFAULT_PASSWORD: default-secret
  KRB5_PASSWORD_MAP: |
    alice=alice-secret
    HTTP/web.example.com=http-secret
```

## Keytabs

Keytabs are exported with `ktadd -norandkey`, so exporting a keytab does not randomize the principal password.

For a principal named `HTTP/web.example.com@EXAMPLE.COM`, the generated file is:

```text
/shared/keytabs/HTTP_web.example.com.keytab
```

When `KRB5_GENERATE_COMBINED_KEYTAB=true`, all configured client and service principals are also added to:

```text
/shared/keytabs/all.keytab
```

## Persistent Data

Persist `/var/lib/krb5kdc` to keep the KDC database across restarts. Persist `/shared` or mount it into other containers to consume generated keytabs and rendered config files.

The entrypoint is idempotent for existing principals. It creates missing principals and regenerates keytab files on each start.
