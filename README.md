# ansible-terraform

Demo repo for showing **Network Operations workflow with Ansible Automation Platform (AAP)** on the Red Hat developer sandbox, plus Terraform/Ansible options to provision the target VM in OpenShift Virtualization.

The demo story: **detect → remediate → validate** on a "network device" (a RHEL VM acting as the target).

---

## Repo layout

```
.
├── network-automation-demo/         # Ansible content used by AAP
│   ├── ansible.cfg
│   ├── inventory.yml                # Target host(s) for the demo
│   ├── files/
│   │   └── expected_config.txt      # Desired-state config used by remediation
│   ├── collections/
│   │   └── requirements.yml         # community.general + kubernetes.core
│   └── playbooks/
│       ├── 00_reset_demo.yml        # Reset target back to broken state
│       ├── 01_check_config.yml      # Detect drift
│       ├── 02_remediate_config.yml  # Apply expected config
│       ├── 03_validate_config.yml   # Assert desired state
│       ├── provision_vm.yml         # Provision VM via Terraform (shells out)
│       ├── destroy_vm.yml           # Destroy Terraform-managed VM
│       ├── provision_vm_k8s.yml     # Provision VM via kubernetes.core (AAP-native)
│       └── destroy_vm_k8s.yml       # Destroy via kubernetes.core
│
├── terraform/                       # Terraform IaC for the VM, headless Service, cloud-init Secret
│   ├── main.tf
│   ├── variables.tf
│   ├── vm.tf
│   ├── service.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── README.md
│
└── execution-environment/           # Custom AAP EE with Terraform CLI baked in
    ├── execution-environment.yml
    ├── requirements.yml
    └── README.md
```

---

## Prerequisites

- A Red Hat developer sandbox with **AAP** and **OpenShift Virtualization** provisioned.
- Local CLI tools (only for the parts you run locally):
  - `oc` (OpenShift CLI)
  - `terraform` (≥ 1.5)
  - `ansible`, `ansible-builder`
  - `podman` or `docker`
- An SSH keypair on your laptop (`~/.ssh/id_ed25519` and `.pub`).
  - Generate if missing: `ssh-keygen -t ed25519 -C "aap-demo" -f ~/.ssh/id_ed25519`

---

## Path A — Manual VM creation + AAP demo (simplest)

Use this for the "check → remediate → validate" story without any provisioning automation.

### A.1 Create the VM in OpenShift Virtualization

1. OpenShift console → *Virtualization* → *VirtualMachines* → *Create VirtualMachine* → pick a RHEL template.
2. In *Scripts* → *Cloud-init* → *Edit*, paste your public key:
   ```yaml
   #cloud-config
   user: rhel
   chpasswd: { expire: False }
   ssh_authorized_keys:
     - ssh-ed25519 AAAA... your full public key line
   ```
   Get the key with: `cat ~/.ssh/id_ed25519.pub`
3. Save and start the VM. Note the **VM name** and **namespace**.

### A.2 Update the Ansible inventory

Edit [network-automation-demo/inventory.yml](network-automation-demo/inventory.yml):

```yaml
all:
  hosts:
    network-node-1:
      ansible_host: <vm-name>.<service-name>.<namespace>.svc.cluster.local
      ansible_user: rhel
      ansible_port: 22
```

The DNS pattern requires a **headless Service** in front of the VM. If you didn't create one via the UI, create it from a terminal:

```bash
oc -n <namespace> create service clusterip headless --clusterip=None --tcp=22:22
oc -n <namespace> patch service headless -p '{"spec":{"selector":{"kubevirt.io/domain":"<vm-name>"}}}'
```

### A.3 Configure AAP

1. **Project** — *Projects* → *Add*:
   - Source Control Type: `Git`
   - Source Control URL: this repo's URL
   - Source Control Branch: `main`
   - Save → wait for green sync
2. **Credential — Machine** (for SSH to the VM) — *Credentials* → *Add*:
   - Credential Type: `Machine`
   - Username: `rhel`
   - SSH Private Key: paste contents of `~/.ssh/id_ed25519`
3. **Inventory** — *Inventories* → *Add inventory* → name `network-demo`:
   - *Sources* tab → *Add*:
     - Source: `Sourced from a Project`
     - Project: the one created above
     - Inventory file: `network-automation-demo/inventory.yml`
   - Sync → check *Hosts* tab for `network-node-1`
