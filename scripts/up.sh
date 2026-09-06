#!/usr/bin/env bash
# Sobe a infraestrutura inteira, do zero até o cluster pronto.
#
#   scripts/up.sh                 infra + plataforma + Secret
#   scripts/up.sh --with-images   idem, e ainda builda as 5 imagens no cluster
#
# Idempotente: pode rodar de novo em cima de um ambiente já existente.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

WITH_IMAGES=0
for a in "$@"; do
  case "$a" in
    --with-images) WITH_IMAGES=1 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) fail "opção desconhecida: $a" ;;
  esac
done

step "Pré-requisitos"
require_tools terraform aws kubectl
require_creds
info "conta $ACCOUNT, região $REGION"

step "Bucket do state"
"$(dirname "${BASH_SOURCE[0]}")/create-state-bucket.sh" | sed 's/^/    /'

step "Infraestrutura (VPC, EKS, RDS, Redis, DynamoDB, SQS, ECR)"
info "leva de 20 a 25 minutos"
tf_init infra
tf infra apply -auto-approve -input=false -no-color | tail -n 3 | sed 's/^/    /'

step "kubeconfig"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" >/dev/null
kubectl wait --for=condition=Ready nodes --all --timeout=300s >/dev/null
info "$(kubectl get nodes --no-headers | wc -l) nós prontos"

step "Plataforma (ingress-nginx e Argo CD)"
tf_init platform
tf platform apply -auto-approve -input=false -no-color | tail -n 3 | sed 's/^/    /'

step "Secret com as credenciais geradas pelo Terraform"
umask 077
ENVFILE="$(mktemp)"
trap 'rm -f "$ENVFILE"' EXIT
tf infra output -raw secrets_env > "$ENVFILE"
kubectl create namespace toggle-master --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n toggle-master create secret generic toggle-master-secrets \
  --from-env-file="$ENVFILE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
info "toggle-master-secrets criado com $(grep -c '=' "$ENVFILE") chaves"
rm -f "$ENVFILE"; trap - EXIT

if [ "$WITH_IMAGES" = 1 ]; then
  "$(dirname "${BASH_SOURCE[0]}")/build-images.sh"
fi

step "Pronto"
info "Argo CD:  kubectl -n argocd port-forward svc/argocd-server 8080:80"
info "senha:    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
info "registry: $(tf infra output -raw ecr_registry_url)"
printf '\n    %sA stack custa ~US$ 0,35/h. Rode scripts/destroy.sh ao terminar.%s\n' "$C_WARN" "$C_OFF"
