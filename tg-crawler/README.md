```shell
kubectl create namespace openprojectx

kubectl apply -f es-envoy.yaml

kubectl -n openprojectx create secret generic tg-crawler-secrets \
  --from-env-file=secrets.env

helm install tg-crawler ./ --namespace openprojectx -f values.yaml
helm --kubeconfig ~/.kube/gcp-k3s.yaml  install tg-crawler ./ --namespace openprojectx -f gcp-hk-values.yaml

helm --kubeconfig ~/.kube/gcp-k3s.yaml  template tg-crawler ./ --namespace openprojectx -f gcp-hk-values.yaml > tg-crawler-gcp-hk.yaml


helm upgrade tg-crawler ./ --namespace openprojectx -f values.yaml --force-conflicts
helm upgrade tg-crawler ./ --namespace openprojectx -f gcp-hk-values.yaml


helm uninstall tg-crawler   --namespace openprojectx  
helm --kubeconfig ~/.kube/gcp-k3s.yaml  uninstall tg-crawler   --namespace openprojectx  


  
```