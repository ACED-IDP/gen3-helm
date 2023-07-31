all: help

update: ## Update from the local helm chart repository
	@helm dependency update ./helm/gen3
	
local: CONTEXT=rancher-desktop 
local: DEPLOY=local
local: check-context deploy ## Deploy the Local commons

development: CONTEXT=arn:aws:eks:us-west-2:119548034047:cluster/aced-commons-development
development: DEPLOY=development
development: check-context deploy zip ## Deploy the Development commons

staging: CONTEXT=arn:aws:eks:us-west-2:119548034047:cluster/aced-commons-staging
staging: DEPLOY=staging
staging: check-context deploy zip ## Deploy the Staging commons

production: CONTEXT=arn:aws:eks:us-west-2:119548034047:cluster/aced-commons-production
production: DEPLOY=production
production: check-context deploy zip ## Deploy the Production commons

context: ## Output the current Kubernetes context
	@echo "Current context: $(shell kubectl config current-context)"

clean: check-clean ## Delete all existing deployments, configmaps, and secrets
	@$(eval ACTUAL=$(shell kubectl config current-context))
	@$(eval DEPLOY=$(shell case $(ACTUAL) in \
		(rancher-desktop) echo "local";; \
		(*development) 		echo "development";; \
		(*staging) 				echo "staging";; \
		(*production) 		echo "production";; \
	esac))

	@read -p "Uninstall $(DEPLOY) deployment? [y/N]: " sure && \
		case "$$sure" in \
			[yY]) true;; \
			*) false;; \
		esac
	@echo "Uninstalling $(DEPLOY)"

	@-helm uninstall $(DEPLOY)
	@kubectl delete secrets --all
	@kubectl delete configmaps --all
	@kubectl delete jobs --all

deploy: check-context
	@[ $(shell readlink Secrets) == "Secrets.$(DEPLOY)" ] || \
		(printf "\033[1mUnexpected Secrets link\033[0m\n"; \
		 printf "\033[92mExpected Secrets:\033[0m Secrets.$(DEPLOY)\n"; \
		 printf "\033[93mActual Secrets:\033[0m   $(shell readlink Secrets)\n"; \
		 exit 1)

	@read -p "Deploy $(DEPLOY)? [y/N]: " sure && \
		case "$$sure" in \
			[yY]) true;; \
			*) false;; \
		esac

	@echo "Deploying $(DEPLOY)"
	@helm upgrade --install $(DEPLOY) ./helm/gen3 \
		-f Secrets/values.yaml \
		-f Secrets/user.yaml \
		-f Secrets/fence-config.yaml \
		-f Secrets/TLS/gen3-certs.yaml

check-context:
	@$(eval ACTUAL=$(shell kubectl config current-context))
	@[ $(ACTUAL) == $(CONTEXT) ] || \
		(printf "\033[1mUnexpected context\033[0m\n"; \
		 printf "\033[92mExpected context:\033[0m $(CONTEXT)\n"; \
		 printf "\033[93mActual context:\033[0m   $(ACTUAL)\n"; \
		 exit 1)

# Create a timestamped Secrets archive and copy to $HOME/OneDrive/ACED-deployments
zip: 
	@$(eval TIMESTAMP="$(DEPLOY)-$(shell date +"%Y-%m-%dT%H-%M-%S%z")")
	echo $(TIMESTAMP)
	@zip Secrets-$(TIMESTAMP).zip Secrets
	@cp Secrets-$(TIMESTAMP).zip $(HOME)/OneDrive/ACED-deployments

# https://gist.github.com/prwhite/8168133
help:	## Show this help message
	@grep -hE '^[A-Za-z0-9_ \-]*?:.*##.*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m\033[1m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: debug deploy clean check-clean zip help

