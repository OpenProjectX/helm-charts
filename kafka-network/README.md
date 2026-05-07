# kafka-network

Network resources for an existing `kafka` chart release.

This chart owns resources whose lifecycle should be stable across Kafka pod upgrades:

- per-broker LoadBalancer Services
- Gateway API `HTTPRoute` and optional `TCPRoute`
- Istio native `VirtualService`, `DestinationRule`, `PeerAuthentication`, and `AuthorizationPolicy`

Use this when LoadBalancer IP stability matters. Reserve static IPs in the cloud provider, put them in this chart, and keep the Kafka workload chart focused on brokers and application components.

## Kafka chart values

When this chart owns the LoadBalancer Services, configure the Kafka chart like this:

```yaml
kafka:
  externalBrokerServices:
    enabled: true
    create: false
    autoDiscovery:
      enabled: true
```

With auto discovery enabled, brokers read the actual external address from the Service at startup. If you want fully static Kafka config instead, disable auto discovery and put the same stable addresses in the Kafka chart's `advertisedHosts`.

## Example

```yaml
kafka:
  releaseName: kafka
  chartName: kafka
  clusters:
    - name: primary
      replicaCount: 2
      externalBrokerServices:
        loadBalancerIPs:
          - 203.0.113.10
          - 203.0.113.11
    - name: standby
      replicaCount: 2
      externalBrokerServices:
        loadBalancerIPs:
          - 203.0.113.12
          - 203.0.113.13

gateway:
  enabled: true
  httpRoutes:
    ui:
      enabled: true
      hostnames:
        - ui.kafka.example.com
      port: 8080
    schemaRegistry:
      enabled: true
      hostnames:
        - schema.kafka.example.com
      port: 8085
```

Install order:

```bash
helm upgrade --install kafka-network ./kafka-network -n kafka -f ./kafka-network/values-gke-hk.yaml --create-namespace
helm upgrade --install kafka ./kafka -n kafka -f ./kafka/values-gke-hk.yaml
```

For an existing release where the `kafka` chart already owns the LoadBalancer Services, do not install this chart with the same Service names until ownership is migrated or the old Services are deleted. If IP stability matters, reserve the current IPs in the cloud provider first, then recreate the Services from this chart with those reserved IPs.
