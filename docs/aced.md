# Instructions for ACED Gen3 Deployment

## Install Rancher

Install Rancher Desktop from [Github Releases page](https://github.com/rancher-sandbox/rancher-desktop/releases/latest)

See docs/gen3_developer_environments.md regarding setting vm.max_map_count.

Note: after restarting rancher desktop, you will need to ensure this value is still set.

```
echo 'sudo sysctl -p' | rdctl shell
```

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


## Aced specific files:

* gitops.json - Controls windmill UI configuration - see values.yaml
  Gitops values are encoded as a json string under portal.gitops.json
  ```
portal:
...  
# -- (map) GitOps configuration for portal
  gitops:
    # -- (string) multiline string - gitops.json
    json: |

  ```

* fence-config.yaml - Authentication config. Same as legacy compose services file except addition of header
    ```
    fence:
    FENCE_CONFIG:
        APP_NAME:
        ...
    ```
* user.yaml - Authorization config. Same as legacy compose services file except addition of header, note contents are a yaml string
    ```
    fence:
    USER_YAML: |
        ...
    ```

* certs
    *See [OneDrive](https://ohsuitg-my.sharepoint.com/:f:/r/personal/walsbr_ohsu_edu/Documents/compbio-tls?csf=1&web=1&e=7oFdxd)*

    Copy the keys into the revproxy volume.

    ```
    cp service.* helm/revproxy/ssl
    ```


## Deploy


```sh
# Clone gen3-helm 
git clone https://github.com/ACED-IDP/gen3-helm
git checkout feature/etl

# update dependencies
helm dependency update helm/gen3

# Start deployment 
helm upgrade --install local ./helm/gen3 -f values.yaml -f fence-config.yaml -f user.yaml --set manifestservice.enabled=false

```

## Add SSL Certs to ingress

Replace the tls.crt and tls.key with the contents of  service-base64.crt, service-base64.key.

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
kubectl delete configmap credentials
kubectl create configmap credentials --from-file credentials-templates
kubectl delete pod etl
kubectl apply -f etl.yaml
sleep 10
kubectl describe pod etl
kubectl exec --stdin --tty etl -- /bin/bash
```


## Helpful Command

### Listing Secrets

```sh
kubectl get pods -o json | jq '.items[].spec.containers[].env[]?.valueFrom.secretKeyRef.name' | grep -v null | sort | uniq
```

#### Counting pods neither Running or Completed

```sh
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed  | grep -v NAMES | wc -l
```