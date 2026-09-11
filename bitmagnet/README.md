# Bitmagnet Helm chart

Deploys [Bitmagnet](https://bitmagnet.io) against an external PostgreSQL
database. PostgreSQL is deliberately not bundled, so the chart composes with
an operator, managed database, or an existing database service.

## Required database configuration

Use an existing Secret whenever possible:

```yaml
postgres:
  host: bitmagnet-pg-primary.it.svc
  database: bitmagnet
  sslMode: require
  auth:
    existingSecret: bitmagnet-pg-pguser-bitmagnet
    usernameKey: user
    passwordKey: password
```

For a standalone test, omit `existingSecret` and set
`postgres.auth.username` and `postgres.auth.password`. The latter is stored in
the Helm release, so it is not recommended for production.

## Workers and DHT

`workers.all: true` runs Bitmagnet's complete worker set. For a split topology,
set it to `false` and configure `workers.keys`. Keep `http_server` in workloads
served by this chart's HTTP Service.

The DHT Service exposes TCP and UDP 3334 as `ClusterIP` by default. Inbound DHT
requires a reachable `LoadBalancer` or `NodePort`, depending on the cluster.
Running a DHT crawler also creates BitTorrent network traffic from the pod's
egress address; use an egress VPN or gateway when that address must be hidden.

## Persistence and observability

Bitmagnet stores its durable catalog in PostgreSQL. `persistence.enabled`
controls its local XDG data directory, which is mainly needed for file logging
or other local state. JSON stdout logging is enabled by default for Kubernetes
log collectors. `serviceMonitor.enabled` exposes `/metrics` to a Prometheus
Operator-compatible collector.

