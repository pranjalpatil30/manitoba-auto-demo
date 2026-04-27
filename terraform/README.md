# Terraform — OpenShift Virtualization VM for the AAP demo

Provisions the RHEL VM, headless Service, and cloud-init secret used as the target host in `../network-automation-demo/`.

## Prerequisites

- Terraform >= 1.5
- `oc` CLI logged into the OpenShift sandbox: copy the *Login command* from the OpenShift console (top-right user menu) and run it. This populates `~/.kube/config`.
- An SSH keypair on disk (`~/.ssh/id_ed25519` / `.pub`).

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and paste your SSH public key

terraform init
terraform plan
terraform apply
```

After apply, grab the inventory snippet:

```bash
terraform output -raw ansible_inventory_snippet
```

…and paste it into `../network-automation-demo/inventory.yml`.

## Tear down

```bash
terraform destroy
```

## Notes

- The `kubernetes_manifest` resource calls the cluster API at plan time, so you must be logged in for `terraform plan` to work.
- The headless Service gives the VM a stable cluster DNS name (`<vm>.<service>.<namespace>.svc.cluster.local`) reachable from AAP execution-environment pods in the same cluster.
- `data_source_name` defaults to `rhel10`; change it if your sandbox exposes a different image (e.g. `rhel9`, `fedora`).
