```shell
kubectl create namespace openprojectx

kubectl -n openprojectx create secret generic tg-crawler-secrets \
  --from-env-file=secrets.env

helm install tg-crawler ./ --namespace openprojectx -f values.yaml

helm upgrade tg-crawler ./ --namespace openprojectx -f values.yaml

  
```