4. **Job Templates** — create one per playbook:
   - `01-Check Config` → playbook `network-automation-demo/playbooks/01_check_config.yml`
   - `02-Remediate Config` → playbook `network-automation-demo/playbooks/02_remediate_config.yml`
   - `03-Validate Config` → playbook `network-automation-demo/playbooks/03_validate_config.yml`
   - `00-Reset Demo` (optional) → playbook `network-automation-demo/playbooks/00_reset_demo.yml`
   Each: attach `network-demo` inventory + the Machine credential.
5. **Workflow Template** — *Templates* → *Add workflow template* → name `Network Drift Workflow`:
   - Visualizer → chain `01-Check Config` → `02-Remediate Config` → `03-Validate Config` (link on success).
   - Run *Reset Demo* manually before each demo to put the target back into the broken state.

### A.4 Run the demo

Launch the workflow → watch the three jobs run → done.

---

## Path B — Provision the VM with Terraform (from your laptop)

Use this when you want infra-as-code provisioning without involving AAP's EE plumbing.

### B.1 Log into the OpenShift cluster

OpenShift console → top-right user menu → *Copy login command* → run the displayed `oc login` command on your terminal. This populates `~/.kube/config`, which Terraform reads.

### B.2 Configure Terraform inputs

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit [terraform/terraform.tfvars](terraform/terraform.tfvars):

```hcl
ssh_public_key = "ssh-ed25519 AAAA... your full public key"
# optional overrides:
# namespace        = "pranjalpatil-ibm-dev"
# vm_name          = "rhel-10-demo-vm-terraform"
# service_name     = "headless-tf"
# vm_user          = "rhel"
# data_source_name = "rhel10"
```

### B.3 Apply

```bash
terraform init
terraform plan
terraform apply
terraform output -raw vm_dns
```

The output prints the VM's cluster DNS, e.g. `rhel-10-demo-vm-terraform.headless-tf.pranjal30-dev.svc.cluster.local`. Paste it into [network-automation-demo/inventory.yml](network-automation-demo/inventory.yml) under `ansible_host`, then run the AAP demo (Path A.4).

### B.4 Tear down

```bash
terraform destroy
```

### B.5 Wrap Terraform in an Ansible playbook (still local)

If you'd rather drive Terraform via Ansible from your laptop:

```bash
ansible-galaxy collection install -r network-automation-demo/collections/requirements.yml

ansible-playbook network-automation-demo/playbooks/provision_vm.yml
ansible-playbook network-automation-demo/playbooks/destroy_vm.yml
```

These shell out to `terraform` under the hood — same effect as B.3 / B.4.

---

## Path C — Provision from AAP using `kubernetes.core` (recommended for AAP-driven provisioning)

This is the cleanest AAP-native path: no custom EE, no kubeconfig juggling — AAP's built-in OpenShift Bearer Token credential drives auth.

### C.1 Get an OpenShift API token

OpenShift console → top-right user menu → *Copy login command* → click *Display Token* → copy:
- API server URL (e.g., `https://api.rm1.0a51.p1.openshiftapps.com:6443`)
- Bearer token

### C.2 Create the AAP credential

*Credentials* → *Add*:
- Credential Type: `OpenShift or Kubernetes API Bearer Token`
- OpenShift or Kubernetes API Endpoint: the API URL
- API Authentication Bearer Token: the token
- Verify SSL: on
- Save

### C.3 Create the Provision Job Template

*Templates* → *Add job template*:
- Name: `Provision VM (k8s)`
- Project: this repo
- Playbook: `network-automation-demo/playbooks/provision_vm_k8s.yml`
- Inventory: any (the playbook targets `localhost`)
- Credentials: the OpenShift bearer-token credential from C.2
- **Survey** → *Add*:
  - Question: "SSH public key"
  - Variable name: `ssh_public_key`
  - Type: `Textarea`
  - Required: yes
- Save

### C.4 Create the Destroy Job Template

Same as C.3 but:
- Name: `Destroy VM (k8s)`
- Playbook: `network-automation-demo/playbooks/destroy_vm_k8s.yml`
- No survey needed

### C.5 Run

Launch *Provision VM (k8s)* → paste your `~/.ssh/id_ed25519.pub` content into the survey prompt → AAP applies the manifests → VM appears in OpenShift Virtualization.

After provisioning, point the demo inventory at the new VM. Edit [network-automation-demo/inventory.yml](network-automation-demo/inventory.yml):

```yaml
all:
  hosts:
    network-node-1:
      ansible_host: rhel-10-manitoba-auto.headless.pranjalpatil-ibm-dev.svc.cluster.local
      ansible_user: rhel
      ansible_port: 22
```

Commit and push, sync the AAP project, then run the workflow from Path A.4.

To clean up: launch *Destroy VM (k8s)*.

### C.6 Variables you can override

