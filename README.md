# single-aks

Single-node AKS on Azure. Terraform + GitHub Actions for infra, ArgoCD for GitOps delivery, Rancher for cluster ops, WireGuard + Cloudflare Tunnel for access.

Companion repo: [`gitops`](https://github.com/Ntnick-22/gitops) (private — manifests ArgoCD deploys onto this cluster).

## Two repos, two jobs

**`single-aks`** (public) — **infra**. Terraform that builds the actual Azure resources: VNets, VMs, the AKS cluster itself, ACR. Applied manually, on demand, via `terraform-apply.yml`. Nothing watches this repo continuously — it only changes when you explicitly run the workflow.

**`gitops`** (private) — **what runs on top of the infra**. Helm charts + ArgoCD `ApplicationSet`s describing the actual workloads (`backend`/`frontend`/`worker`). ArgoCD — itself installed *by* `single-aks`'s `05_helm` layer, running *inside* the cluster `single-aks` built — polls this repo every ~3 minutes and reconciles the live cluster to match it.

**How they connect:** one-directional, not a sync loop. `single-aks` builds the platform once; `gitops` is the continuously-reconciled source of truth for everything deployed on top of it. `single-aks` doesn't know `gitops` exists — ArgoCD is the only thing watching, and it only watches `gitops`, never the infra repo. Change infra → re-run a Terraform layer by hand. Change an app → push to `gitops`, ArgoCD picks it up on its own.

## Architecture

```
 laptop
   │
   ├─ WireGuard ──────────► vpn-vm ──(VNet peering)──► myaks-vnet
   │                                                         │
   ├─ kubectl (public API) ─────────────────────────────────►│
   │                                                          ▼
   │                                                   shared-aks (AKS)
   │                                                    ├─ ArgoCD ──(SSH deploy key, read-only)──► gitops (private)
   │                                                    └─ backend / frontend / worker ──► ACR (sharedaksnick)
   │
   └─ https://rancher.nt-nick.link ─┐
      https://argocd.nt-nick.link ──┴─► Cloudflare Edge ──(outbound-only tunnel)──► rancher-vm / argocd-server
```

## Stack

Terraform · GitHub Actions (OIDC) · AKS · ArgoCD · Rancher · WireGuard · Cloudflare Tunnel · Traefik · cert-manager · ACR

## Layers

| Layer | Does |
|---|---|
| `00_rg` | resource group |
| `01_networking` | `myask-vnet` (`10.0.0.0/16`) |
| `02_vm` | WireGuard VPN, peered into `myask-vnet` |
| `03_rancher` | Rancher (Docker) + Cloudflare Tunnel connector |
| `04_aks` | AKS cluster, node pool, ACR, `AcrPull` binding |
| `05_helm` | Traefik, cert-manager, ArgoCD |

Each layer = its own remote state, applied independently via `terraform-apply.yml`.

## Notable choices

- **WireGuard** — keys generated on both ends independently, only public keys ever transmitted.
- **Rancher + ArgoCD behind Cloudflare Tunnel** — outbound-only from each VM/pod, zero inbound ports for the management plane, real TLS certs instead of self-signed.
- **`gitops` is private** — ArgoCD authenticates via a read-only SSH deploy key scoped to that one repo, not a personal token.
- **`selfHeal: true`, `prune: true`** — git is the actual source of truth; manual `kubectl edit` gets reverted on next reconcile.
- **RBAC in ArgoCD** — `developer` read-only, `devops` admin. No shared admin login day-to-day.
- **SSH restricted to the WireGuard subnet** on every VM.

## Screenshots

`![WireGuard tunnel connected](docs/screenshots/wireguard-connected.png)`

`![Rancher — shared-aks Active](docs/screenshots/rancher-dashboard.png)`

`![ArgoCD — all apps Synced/Healthy](docs/screenshots/argocd-apps-synced.png)`

`![ArgoCD RBAC — developer, read-only](docs/screenshots/argocd-rbac-developer.png)`

`![Cloudflare Tunnels healthy](docs/screenshots/cloudflare-tunnels.png)`

`![GitHub Actions — OIDC apply run](docs/screenshots/github-actions-oidc.png)`
