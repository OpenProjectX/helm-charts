helm package common
helm package opendj
helm package tg-crawler

helm repo index . \
  --url https://github.com/OpenProjectX/helm-charts/releases/download/v0.1.0


#helm lint opendj
#
#helm plugin install  --verify=false https://github.com/chartmuseum/helm-push

helm repo add openprojectx https://openprojectx.github.io/helm-charts/

#helm install opendj OpenProjectX/opendj

