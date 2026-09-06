#!/usr/bin/env bash
# Derruba TUDO que up.sh cria. Não deixa nada para trás — inclusive o bucket do
# state, que não é gerenciado pelo Terraform.
#
#   scripts/destroy.sh                      pede confirmação
#   scripts/destroy.sh --yes                sem perguntar
#   scripts/destroy.sh --keep-state-bucket  preserva só o bucket do tfstate
#
# Três coisas que um `terraform destroy` puro NÃO resolve, e por isso existem
# aqui: finalizers das Applications do Argo CD travam a deleção do namespace;
# Services type=LoadBalancer criam ELBs que o Terraform não conhece e cujas ENIs
# órfãs travam a deleção da VPC; e o bucket do state é criado por script.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

ASSUME_YES=0
KEEP_BUCKET=0
for a in "$@"; do
  case "$a" in
    --yes|-y) ASSUME_YES=1 ;;
    --keep-state-bucket) KEEP_BUCKET=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) fail "opção desconhecida: $a" ;;
  esac
done

step "Pré-requisitos"
require_tools terraform aws
require_creds
info "conta $ACCOUNT, região $REGION"

if [ "$ASSUME_YES" = 0 ]; then
  printf '\n    %sIsto apaga o cluster, os 3 bancos, o Redis, as filas, a tabela\n' "$C_WARN"
  printf '    DynamoDB e os 5 repositórios ECR com todas as imagens.%s\n' "$C_OFF"
  [ "$KEEP_BUCKET" = 0 ] && printf '    %sO bucket do tfstate também é apagado.%s\n' "$C_WARN" "$C_OFF"
  printf '\n    Digite %sdestruir%s para confirmar: ' "$C_ERR" "$C_OFF"
  read -r answer
  [ "$answer" = "destruir" ] || fail "cancelado"
fi

# ---------------------------------------------------------------------------
step "Limpeza dentro do cluster"
if kube_reachable; then
  # Finalizers das Applications travam o namespace argocd para sempre.
  for app in $(kubectl -n argocd get applications -o name 2>/dev/null || true); do
    kubectl -n argocd patch "$app" --type=merge \
      -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
  done
  kubectl -n argocd delete applications --all --timeout=60s >/dev/null 2>&1 || true

  # Cada Service LoadBalancer é um ELB que o Terraform não vê.
  LBSVC="$(kubectl get svc -A \
    -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' \
    2>/dev/null || true)"
  if [ -n "$LBSVC" ]; then
    for s in $LBSVC; do
      info "removendo Service LoadBalancer $s"
      kubectl -n "${s%%/*}" delete svc "${s##*/}" --timeout=120s >/dev/null 2>&1 || true
    done
    info "aguardando os ELBs saírem"
    for _ in $(seq 1 30); do
      n="$(aws elbv2 describe-load-balancers --query 'length(LoadBalancers)' --output text 2>/dev/null || echo 0)"
      c="$(aws elb describe-load-balancers --query 'length(LoadBalancerDescriptions)' --output text 2>/dev/null || echo 0)"
      [ "$n" = "0" ] && [ "$c" = "0" ] && break
      sleep 10
    done
  fi

  kubectl delete namespace toggle-master kaniko --timeout=120s >/dev/null 2>&1 || true
else
  info "cluster inacessível — nada a limpar por dentro"
fi

# ---------------------------------------------------------------------------
step "terraform destroy — platform"
if tf_init platform 2>/dev/null && tf_has_state platform; then
  tf platform destroy -auto-approve -input=false -no-color -var bootstrap_root_app=false \
    | tail -n 2 | sed 's/^/    /'
else
  info "sem state, pulando"
fi

step "terraform destroy — infra"
if tf_init infra 2>/dev/null && tf_has_state infra; then
  tf infra destroy -auto-approve -input=false -no-color | tail -n 2 | sed 's/^/    /'
  TF_OK=1
else
  info "sem state, pulando"
  TF_OK=1
fi

# ---------------------------------------------------------------------------
step "Varredura de órfãos"
for eip in $(aws ec2 describe-addresses \
    --filters "Name=tag:Project,Values=${PROJECT}" \
    --query 'Addresses[].AllocationId' --output text 2>/dev/null); do
  info "liberando EIP órfão $eip"
  aws ec2 release-address --allocation-id "$eip" >/dev/null 2>&1 || true
done
for lg in $(aws logs describe-log-groups --log-group-name-prefix "/aws/eks/${CLUSTER}" \
    --query 'logGroups[].logGroupName' --output text 2>/dev/null); do
  info "removendo log group $lg"
  aws logs delete-log-group --log-group-name "$lg" >/dev/null 2>&1 || true
done

# ---------------------------------------------------------------------------
if [ "$KEEP_BUCKET" = 0 ] && [ "${TF_OK:-0}" = 1 ]; then
  step "Bucket do state"
  if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
    # Bucket versionado: apagar objetos não basta, é preciso apagar cada
    # versão e cada delete marker.
    # Em lote: delete-objects apaga até 1000 por chamada. Apagar uma versão por
    # invocação do CLI levava ~20 min num state com 780 versões — o Terraform
    # grava uma versão por operação e isso cresce rápido.
    n=0
    pass=0
    while [ "$pass" -lt 200 ]; do
      pass=$((pass + 1))
      payload="$(aws s3api list-object-versions --bucket "$BUCKET" --max-keys 1000 \
        --query '{Objects: [Versions[].{Key:Key,VersionId:VersionId}, DeleteMarkers[].{Key:Key,VersionId:VersionId}][], Quiet: `true`}' \
        --output json 2>/dev/null || echo '{}')"
      case "$payload" in *'"Key"'*) ;; *) break ;; esac
      k="$(printf '%s' "$payload" | grep -c '"Key"')"
      # Sem o break aqui, uma falha de permissão vira laço infinito: a listagem
      # devolve as mesmas versões para sempre.
      if ! aws s3api delete-objects --bucket "$BUCKET" --delete "$payload" >/dev/null 2>&1; then
        warn "delete em lote falhou no passo $pass — interrompendo"
        break
      fi
      n=$((n + k))
    done
    [ "$pass" -lt 200 ] || warn "limite de passos atingido; pode ter sobrado objeto"
    aws s3api delete-bucket --bucket "$BUCKET" >/dev/null 2>&1 \
      && info "$BUCKET removido ($n versões apagadas)" \
      || warn "$BUCKET não pôde ser removido"
  else
    info "bucket já não existe"
  fi
elif [ "$KEEP_BUCKET" = 1 ]; then
  step "Bucket do state"
  info "$BUCKET preservado (--keep-state-bucket)"
fi

# ---------------------------------------------------------------------------
step "Verificação final"
LEFT=0
check() {
  local label="$1" value="$2"
  if [ -z "$value" ] || [ "$value" = "None" ] || [ "$value" = "0" ]; then
    printf '    %-16s %sok%s\n' "$label" "$C_OK" "$C_OFF"
  else
    printf '    %-16s %s%s%s\n' "$label" "$C_ERR" "$value" "$C_OFF"
    LEFT=1
  fi
}
check "EKS"        "$(aws eks list-clusters --query 'clusters' --output text 2>/dev/null | tr '\t' ' ')"
check "RDS"        "$(aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output text 2>/dev/null | tr '\t' ' ')"
check "ElastiCache" "$(aws elasticache describe-cache-clusters --query 'CacheClusters[].CacheClusterId' --output text 2>/dev/null | tr '\t' ' ')"
check "ECR"        "$(aws ecr describe-repositories --query 'repositories[].repositoryName' --output text 2>/dev/null | tr '\t' ' ')"
check "DynamoDB"   "$(aws dynamodb list-tables --query 'TableNames' --output text 2>/dev/null | tr '\t' ' ')"
check "SQS"        "$(aws sqs list-queues --query 'QueueUrls' --output text 2>/dev/null | tr '\t' ' ')"
check "VPC"        "$(aws ec2 describe-vpcs --filters 'Name=is-default,Values=false' --query 'Vpcs[].VpcId' --output text 2>/dev/null | tr '\t' ' ')"
check "NAT"        "$(aws ec2 describe-nat-gateways --filter 'Name=state,Values=available,pending' --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null | tr '\t' ' ')"
check "EIP"        "$(aws ec2 describe-addresses --query 'Addresses[].AllocationId' --output text 2>/dev/null | tr '\t' ' ')"
check "ELB"        "$(aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text 2>/dev/null | tr '\t' ' ')"
check "EC2"        "$(aws ec2 describe-instances --filters 'Name=instance-state-name,Values=running,pending,stopping,stopped' --query 'length(Reservations[].Instances[])' --output text 2>/dev/null)"
[ "$KEEP_BUCKET" = 1 ] || check "S3" "$(aws s3api list-buckets --query "Buckets[?starts_with(Name, '${PROJECT}')].Name" --output text 2>/dev/null | tr '\t' ' ')"

if [ "$LEFT" = 0 ]; then
  printf '\n    %sNada restou na conta.%s\n' "$C_OK" "$C_OFF"
else
  printf '\n    %sSobrou recurso — veja em vermelho acima.%s\n' "$C_ERR" "$C_OFF"
  exit 1
fi
