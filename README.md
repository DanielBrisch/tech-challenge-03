# ToggleMaster — Infraestrutura AWS (Terraform)

Tech Challenge Fase 3 da FIAP, **completo**: infraestrutura como código,
pipeline de CI com DevSecOps e entrega contínua por GitOps, para os 5
microsserviços do **ToggleMaster** (um sistema de feature flags) num cluster
EKS, em ambiente **AWS Academy Learner Lab**.

| Seção do enunciado | Onde está |
|---|---|
| 1 · Infraestrutura como Código | `infra/`, `platform/`, `modules/` |
| 2 · CI & DevSecOps | `.github/workflows/reusable-ci-*.yml` + `service-ci/` |
| 3 · Entrega Contínua & GitOps | `k8s/`, `argocd/`, `.github/workflows/gitops-bump.yml` |

```
├── scripts/
│   ├── up.sh                    sobe tudo, do zero ao cluster pronto
│   ├── destroy.sh               derruba tudo, sem deixar nada
│   ├── build-images.sh          builda as 5 imagens no cluster (kaniko)
│   └── create-state-bucket.sh   bucket S3 do backend remoto
├── k8s/         ③  manifestos: platform (compartilhados) + apps/<serviço>
├── argocd/      ③  App of Apps + as 6 Applications
├── service-ci/  ②  o ci.yml de cada serviço, para copiar nos 5 repositórios
├── .github/workflows/
│   ├── reusable-ci-go.yml       ②  lint · testes · SAST · SCA · Docker · ECR
│   ├── reusable-ci-python.yml   ②  idem, para os 3 serviços Flask
│   └── gitops-bump.yml          ③  troca a tag da imagem e commita
├── infra/       ①  VPC · EKS · 3 RDS · Redis · DynamoDB · SQS · ECR
├── platform/    ①  ingress-nginx · Argo CD
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

## Subir

```bash
scripts/up.sh                 # infra + plataforma + Secret
scripts/up.sh --with-images   # idem, e ainda builda as 5 imagens no cluster
```

Leva de 25 a 35 minutos, quase tudo esperando o control plane do EKS e as 3
instâncias RDS. O script é idempotente — pode rodar de novo sobre um ambiente
já existente.

Em ordem, ele: cria o bucket do state, aplica `infra/`, configura o `kubeconfig`
e espera os nós ficarem `Ready`, aplica `platform/`, e cria o Secret
`toggle-master-secrets` a partir das senhas que o próprio Terraform gerou — sem
ninguém copiar endpoint à mão.

| Recurso | Detalhe |
|---|---|
| VPC | `10.0.0.0/16`, 2 AZs, subnet pública e privada em cada, 1 NAT Gateway |
| EKS | Kubernetes 1.34, node group gerenciado com 2× `t3.medium` |
| RDS | 3× PostgreSQL 16 `db.t3.micro` — `auth_db`, `flags_db`, `targeting_db` |
| ElastiCache | Redis 7.1, nó único `cache.t3.micro` |
| DynamoDB | `ToggleMasterAnalytics`, PK `event_id`, sob demanda |
| SQS | `toggle-master-evaluations` + dead-letter queue |
| ECR | 5 repositórios, tags **imutáveis**, scan on push |

Ao final:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### Imagens sem Docker local

`scripts/build-images.sh` clona os 5 repositórios e builda **dentro do cluster**
com kaniko, publicando no ECR. Não exige Docker na máquina — o que resolve o
caso de a virtualização estar desabilitada e o Docker Desktop não subir.

### Passo a passo manual

Se preferir rodar na mão, é o que o `up.sh` faz:

```bash
scripts/create-state-bucket.sh                       # imprime o nome do bucket
terraform -chdir=infra    init -backend-config="bucket=<nome>"
terraform -chdir=infra    apply
aws eks update-kubeconfig --region us-east-1 --name toggle-master-eks
terraform -chdir=platform init -backend-config="bucket=<nome>"
terraform -chdir=platform apply
terraform -chdir=infra output -raw secrets_env > secrets.local.env
kubectl create namespace toggle-master
kubectl -n toggle-master create secret generic toggle-master-secrets --from-env-file=secrets.local.env
rm secrets.local.env
```

### AWS Academy

Nenhuma IAM Role ou Policy é criada. A `LabRole` existente é importada por data
source e associada ao cluster e ao node group, como o ambiente exige:

```hcl
data "aws_iam_role" "lab" {
  name = var.lab_role_name          # "LabRole"
}
```

## ② CI & DevSecOps

Toda a lógica vive em dois workflows reutilizáveis aqui — um para Go, um para
Python. Cada repositório de serviço só carrega um `ci.yml` de 14 linhas, que
está pronto em `service-ci/<serviço>/ci.yml`.

Como o código dos 5 serviços fica na organização da faculdade, este projeto usa
**forks pessoais** (`DanielBrisch/<serviço>`). Copie o `ci.yml` correspondente
para `.github/workflows/` de cada fork.

O pipeline roda a cada push e PR na `main`:

| Estágio | Go | Python |
|---|---|---|
| Build e testes | `go build` + `go test -race` com cobertura | `compileall` + `pytest` |
| Lint | golangci-lint | ruff |
| SAST | gosec (`-severity high`) | bandit (`-ll -ii`) |
| SCA | Trivy fs | Trivy fs |
| Segredos | Trivy secret | Trivy secret |
| Imagem | build → Trivy image → push no ECR | idem |

**Regra de bloqueio:** vulnerabilidade `CRITICAL` reprova o pipeline, tanto nas
dependências quanto na imagem. `HIGH` sai como relatório na aba de resumo, sem
bloquear. Uso `--ignore-unfixed` porque CVE sem correção publicada não tem ação
possível — reprovar por ela só ensina o time a ignorar o gate.

Os gates de SAST e SCA são jobs com thresholds independentes de propósito:
assim uma CVE nova numa dependência não mascara um problema no código-fonte,
nem o contrário.

O push só acontece em `push` na `main` — em Pull Request o pipeline roda até os
scans e para aí.

## ③ Entrega Contínua & GitOps

```
k8s/
├── platform/          namespace · configmap · ingress · hpa · jobs de init
└── apps/<serviço>/    deployment + service + kustomization
argocd/
├── root-app.yaml      App of Apps — o único manifesto aplicado à mão
└── applications/      as 6 Applications
```

São **6 Applications**: uma por microsserviço, mais uma para os recursos
compartilhados. Cada serviço vê só o seu diretório, então um manifesto quebrado
não derruba os outros quatro. Todas com `automated`, `prune` e `selfHeal` — o
Git é a fonte da verdade e alteração manual no cluster é desfeita sozinha.

O elo com o CI é o `gitops-bump.yml`. No fim do pipeline, ele recebe serviço,
imagem e tag, roda `kustomize edit set image` no `kustomization.yaml` daquele
serviço, valida o build e commita. O Argo CD detecta em até 30 segundos.

**Nenhum pipeline tem credencial de cluster.** O CI não roda `kubectl` — ele só
commita num repositório Git. O `GITOPS_TOKEN` dá escrita em um repositório, não
no EKS.

### Secrets necessários

Configure como secrets **do repositório** em cada um dos 5 forks (ou como
secrets da organização, se preferir):

| Secret | Conteúdo |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` | credenciais do Learner Lab — expiram a cada sessão |
| `GITOPS_TOKEN` | PAT fine-grained com **Contents: Read and write** apenas neste repositório |

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

