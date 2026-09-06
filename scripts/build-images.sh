#!/usr/bin/env bash
# Builda as 5 imagens e publica no ECR, usando kaniko DENTRO do cluster.
#
# Não precisa de Docker na máquina local — útil quando a virtualização está
# desabilitada e o Docker Desktop não roda. Depende do hop limit do IMDS estar
# em 2, o que o launch template do módulo eks garante.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

SERVICES="${SERVICES:-auth-service flag-service targeting-service evaluation-service analytics-service}"
GH_ORG="${GH_ORG:-FIAP-Teach-Challenge-2}"
ECR_PREFIX="${ECR_PREFIX:-togglemaster}"
KANIKO_IMAGE="${KANIKO_IMAGE:-gcr.io/kaniko-project/executor:v1.23.2}"

step "Pré-requisitos"
require_tools aws kubectl curl
require_creds
kube_reachable || fail "kubectl não alcança o cluster. Rode: aws eks update-kubeconfig --region $REGION --name $CLUSTER"
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
info "registry $REGISTRY"

step "Preparando o namespace"
kubectl create namespace kaniko --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n kaniko create configmap docker-config \
  --from-literal=config.json="{\"credHelpers\":{\"${REGISTRY}\":\"ecr-login\"}}" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

step "Disparando os builds"
kubectl -n kaniko delete jobs --all >/dev/null 2>&1 || true
for svc in $SERVICES; do
  sha="$(curl -fsSL "https://api.github.com/repos/${GH_ORG}/${svc}/commits/main" \
    | grep -m1 '"sha"' | cut -d'"' -f4)"
  [ -n "$sha" ] || fail "não consegui ler o commit de ${GH_ORG}/${svc}"
  info "${svc} main@${sha}"
  kubectl apply -f - >/dev/null <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: build-${svc}
  namespace: kaniko
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: kaniko
          image: ${KANIKO_IMAGE}
          args:
            - --context=git://github.com/${GH_ORG}/${svc}.git#refs/heads/main
            - --dockerfile=Dockerfile
            - --destination=${REGISTRY}/${ECR_PREFIX}/${svc}:${sha}
            - --cache=false
          env:
            - name: AWS_REGION
              value: ${REGION}
          volumeMounts:
            - name: docker-config
              mountPath: /kaniko/.docker
          resources:
            requests:
              cpu: 300m
              memory: 512Mi
            limits:
              memory: 2Gi
      volumes:
        - name: docker-config
          configMap:
            name: docker-config
EOF
done

step "Aguardando"
FAILED=0
for svc in $SERVICES; do
  printf '    %-20s ' "$svc"
  if kubectl -n kaniko wait --for=condition=complete "job/build-${svc}" --timeout=900s >/dev/null 2>&1; then
    printf '%sok%s\n' "$C_OK" "$C_OFF"
  else
    printf '%sfalhou%s\n' "$C_ERR" "$C_OFF"
    FAILED=1
  fi
done
[ "$FAILED" = 0 ] || fail "algum build falhou. Log: kubectl -n kaniko logs job/build-<serviço>"

step "Imagens publicadas"
for svc in $SERVICES; do
  printf '    %-20s %s\n' "$svc" \
    "$(aws ecr describe-images --repository-name "${ECR_PREFIX}/${svc}" \
       --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text 2>/dev/null)"
done
kubectl -n kaniko delete jobs --all >/dev/null 2>&1 || true
