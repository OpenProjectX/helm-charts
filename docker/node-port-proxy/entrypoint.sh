#!/bin/sh
set -xe


SERVICE_NAME=${TARGET_SERVICE_NAME}
SERVICE_NAMESPACE=${TARGET_SERVICE_NAMESPACE}
SERVICE_PORT=${TARGET_SERVICE_PORT}

echo "Detecting NodePort for ${SERVICE_NAMESPACE}/${SERVICE_NAME} port ${SERVICE_PORT}"

NODEPORT=$(kubectl -n ${SERVICE_NAMESPACE} \
  get svc ${SERVICE_NAME} \
  -o jsonpath="{.spec.ports[?(@.port==${SERVICE_PORT})].nodePort}")

if [ -z "$NODEPORT" ]; then
  echo "Failed to detect NodePort"
  exit 1
fi

echo "Detected NodePort: $NODEPORT"

cat <<EOF > /usr/local/etc/haproxy/haproxy.cfg
global
    maxconn 2000
    daemon

defaults
    mode tcp
    timeout connect 5s
    timeout client  60s
    timeout server  60s

frontend https_front
    bind *:443
    default_backend istio_nodeport

backend istio_nodeport
    server local 127.0.0.1:${NODEPORT}
EOF

exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg -db