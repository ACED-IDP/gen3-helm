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

# update dependencies
helm dependency update helm/gen3

# Start deployment 
helm upgrade --install local ./helm/gen3 -f values.yaml -f user.yaml -f fence-config.yaml -f Secrets/TLS/gen3-certs.yaml
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

```sh
kubectl delete configmap credentials
kubectl create configmap credentials --from-file credentials-templates
kubectl delete pod etl
kubectl apply -f etl.yaml
sleep 10
kubectl describe pod etl
kubectl exec --stdin --tty etl -- /bin/bash
```

## Add Minio k8s Pod

```sh
kubectl apply -f minio-dev.yaml

# namespace/minio-dev created
# pod/minio created

kubectl get pods -n minio-dev

# NAME    READY   STATUS    RESTARTS   AGE
# minio   1/1     Running   0          77s

kubectl describe pod/minio -n minio-dev
kubectl logs pod/minio -n minio-dev
```

## Add Minio Helm Chart

Adapted from the [Minio Operator documentation](https://github.com/minio/operator/tree/master/helm/operator).

First add the Minio Helm repo and install the chart into the minio-operator namespace:

```sh
helm repo add minio https://operator.min.io/

helm install --namespace minio-operator --create-namespace minio-operator minio/operator
```

Then create the Minio k8s secret:

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: console-sa-secret
  namespace: minio-operator
  annotations:
    kubernetes.io/service-account.name: console-sa
type: kubernetes.io/service-account-token
EOF
```

Get the JWT token For logging into the console:


```sh
kubectl -n minio-operator  get secret console-sa-secret -o jsonpath="{.data.token}" | base64 --decode
```

Then start the minio-operator which will open the console on port 9090 of localhost:

```sh
kubectl --namespace minio-operator port-forward svc/console 9090:9090
echo "Visit the Operator Console at http://127.0.0.1:9090"
```

Then log in to the Minio console with the JWT token from the previous step.

If the console is up and able to be logged into the we can move on to creating four node Minio tenant/cluster:

```sh
helm install --namespace tenant-ns --create-namespace tenant minio/tenant
```

Note: if `helm` or `kubectl` complain about not finding a release you can specify the namespace to target the resource of interes (e.g. `tenant` in the `tenant-ns` namespace):

```sh
kubectl describe tenant
# No resources found in default namespace.

kubectl describe tenant --namespace tenant-ns
# ...
# Events:
#   Type    Reason       Age   From            Message
#   ----    ------       ----  ----            -------
#   Normal  CSRCreated   12m   minio-operator  MinIO CSR Created
#   Normal  SvcCreated   11m   minio-operator  MinIO Service Created
#   Normal  SvcCreated   11m   minio-operator  Console Service Created

helm uninstall tenant
# Error: uninstall: Release not loaded: tenant: release: not found

helm uninstall tenant --namespace tenant-ns
# release "tenant" uninstalled
```

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

