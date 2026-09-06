# Módulo Terraform · `argocd`

Instala o **Argo CD** no cluster EKS e registra o **App of Apps**. A partir daí
todo o deploy — os 5 microsserviços, o namespace, o Ingress — é criado pelo
próprio Argo CD a partir do repositório de manifestos.

## Por que dois `helm_release`

1. `helm_release.argocd` — o chart oficial `argo-cd`.
2. `helm_release.bootstrap` — um chart mínimo em `charts/bootstrap/` que
   renderiza o `Application` raiz montado em `locals.root_app`.

As CRDs do Argo CD vivem em `templates/crds` do chart oficial (e não no
diretório `crds/`), então só passam a existir na API durante a instalação.
Declarar o `Application` no mesmo release falharia em cluster novo com
`no matches for kind Application`, porque o Helm resolve todos os kinds antes de
criar qualquer recurso. O segundo release, com `depends_on`, roda depois.

Isso também evita `kubernetes_manifest`, que exigiria a CRD já existente no
momento do `terraform plan` — quebrando o primeiro `apply`.

## Uso

```hcl
module "argocd" {
  source = "../modules/argocd"

  gitops_repo_url        = "https://github.com/FIAP-Teach-Challenge-2/toggle-master-infra.git"
  gitops_target_revision = "main"
  gitops_path            = "aws/argocd/applications"
}
```

Configure o provider `helm` a partir de **data sources** de um cluster que já
existe, e não de outputs de um `module.eks` no mesmo apply — nesse segundo caso
o endpoint é desconhecido durante o `plan` e o primeiro `apply` falha. É por
isso que `infra/` e `platform/` são roots separados. Veja
[`platform/providers.tf`](../../platform/providers.tf), que também mostra por
que a autenticação usa `exec` e não um token estático.

## Entradas principais

| Variável | Padrão |
|---|---|
| `namespace` | `argocd` |
| `chart_version` | `10.8.0` (Argo CD v3.5.2) |
| `gitops_repo_url` | repo do ToggleMaster |
| `gitops_target_revision` | `main` |
| `gitops_path` | `aws/argocd/applications` |
| `values_file` | `values.yaml` do próprio módulo |

## Depois do apply

```bash
terraform output -raw argocd_admin_password_command   # copie e rode
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

## AWS Academy

Não cria nenhuma IAM Role ou Policy. O `Service` do `argocd-server` é
`ClusterIP` (acesso por `port-forward`), então não provisiona ELB nem gera custo.
`dex`, `notifications` e `applicationSet` vêm desligados para caber num node
group pequeno.
