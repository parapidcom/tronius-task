#!/bin/bash

set -e

source token

export VAULT_TOKEN=${VAULT_TOKEN:="tronius"}


# get the vault pod name
# loop to check every 5 seconds if the pod is running
while true; do
  VAULT_POD=$(kubectl get pods -l app.kubernetes.io/name=vault -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)

  # Check if VAULT_POD is non-empty and if its status is "Running"
  if [[ -n "$VAULT_POD" ]] && [[ $(kubectl get pod "$VAULT_POD" -o jsonpath="{.status.phase}") == "Running" ]]; then
    echo "Vault pod is running. Continue..."
    break
  else
    echo "Waiting for Vault pod to be in running state..."
  fi
  sleep 5
done

# exec into vault pod and execute commands
kubectl exec -it $VAULT_POD -- sh -c '
  export VAULT_TOKEN="'${VAULT_TOKEN}'"

  vault auth enable kubernetes

  vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc" \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    issuer="https://kubernetes.default.svc.cluster.local"

  vault policy write myservice - <<EOH
path "secret/data/myservice" {
  capabilities = ["read"]
}
EOH

  vault write auth/kubernetes/role/myservice \
    bound_service_account_names=myservice-sa \
    bound_service_account_namespaces=default \
    policies=myservice \
    ttl=1h

  # vault secrets enable -path=secret -version=2 kv || true -> I disabled this step as I can see it secret/ path is already created by default, can be uncommeted if it fails because of missing

  vault kv put secret/myservice \
    foo="bar" \
    rand="krneki"

  echo -e "\nVerifying configuration:"
  echo "1. Checking auth methods:"
  vault auth list

  echo -e "\n2. Checking myservice policy:"
  vault policy read myservice

  echo -e "\n3. Checking secrets:"
  vault kv get secret/myservice
'
