```shell
kubectl create ns openprojectx
kubectl -n openprojectx create secret generic tg-crawler-secrets \
  --from-env-file=secrets.env
  
  
kubectl -n openprojectx create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=$GHCR_USER \
  --docker-password=$GHCR_TOKEN \
  --docker-email=$$GHCR_EMAIL
```

```shell
kubectl --kubeconfig ~/.kube/gcp-k3s.yaml get nodes
kubectl --kubeconfig ~/.kube/gcp-k3s.yaml  create ns openprojectx
kubectl --kubeconfig ~/.kube/gcp-k3s.yaml -n openprojectx create secret generic tg-crawler-secrets \
  --from-env-file=secrets.env
  
  
kubectl --kubeconfig ~/.kube/gcp-k3s.yaml -n openprojectx create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=$GHCR_USER \
  --docker-password=$GHCR_TOKEN \
  --docker-email$$GHCR_EMAIL
```