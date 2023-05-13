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

    Copy the keys into the `gen3-certs.yaml` file.

    ```
    cp Secrets/TLS/gen3-certs-example.yaml Secrets/TLS/gen3-certs.yaml
    cat service.* >> Secrets/TLS/gen3-certs.yaml
    # Then match the key-key value formats in the file
    ```

## Deploy

```sh
# Clone gen3-helm 
git clone https://github.com/ACED-IDP/gen3-helm
git checkout feature/etl

# uninstall previous version
helm uninstall local
# update dependencies
helm dependency update helm/gen3

# Start deployment 
helm upgrade --install local ./helm/gen3 -f values.yaml -f user.yaml -f fence-config.yaml -f Secrets/TLS/gen3-certs.yaml

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
kubectl create secret tls gen3-certs --key=Secrets/TLS/service.key --cert=Secrets/TLS/service.crt

```

## Increase Elasticsearch Memory

As referenced in the [Gen3 developer docs](gen3_developer_environments.md#elasticsearch-error), Elasticsearch may output an error regarding too low of `max virtual memory` --

```
ERROR: [1] bootstrap checks failed
[1]: max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
```

To fix this we'll open a shell into the Rancher Desktop node and update the required memory fields -- 

```sh
rdctl shell

sudo sysctl -w vm.max_map_count=262144
sudo sh -c 'echo "vm.max_map_count=262144" >> /etc/sysctl.conf'

sysctl vm.max_map_count
# vm.max_map_count = 262144
```

## Increase Elasticsearch Memory

As referenced in the [Gen3 developer docs](gen3_developer_environments.md#elasticsearch-error), Elasticsearch may output an error regarding too low of `max virtual memory` --

```
ERROR: [1] bootstrap checks failed
[1]: max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
```

To fix this we'll open a shell into the Rancher Desktop node and update the required memory fields -- 

```sh
rdctl shell

sudo sysctl -w vm.max_map_count=262144
sudo sh -c 'echo "vm.max_map_count=262144" >> /etc/sysctl.conf'

sysctl vm.max_map_count
# vm.max_map_count = 262144
```


## Add ETL Pod

> Login to browser first, download credentials.json to Secrets/credentials.json

```sh
kubectl delete configmap credentials
kubectl create configmap credentials --from-file Secrets
kubectl delete pod etl
kubectl apply -f etl.yaml
sleep 10
# kubectl describe pod etl
kubectl exec --stdin --tty etl -- /bin/bash
```

## Bucket setup

> Unlike our compose services environment, where docker-compose was responsible for Gen3 and S3 (minio) configurations,  our k8s environment only has responsibility for Gen3 services and dependencies.   S3, whether AWS or Minio based is handled externally.

### Current staging setup

* OHSU - minio setup documented [here](https://ohsuitg-my.sharepoint.com/:t:/r/personal/walsbr_ohsu_edu/Documents/aced-1-minio.md?csf=1&web=1&e=iL5PmW)

* ucl, manchester, stanford

  * create buckets
  ![image](https://user-images.githubusercontent.com/47808/230643703-358ccacc-e974-4140-b0e6-7f080b90d484.png)

  * grant permissions to a AWS IAM user representing fence.
  ![image](https://user-images.githubusercontent.com/47808/230643891-df980b9c-eddf-45c4-93ed-7dff2c27cb34.png)

  * see fence-config.yaml:
     * `AWS_CREDENTIALS: {}`  aws_access_key_id, aws_secret_access_key
     * `S3_BUCKETS: {}`  bucket_name, cred, region






## Helpful Command

### Listing Secrets

```sh
kubectl get pods -o json | jq '.items[].spec.containers[].env[]?.valueFrom.secretKeyRef.name' | grep -v null | sort | uniq
```

### Counting pods neither Running or Completed

```sh
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed  | grep -v NAMES | wc -l
```

### Manually change SSL certificate

The SSL certificate and key file are automatically handled by the `Secrets/TLS/gen3-certs.yaml` and invoked in the `helm upgrade` command. However if you wish change the certificate or key for any reason simply delete the `gen3-certs` secret and recreate it with the `crt` and `key` file you wish to use:

```sh
kubectl delete secrets gen3-certs
kubectl create secret tls gen3-certs --cert=Secrets/TLS/service.crt --key=Secrets/TLS/service.key
```
### TODO - Create env varaiables instead of files in etl.yaml 

```sh

export PGDB=`cat /creds/sheepdog-creds/database`
export PGPASSWORD=`cat /creds/sheepdog-creds/password`
export PGUSER=`cat /creds/sheepdog-creds/username`
export PGHOST=`cat /creds/sheepdog-creds/host`
export DBREADY=`cat /creds/sheepdog-creds/dbcreated`
export PGPORT=`cat /creds/sheepdog-creds/port`

echo e.g. Connecting $PGUSER:$PGPASSWORD@$PGHOST:$PGPORT//$PGDB if $DBREADY  
```

