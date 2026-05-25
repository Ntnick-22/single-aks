# single-aks

Terraform infrastructure for a single AKS cluster on Azure. Organised into independent layers — each layer manages one concern and stores its state remotely in Azure Blob Storage.

## Architecture

```
00_rg          Resource Group
01_networking  Virtual Network + Subnets
02_vm          Jump/bastion Linux VM
04_aks         AKS Cluster + Node Pools
```

Each layer reads outputs from the layers it depends on via `terraform_remote_state`.

## Layer Details

### 00_rg
Creates the resource group. All other layers reference this via remote state to get the resource group name and location.

### 01_networking
Creates the VNet (`10.0.0.0/16`) and a VM subnet (`10.0.1.0/24`). The AKS subnet is managed inside `04_aks` directly.

### 02_vm
Provisions a Linux jump VM (`Standard_B1s`, Ubuntu 22.04) with:
- Static public IP
- NSG with SSH inbound rule
- SSH key authentication only (no password)

### 04_aks
Provisions the AKS cluster with:
- `kubenet` network plugin
- 2-node default pool (`Standard_D2s_v3`)
- 2 extra node pools — `dbpool` (tainted `role=db:NoSchedule`) and `prodpool`
- `SystemAssigned` managed identity
- NSG attached to AKS subnet allowing HTTP/HTTPS/LB health probes



## State Backend

All layers use Azure Blob Storage for remote state:

| Layer | State Key |
|---|---|
| 00_rg | `00_rg/terraform.tfstate` |
| 01_networking | `01_networking/terraform.tfstate` |
| 02_vm | `02_vm/terraform.tfstate` |
| 04_aks | `04_aks/terraform.tfstate` |

Storage account: `aksk8state` in resource group `aks-k8-rg`.

## CI/CD

Two GitHub Actions workflows in `.github/workflows/`:

### terraform-plan.yml
- Triggers on pull requests to `main` (plans all layers) or manual dispatch (plan a specific layer)
- Posts plan output as a PR comment

### terraform-apply.yml
- Manual dispatch only (`workflow_dispatch`)
- Select the layer to apply from the dropdown
- Authentication via GitHub OIDC → Azure (no stored credentials)

### Authentication
Uses GitHub OIDC federation — no client secrets stored in GitHub. Required secrets:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Apply Order

Layers must be applied in dependency order:

```
00_rg → 01_networking → 02_vm
                      → 04_aks
```
