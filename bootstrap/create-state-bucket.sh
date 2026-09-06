#!/usr/bin/env bash
# Cria o bucket S3 que guarda o tfstate. Idempotente.
# Por que script e não Terraform: ver "Decisões de implementação" no README.
set -euo pipefail

REGION="${REGION:-us-east-1}"
PROJECT="${PROJECT:-toggle-master}"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${PROJECT}-tfstate-${ACCOUNT}"

if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo ">> bucket $BUCKET já existe"
else
  echo ">> criando $BUCKET em $REGION"
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=$REGION" >/dev/null
  fi
fi

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'

echo
echo ">> pronto:"
echo "   terraform -chdir=infra    init -backend-config=\"bucket=$BUCKET\""
echo "   terraform -chdir=platform init -backend-config=\"bucket=$BUCKET\""
