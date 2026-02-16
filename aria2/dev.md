```shell

kubectl -n it apply -f /data/Git/openprojectx-helm-charts/aria2/aria2-configmap.yaml

helm dependency update /data/Git/openprojectx-helm-charts/aria2  
helm template /data/Git/openprojectx-helm-charts/aria2  

helm install aria2 /data/Git/openprojectx-helm-charts/aria2  --namespace it


helm upgrade aria2  /data/Git/openprojectx-helm-charts/aria2  --namespace it

helm uninstall aria2  --namespace it

```