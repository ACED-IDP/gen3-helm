# Instructions for ACED Gen3 Deployment

## Install Rancher

Install Rancher Desktop from [Github Releases page](https://github.com/rancher-sandbox/rancher-desktop/releases/latest)

## Install Kubernetes

```sh
brew install kubectl
```

## Install Helm

```sh
brew install helm
helm repo add gen3 https://helm.gen3.org
helm repo update
```

## Add SSL Certs

```sh
cat service.crt | base64 > service-base64.crt
cat service.key | base64 > service-base64.key
KUBE_EDITOR="code -w" kubectl edit secrets gen3-certs
```

### Alternate Method

```sh
kubectl delete secrets gen3-certs
kubectl apply -f secret.yaml
```

## Add ETL Pod

```sh
kubectl create configmap credentials --from-file credentials-templates
kubectl apply -f etl.yaml
kubectl exec --stdin --tty etl -- /bin/bash
kubectl describe pod etl
```

## Deploy

```sh
Clone gen3-helm — git clone https://github.com/ACED-IDP/gen3-helm
git checkout feature/etl
Start deployment — helm upgrade --install local gen3/gen3 -f values.yaml -f user.yaml -f fence-config.yaml
helm upgrade --install local gen3/gen3 -f values.yaml --set manifestservice.enabled=false
```

## Helpful Command

### Listing Secrets

```sh
kubectl get pods -o json | jq '.items[].spec.containers[].env[]?.valueFrom.secretKeyRef.name' | grep -v null | sort | uniq
```