The defaults in [provision_vm_k8s.yml](network-automation-demo/playbooks/provision_vm_k8s.yml) match the Terraform defaults. Override via additional survey questions or *Extra Variables* on the Job Template:

```yaml
namespace: pranjalpatil-ibm-dev
vm_name: rhel-10-demo-vm-terraform
service_name: headless-tf
vm_user: rhel
data_source_name: rhel10
root_disk_size: 30Gi
memory: 2Gi
cpu_cores: 1
```

---

## Path D — Run Terraform from inside AAP (custom Execution Environment)

Use this only if "Terraform driven by AAP" is part of your story. Path C is simpler if you only care about provisioning.

### D.1 Build a custom EE

```bash
pip install ansible-builder
cd execution-environment
ansible-builder build -t quay.io/<your-quay-user>/aap-terraform-ee:latest --verbosity 2
```

Definition is in [execution-environment/execution-environment.yml](execution-environment/execution-environment.yml). It installs Terraform 1.9.5 on top of `quay.io/ansible/awx-ee:latest`.

### D.2 Push to a registry the sandbox can pull from

```bash
podman login quay.io
podman push quay.io/<your-quay-user>/aap-terraform-ee:latest
```

Make the Quay repository **public** (Repo Settings → Visibility) so the sandbox doesn't need pull credentials.

### D.3 Register the EE in AAP

*Execution Environments* → *Add*:
- Name: `aap-terraform-ee`
- Image: `quay.io/<your-quay-user>/aap-terraform-ee:latest`
- Pull policy: `Always` (during iteration; `Missing` once stable)

### D.4 Inject a kubeconfig (the hard part)

Terraform's Kubernetes provider needs a kubeconfig file inside the EE container. AAP's bearer-token credential type only helps `kubernetes.core` — not Terraform. Two options:

- **Custom credential type**: define a credential type that writes a kubeconfig into a temp file and exports `KUBECONFIG`. Standard but fiddly. ← typical AAP pattern
- **In-cluster service account**: if AAP runs in the same cluster as the target, give the EE pod's SA permission and configure the Terraform provider with `config_path = ""`, `host = "https://kubernetes.default.svc"`, and the SA token mounted at `/var/run/secrets/kubernetes.io/serviceaccount/token`.

For a demo, prefer **Path C** unless you specifically need to showcase Terraform-from-AAP.

### D.5 Wire up the Job Templates

Same as Path C but:
- Playbooks: `provision_vm.yml` / `destroy_vm.yml` (the Terraform-wrapping pair)
- Execution Environment: `aap-terraform-ee`
- Credential: whatever you wired up in D.4

---

## Files you typically edit

| File | When | Why |
|------|------|-----|
| [network-automation-demo/inventory.yml](network-automation-demo/inventory.yml) | Whenever the target VM changes | `ansible_host` must match the actual cluster DNS name |
| [terraform/terraform.tfvars](terraform/terraform.tfvars) (gitignored) | Before `terraform apply` | Holds your SSH public key + any overrides |
| [network-automation-demo/files/expected_config.txt](network-automation-demo/files/expected_config.txt) | If you change the demo story | Desired-state config that remediation enforces |
| AAP Project sync | After any Git push | AAP doesn't auto-pull; click *Sync* on the Project after pushing |

---

## Troubleshooting

**`hostname contains invalid characters`**
The inventory still has placeholder `<...>` text. Replace with real DNS.

**`Destination directory /tmp/network_demo does not exist`**
You ran the playbooks against `localhost` instead of the VM, and each AAP Job Template gets a fresh execution environment. Confirm the inventory points at the VM, the Machine credential is attached, and the SSH connection actually works.

**Terraform `kubernetes_manifest` plan errors**
You're not logged into the cluster. Run the `oc login` command from the OpenShift console first.

**AAP project sync fails**
Check the Source Control URL is reachable and (if private) that a Source Control credential is attached to the Project.

**VM never reaches Running**
Check *Virtualization* → click the VM → *Events* tab. Common causes: data source name mismatch (`rhel10` vs `rhel9`), insufficient quota in the sandbox namespace.

**Workflow says success but nothing changed**
Job Template `01_check_config.yml` uses `ignore_errors: yes`, so the workflow proceeds even when drift detection "fails". This is intentional for the simple demo. To gate remediation on drift, switch to a `block`/`rescue` or use workflow links on success/failure.

---

## Quick decision matrix

| Goal | Use |
|------|-----|
| Show check → remediate → validate (no provisioning) | Path A |
| Provision the VM via IaC, locally | Path B |
| Provision the VM via AAP, simplest | **Path C** |
| Demo Terraform-from-AAP specifically | Path D |
