# Creating and Using Gen3 Certs in Helm

In this directory we have a `service.crt` and `service.key` file that together make up the SSL certification used for our site (https://aced-training.compbio.ohsu.edu for development purposes). These files can then be plugged into the `gen3-certs.yaml` file and included in subsequent `helm upgrade` commands.

## 1. Add the certificate and key values

```yaml
global:
  tls:
    cert: |
      <service.crt>
    key: |
      <service.key>
```

*Note*: This `tls.cert` and `tls.key` configuration will be passed by Helm into `helm/revproxy/templates/tls.yaml` and must match the key-value format found in that file.

## 2. Use the new yaml file in Helm

```sh
helm upgrade --install local ./helm/gen3 -f values.yaml -f user.yaml -f fence-config.yaml -f Secrets/TLS/gen3-certs.yaml
```
