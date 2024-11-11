.PHONY: build certs helm-vault helm-ingress-nginx helm deploy configure-vault install-vault hosts secrets-delete secrets rebuild deploy up clean clean-k8s clean-helm clean-images clean-certs clean-hosts clean-all
include token

# build backend api image
build:
	@docker build -f myservice/Dockerfile -t myservice:latest myservice/

# create certificate authority, sign requests, keys, server and client certificates
certs:
	@bash scripts/makecerts.sh

# install nginx ingress plugin using helm
helm-ingress-nginx:
	@helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx; \
	helm repo update;
	helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace


# install vault plugin using helm
helm-vault:
	@helm repo add hashicorp https://helm.releases.hashicorp.com; \
	 	helm repo update ; \
		helm install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "injector.enabled=true" \
  --set "server.dev.devRootToken=$(VAULT_TOKEN)" \
	--set "server.service.type=NodePort"  \
  --set "server.service.nodePort=30820"

# run all helm targets
helm: helm-ingress-nginx helm-vault
	@echo "Waiting for Vault pod to be ready..."
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault --timeout=120s
	@$(MAKE) configure-vault


# exec into vault pod and configure its policies and create secret
configure-vault:
	@bash scripts/setup_vault.sh

# run full vault install and configure
install-vault: k8secret helm-vault configure-vault

# this target creates entry for example domain in hosts file
hosts:
	@if ! grep -q "127.0.0.1 myservice.example.com" /etc/hosts; then \
		echo "I need sudo to add domain to hosts file"; \
	  echo "127.0.0.1 myservice.example.com" | sudo tee -a /etc/hosts; \
	else \
		echo "Domain is already in hosts file.Skipping..."; \
	fi

# generate certs and add them to k8s etcd
secrets: certs
	@kubectl delete secret myservice-tls -n default || true
	@kubectl create secret tls myservice-tls \
		--cert=certs/server.crt \
		--key=certs/server.key \
		--namespace=default
	@kubectl create secret generic myservice-ca \
		--from-file=ca.crt=certs/ca.crt \
		--namespace=default

# rebuild image and restart pod to pick it up
rebuild: build
	@kubectl delete pod -l app=myservice -n default

# deploy api to k8s
deploy:
	@kubectl apply -f k8s/myservice/

# delete k8s resources
clean-k8s:
	@echo "cleaning up Kubernetes resources..."
	@kubectl delete -f myservice/k8s.yaml || true
	@kubectl delete -n default deployment/myservice service/myservice ingress/myservice-ingress || true
	@kubectl delete -n default serviceaccount/myservice-sa || true
	@kubectl delete clusterrolebinding role-tokenreview-binding || true

# remove helm installations
clean-helm:
	@echo "cleaning up helm installations..."
	@helm uninstall ingress-nginx -n ingress-nginx || true
	@helm uninstall vault || true
	@kubectl delete namespace ingress-nginx || true

# remove docker image
clean-images:
	@echo "cleaning up docker images..."
	@docker rmi myservice:latest || true

# bring whole stack up
up: hosts build secrets helm
	@echo "waiting nginx to be ready..."
	@kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=120s || true
	@kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=admission-webhook \
		--timeout=120s || true
	@$(MAKE) deploy
	@echo "waiting for myservice pods to be ready..."
	@kubectl wait --for=condition=ready pod -l app=myservice --timeout=120s
	@echo "Setup complete!"

# remove everything
down: clean-k8s secrets-delete clean-helm clean-images
	@echo "cleanup done"
