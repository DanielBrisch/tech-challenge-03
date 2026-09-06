#!/usr/bin/env bash
# Funções compartilhadas por up.sh e destroy.sh.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGION="${REGION:-us-east-1}"
PROJECT="${PROJECT:-toggle-master}"
CLUSTER="${CLUSTER:-${PROJECT}-eks}"

C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'

step() { printf '\n%s==>%s %s\n' "$C_OK" "$C_OFF" "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    %s%s%s\n' "$C_WARN" "$*" "$C_OFF"; }
fail() { printf '\n%serro:%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

require_tools() {
  local missing=()
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
  [ ${#missing[@]} -eq 0 ] || fail "faltando no PATH: ${missing[*]}"
}

require_creds() {
  ACCOUNT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" \
    || fail "credenciais AWS inválidas ou expiradas. No painel do lab: AWS Details -> AWS CLI, e cole em ~/.aws/credentials"
  export ACCOUNT
  BUCKET="${PROJECT}-tfstate-${ACCOUNT}"
  export BUCKET
}

tf() { terraform -chdir="$ROOT/$1" "${@:2}"; }

tf_init() {
  local dir="$1"
  tf "$dir" init -input=false -no-color -reconfigure \
    -backend-config="bucket=${BUCKET}" >/dev/null \
    || fail "terraform init falhou em $dir"
}

# true se o root tem state com pelo menos um recurso
tf_has_state() {
  local n
  n="$(tf "$1" state list 2>/dev/null | wc -l)"
  [ "${n:-0}" -gt 0 ]
}

kube_reachable() { kubectl cluster-info >/dev/null 2>&1; }
