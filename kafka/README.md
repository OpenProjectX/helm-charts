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
