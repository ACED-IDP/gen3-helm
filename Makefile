# Include the debug flags for the 'debug' target only
# Will output out all Helm values to debug.yaml
install: DEBUG =
debug:   DEBUG = --debug --dry-run > debug.yaml

all: update install

# Delete all existing deployments, configmaps, and secrets
clean:	
	-helm uninstall local
	kubectl delete secrets --all
	kubectl delete configmaps --all

# Update from the local helm chart repository
update:
	helm dependency update ./helm/gen3
	

# Deploy the helm release
install debug:
	helm upgrade --install local ./helm/gen3 \
	-f Secrets/values.yaml \
	-f Secrets/user.yaml \
	-f Secrets/fence-config.yaml \
	-f Secrets/TLS/gen3-certs.yaml \
	$(DEBUG)

.PHONY: debug