```bash
scripts/destroy.sh                      # pede confirmação
scripts/destroy.sh --yes                # sem perguntar
scripts/destroy.sh --keep-state-bucket  # preserva só o bucket do tfstate
```

Leva de 20 a 30 minutos e **não deixa nada** — inclui os 5 repositórios ECR com
as imagens, a tabela DynamoDB, as filas e o bucket do state. Ao final ele
inventaria a conta e sai com código diferente de zero se algo sobrou.

**Nunca clique em End Lab sem destruir antes.** End Lab dá falsa sensação de
segurança: ele para as instâncias EC2, mas EKS, RDS e ElastiCache continuam
faturando.

### O que o script faz além de `terraform destroy`

Três coisas que um `terraform destroy` puro deixa para trás:

1. **Finalizers das Applications do Argo CD.** Sem removê-los antes, a deleção
   do namespace `argocd` fica presa indefinidamente.
2. **Services `type: LoadBalancer`.** Cada um é um ELB criado pelo Kubernetes,
   que o Terraform não conhece. Se o cluster morrer antes, o ELB fica órfão e
   suas ENIs travam a deleção da VPC. O script remove os Services e espera os
   ELBs sumirem antes de seguir.
3. **O bucket do state.** É criado por script, não pelo Terraform, e é
   versionado — apagar os objetos não basta, é preciso apagar cada versão e cada
   delete marker. Só é removido se os dois `terraform destroy` tiverem passado,
   para não perder o state com recursos ainda de pé.

Depois disso ele ainda varre EIPs órfãos e log groups do cluster.

### Manter só o bloco barato entre sessões

Se você vai voltar amanhã, dá para preservar ECR, DynamoDB, SQS e o bucket
(~US$ 0,10/mês) e destruir só o que custa caro:

```bash
terraform -chdir=platform destroy
terraform -chdir=infra destroy \
  -target=module.eks -target=module.rds -target=module.elasticache -target=module.networking
```

Isso preserva as imagens já buildadas e o state, e a próxima subida cai para
~20 minutos.

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
