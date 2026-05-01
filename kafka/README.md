# kafka

helm install kafka ./kafka -n kafka --create-namespace
helm upgrade kafka ./kafka -n kafka

The default values deploy:

- a Kerby KDC using `openprojectx/kerby-kdc`
- a two-broker Apache Kafka KRaft cluster using SASL/GSSAPI
- Confluent Schema Registry
- Kafbat UI
- a topic initialization Job

Key toggles:

- `kerberos.enabled`, `kerberos.kdc.enabled`, and `kerberos.existingSecret`
- `kafka.replicaCount`, `kafka.clusterId`, `kafka.config`, `kafka.persistence`
- `schemaRegistry.enabled`
- `kafbatUi.enabled`
- `topicInit.enabled`
- `mirrorMaker.enabled`
- `istio.enabled` with opt-in `HTTPRoute`, `TCPRoute`, `VirtualService`, `DestinationRule`, `PeerAuthentication`, and `AuthorizationPolicy` resources

API-family switches:

- Gateway API only: `istio.enabled=true`, `istio.gatewayApi.enabled=true`, `istio.native.enabled=false`
- Istio native only: `istio.enabled=true`, `istio.gatewayApi.enabled=false`, `istio.native.enabled=true`
- Mixed: keep both enabled and enable only the individual resources available in the cluster

For production, prefer providing an external Kerberos secret or RWX volume containing `client/krb5.conf` and service keytabs. When using a secret, set `kerberos.existingSecret` and map keys into nested paths with `kerberos.existingSecretItems`, for example `[{key: krb5.conf, path: client/krb5.conf}, {key: kafka-0.keytab, path: keytabs/kafka-0.keytab}]`.

Kerberos clients should use the StatefulSet broker DNS names from the headless service. If exposing Kafka through an Istio TCP route, add a matching `kafka/<external-host>@REALM` service principal and keytab, or override the advertised listener and Kerberos principal pattern accordingly.

## Broker persistence

Broker data uses PVCs by default. For ephemeral/dev clusters that should not create PVCs, disable broker persistence:

```yaml
kafka:
  persistence:
    enabled: false
```

With persistence disabled, the broker data path is still mounted, but it uses `emptyDir` and is lost when the pod is deleted.

## User-managed SASL secrets

For SASL/PLAIN, keep credentials in Kubernetes Secrets and point the chart at those secrets instead of putting JAAS strings in values files.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kafka-auth
type: Opaque
stringData:
  kafka-server-jaas.conf: |
    KafkaServer {
      org.apache.kafka.common.security.plain.PlainLoginModule required
      username="admin"
      password="admin-secret"
      user_admin="admin-secret"
      user_kafbat-ui="ui-secret"
      user_schema-registry="schema-secret"
      user_mm2="mm2-secret";
    };
  schema-registry-jaas.conf: |
    org.apache.kafka.common.security.plain.PlainLoginModule required username="schema-registry" password="schema-secret";
  kafbat-ui-jaas.conf: |
    org.apache.kafka.common.security.plain.PlainLoginModule required username="kafbat-ui" password="ui-secret";
  client-secret.properties: |
    sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="admin" password="admin-secret";
---
apiVersion: v1
kind: Secret
metadata:
  name: kafka-mm2
type: Opaque
stringData:
  mm2-secret.properties: |
    primary.sasl.jaas.config = org.apache.kafka.common.security.plain.PlainLoginModule required username="mm2" password="mm2-secret";
    standby.sasl.jaas.config = org.apache.kafka.common.security.plain.PlainLoginModule required username="mm2" password="mm2-secret";
```

Then reference them from values:

```yaml
kafka:
  jaas:
    enabled: true
    existingSecret: kafka-auth
    existingSecretKey: kafka-server-jaas.conf

topicInit:
  commandConfig: |
    security.protocol=SASL_PLAINTEXT
    sasl.mechanism=PLAIN
  commandConfigSecretExistingSecret: kafka-auth
  commandConfigSecretExistingSecretKey: client-secret.properties

mirrorMaker:
  properties: |
    clusters = primary, standby
    primary.bootstrap.servers = kafka-kafka-primary-0.kafka-kafka-primary-headless.kafka.svc.cluster.local:9092,kafka-kafka-primary-1.kafka-kafka-primary-headless.kafka.svc.cluster.local:9092
    standby.bootstrap.servers = kafka-kafka-standby-0.kafka-kafka-standby-headless.kafka.svc.cluster.local:9092,kafka-kafka-standby-1.kafka-kafka-standby-headless.kafka.svc.cluster.local:9092
    primary.security.protocol = SASL_PLAINTEXT
    primary.sasl.mechanism = PLAIN
    standby.security.protocol = SASL_PLAINTEXT
    standby.sasl.mechanism = PLAIN
    primary->standby.enabled = true
    primary->standby.topics = .*
    replication.policy.class = org.apache.kafka.connect.mirror.IdentityReplicationPolicy
  secretPropertiesExistingSecret: kafka-mm2
  secretPropertiesExistingSecretKey: mm2-secret.properties
```

## Multi-cluster example

```yaml
kafka:
  clusters:
    - name: primary
      clusterId: MkU3OEVBNTcwNTJENDM2Qk
    - name: standby
      clusterId: zlFiTJelTOuhnklFwLWixw

schemaRegistry:
  kafkaCluster: primary

topicInit:
  kafkaCluster: primary

kafbatUi:
  autoClusters: true
  clusters: []

mirrorMaker:
  enabled: true
  properties: |
    clusters = primary, standby

    primary.bootstrap.servers = kafka-kafka-primary-0.kafka-kafka-primary-headless.kafka.svc.cluster.local:9092,kafka-kafka-primary-1.kafka-kafka-primary-headless.kafka.svc.cluster.local:9092
    standby.bootstrap.servers = kafka-kafka-standby-0.kafka-kafka-standby-headless.kafka.svc.cluster.local:9092,kafka-kafka-standby-1.kafka-kafka-standby-headless.kafka.svc.cluster.local:9092

    primary.security.protocol = SASL_PLAINTEXT
    primary.sasl.mechanism = GSSAPI
    primary.sasl.kerberos.service.name = kafka
    primary.sasl.jaas.config = com.sun.security.auth.module.Krb5LoginModule required useKeyTab=true storeKey=true keyTab="/kerby/keytabs/mm2.keytab" principal="mm2/mm2.example.com@EXAMPLE.COM";

    standby.security.protocol = SASL_PLAINTEXT
    standby.sasl.mechanism = GSSAPI
    standby.sasl.kerberos.service.name = kafka
    standby.sasl.jaas.config = com.sun.security.auth.module.Krb5LoginModule required useKeyTab=true storeKey=true keyTab="/kerby/keytabs/mm2.keytab" principal="mm2/mm2.example.com@EXAMPLE.COM";

    primary->standby.enabled = true
    primary->standby.topics = .*
    replication.policy.class = org.apache.kafka.connect.mirror.IdentityReplicationPolicy
    replication.factor = 1
    checkpoints.topic.replication.factor = 1
    heartbeats.topic.replication.factor = 1
    offset-syncs.topic.replication.factor = 1
```
