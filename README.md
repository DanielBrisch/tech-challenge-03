# ToggleMaster — Infraestrutura AWS (Terraform)

Infraestrutura como código do **ToggleMaster**, projeto de feature flags do Tech
Challenge Fase 3 da FIAP. Provisiona tudo que os 5 microsserviços precisam num
cluster EKS, num ambiente **AWS Academy Learner Lab**.

Os manifestos Kubernetes e a camada de GitOps ficam em outro repositório:
[`FIAP-Teach-Challenge-2/toggle-master-infra`](https://github.com/FIAP-Teach-Challenge-2/toggle-master-infra).
Este projeto cria a infraestrutura e instala o Argo CD — daí em diante quem faz
o deploy é o Argo CD, a partir do Git.

```
├── bootstrap/   ①  script que cria o bucket S3 do backend remoto
├── infra/       ②  VPC · EKS · 3 RDS · Redis · DynamoDB · SQS · ECR
├── platform/    ③  ingress-nginx · Argo CD
└── modules/
    ├── networking/   VPC, subnets, IGW, NAT, route tables
    ├── eks/          cluster + node group + add-on metrics-server
    ├── rds/          uma instância PostgreSQL (instanciado 3×)
    ├── elasticache/  Redis
    ├── dynamodb/     tabela de eventos
    ├── sqs/          fila + dead-letter queue
    ├── ecr/          5 repositórios de imagem
    └── argocd/       Argo CD + App of Apps
```

`infra` e `platform` são roots separados por um motivo técnico, não estético:
configurar o provider `helm` a partir de outputs de um cluster que ainda não
existe deixa o primeiro `plan` indeterminado. Separando, o `platform` lê o
cluster por data source, que já existe quando ele roda.

---

## Pré-requisitos

```bash
winget install -e --id Hashicorp.Terraform --id Amazon.AWSCLI --id Kubernetes.kubectl --id Helm.Helm
```

Terraform **1.11+**: os dois `backend.tf` usam `use_lockfile` (lock nativo no
S3, sem tabela DynamoDB), que só é GA a partir dessa versão.

Credenciais do Learner Lab: no painel do lab, **AWS Details → AWS CLI → Show**,
e cole o bloco em `~/.aws/credentials`. Elas expiram ao fim de cada sessão —
quando o Terraform responder `ExpiredToken`, é isso. Confirme com:

```bash
aws sts get-caller-identity
```

---

## ① Backend remoto

O `terraform.tfstate` não pode ficar local (requisito do enunciado). O bucket que
o guarda é criado por um script, e não por Terraform, por dois motivos:

1. O backend precisa existir **antes** do primeiro `terraform init` que o usa —
   o clássico ovo e galinha do bootstrap.
2. No AWS Academy o recurso `aws_s3_bucket` é inutilizável: o provider chama
   `s3:GetBucketObjectLockConfiguration` em toda leitura, e o SCP do laboratório
   nega essa ação explicitamente. As demais chamadas de S3 são permitidas.

```bash
bash bootstrap/create-state-bucket.sh
```

O nome sai como `toggle-master-tfstate-<account-id>` — único globalmente e
estável entre sessões do lab. O script é idempotente. O bucket **sobrevive ao
End Lab** e custa centavos.

## ② Infraestrutura

```bash
cd infra
terraform init -backend-config="bucket=toggle-master-tfstate-<account-id>"
terraform plan
terraform apply
```

**20 a 25 minutos** — o control plane do EKS sozinho gasta uns 10.

| Recurso | Detalhe |
|---|---|
| VPC | `10.0.0.0/16`, 2 AZs, subnet pública e privada em cada, 1 NAT Gateway |
| EKS | Kubernetes 1.34, node group gerenciado com 2× `t3.medium` |
| RDS | 3× PostgreSQL 16 `db.t3.micro` — `auth_db`, `flags_db`, `targeting_db` |
| ElastiCache | Redis 7.1, nó único `cache.t3.micro` |
| DynamoDB | `ToggleMasterAnalytics`, PK `event_id`, sob demanda |
| SQS | `toggle-master-evaluations` + dead-letter queue |
| ECR | 5 repositórios, tags **imutáveis**, scan on push |

```bash
aws eks update-kubeconfig --region us-east-1 --name toggle-master-eks
kubectl get nodes
```

### AWS Academy

Nenhuma IAM Role ou Policy é criada. A `LabRole` existente é importada por data
source e associada ao cluster e ao node group, como o enunciado exige:

```hcl
data "aws_iam_role" "lab" {
  name = var.lab_role_name          # "LabRole"
}
```

## ③ Plataforma

```bash
cd ../platform
terraform init -backend-config="bucket=toggle-master-tfstate-<account-id>"
terraform apply
```

Instala o **ingress-nginx** (que provisiona o NLB) e o **Argo CD**, já
registrando o App of Apps. Daí em diante o Argo CD assume.

```bash
terraform output -raw argocd_admin_password_command   # copie e rode
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

## ④ Criar o Secret

O Terraform gerou as senhas; este passo entrega os valores ao cluster sem
ninguém copiar endpoint à mão:

```bash
terraform -chdir=infra output -raw secrets_env > secrets.local.env
kubectl create namespace toggle-master
kubectl -n toggle-master create secret generic toggle-master-secrets \
  --from-env-file=secrets.local.env
rm secrets.local.env
```

`secrets.local.env` está no `.gitignore`.

---

## Decisões de implementação

Sete pontos do código que parecem estranhos e não são. Todos vieram de erro real
neste ambiente, não de preferência de estilo.

**1. O node group usa launch template só por causa do IMDS.**
Um managed node group nasce com `httpPutResponseHopLimit = 1`. Um pod está a um
salto de rede a mais que o kubelet, então com `1` **nenhum pod alcança o IMDS**:
`analytics-service` e `evaluation-service` não obtêm a credencial da `LabRole` e
falham ao falar com SQS e DynamoDB. O sintoma é timeout genérico de credencial,
que não aponta para a causa. Não dá para ajustar isso direto no
`aws_eks_node_group` — exige launch template. **Não remova o launch template.**

**2. RDS e ElastiCache autorizam o CIDR da VPC, não um security group.**
`vpc_config.security_group_ids` do `aws_eks_cluster` anexa SGs às ENIs do
**control plane**, não aos nós. Um managed node group sem launch template recebe
o *cluster security group* que o EKS cria sozinho. Autorizar um SG criado à mão
resulta em pods em CrashLoop com timeout de conexão — parecendo bug de
aplicação. Referenciar `cluster_security_group_id` funcionaria, mas criaria
dependência do RDS no cluster pronto e serializaria o apply (~9 min a mais). As
instâncias estão em subnet privada com `publicly_accessible = false`.

**3. As subnets levam a tag `kubernetes.io/cluster/<nome>`.**
O cloud-controller-manager legado — que é quem atende `type: LoadBalancer`, já
que o AWS Load Balancer Controller exige IRSA, indisponível no Academy — usa
essa tag **e** a de `role/elb` para descobrir subnet. Faltando a de cluster, o
`EXTERNAL-IP` do Service pode ficar `<pending>` para sempre.

**4. O bucket do state é criado por script, não por Terraform.**
Dois motivos: o backend precisa existir antes do `init` que o usa, e no Academy
o recurso `aws_s3_bucket` é inutilizável — o provider chama
`s3:GetBucketObjectLockConfiguration` em toda leitura e o SCP do laboratório
nega essa ação. As demais chamadas de S3 são permitidas.

**5. `infra` e `platform` são roots separados.**
Configurar o provider `helm` a partir de outputs de um cluster que ainda não
existe deixa o endpoint desconhecido no `plan`, e o primeiro `apply` falha.
Separando, o `platform` lê o cluster por data source.

**6. O provider `helm` autentica com `exec`, não com `aws_eks_cluster_auth`.**
Aquele token é estático e vale 15 minutos, gerados no `plan`. O `platform` tem
dois `helm_release` com timeout de 15 min cada, e o ingress-nginx espera o NLB
provisionar — o segundo release começaria com o token vencido e falharia com
`Unauthorized`. O `exec` renova a cada invocação.

**7. O módulo `argocd` faz dois `helm_release`.**
As CRDs do Argo CD ficam em `templates/crds` do chart oficial, e não no
diretório `crds/`, então só existem na API durante a instalação. Um
`Application` declarado no mesmo release falha em cluster novo com
`no matches for kind Application`, porque o Helm resolve todos os kinds antes de
criar qualquer recurso. O segundo release, com `depends_on`, roda depois.

---

## Custo e destruição

Rodando 24h, o conjunto fica em torno de **US$ 8,45/dia** (≈ US$ 0,35/h): EKS
US$ 0,10/h, NAT Gateway, NLB, 3 RDS, Redis e os nós. Com US$ 50 de crédito são
**~142 horas**. Deixar ligado num fim de semana queima metade.

**Bloco permanente** (~US$ 0,10/mês, não destrua): bucket do tfstate, 5 ECR,
DynamoDB e SQS. Preserva imagens e state entre sessões.

```bash
terraform -chdir=infra apply -target=module.ecr -target=module.dynamodb -target=module.sqs
```

**Bloco efêmero** (US$ 0,35/h, destrua a cada sessão): VPC/NAT, EKS, nós, RDS,
Redis e NLB.

**A ordem de destruição importa:**

```bash
# 1. as Applications primeiro — os finalizers travam a deleção do namespace argocd
kubectl -n argocd delete applications --all

# 2. o platform, que remove o NLB
terraform -chdir=platform destroy

# 3. só então a infra
terraform -chdir=infra destroy
```

Destruir `infra` antes de `platform` deixa o state do platform impossível de
limpar, e o NLB órfão bloqueia o delete da VPC. **Nunca clique em End Lab sem
destruir antes** — End Lab dá falsa sensação de segurança: ele para EC2, mas
EKS e RDS continuam faturando.

---

## Solução de problemas

| Erro | O que é |
|---|---|
| `ExpiredToken` / `InvalidClientTokenId` | Sessão do lab expirou. **Start Lab** e recole `~/.aws/credentials` |
| `AccessDenied` em `iam:CreateRole` | Algo tentando criar role. No Academy só a `LabRole` é utilizável |
| `KMSKeyNotAccessibleFault` no RDS | O lab bloqueou KMS. Rode com `-var db_storage_encrypted=false` |
| `unsupported Kubernetes version` | Ajuste `cluster_version` (`aws eks describe-cluster-versions`) |
| `Unsupported instance type` | O lab limita os tipos. Tente `t3.small` |
| Pods em CrashLoop com timeout de conexão | Confira em que SG e CIDR os nós estão: `aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=toggle-master-eks" --query 'Reservations[].Instances[].SecurityGroups[].GroupId'` |
| `EXTERNAL-IP` do ingress em `<pending>` | Tags `kubernetes.io/cluster/<nome>` faltando nas subnets públicas |
| `AccessDenied` em `s3:GetBucketObjectLockConfiguration` | SCP do lab. Por isso o bucket do state é criado por script, não por `aws_s3_bucket` |
| `destroy` do `infra` travado na VPC | Rode o `destroy` do `platform` antes, para remover o NLB |
