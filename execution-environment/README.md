# Custom AAP Execution Environment with Terraform

Builds a container image that the default AAP execution environment doesn't provide: Ansible + Terraform CLI in one image, so `community.general.terraform` works inside AAP Job Templates.

## What's inside

- Base: `quay.io/ansible/awx-ee:latest` (publicly pullable, Ansible pre-installed)
- Collections: `community.general`, `kubernetes.core`
- Terraform CLI v1.9.5 at `/usr/local/bin/terraform`

## Prerequisites

- Podman or Docker
- `ansible-builder`: `pip install ansible-builder`
- A container registry the AAP sandbox can pull from (Quay.io free account works)

## Build and push

```bash
cd execution-environment

# build (use podman or docker — ansible-builder picks one automatically)
ansible-builder build -t quay.io/<your-quay-user>/aap-terraform-ee:latest --verbosity 2

# push to a registry your AAP sandbox can pull from
podman login quay.io
podman push quay.io/<your-quay-user>/aap-terraform-ee:latest
```

Make the Quay.io repo **public** (Repo Settings → Visibility) so the sandbox can pull without credentials.

## Register the EE in AAP

1. *Execution Environments* → *Add*
2. Name: `aap-terraform-ee`
3. Image: `quay.io/<your-quay-user>/aap-terraform-ee:latest`
4. Pull policy: `Always` (during iteration; `Missing` is fine once stable)
5. Save.

## Use it from a Job Template

When creating/editing a Job Template that runs `provision_vm.yml` or `destroy_vm.yml`:

- *Execution Environment*: `aap-terraform-ee`

## Outstanding piece: kubeconfig in AAP

The Terraform Kubernetes provider needs a kubeconfig to talk to the OpenShift cluster. From a local laptop `oc login` populates `~/.kube/config` automatically, but the EE container in AAP starts fresh.

Two clean options:

1. **Custom credential type** (recommended): create a custom AAP credential type that injects a `KUBECONFIG` env var pointing at a temp file written from the credential's payload. Attach it to the Job Template.
2. **In-cluster service account**: if the AAP and the target VM live in the same OpenShift cluster, configure the Terraform provider to use the in-cluster service account token by mounting it. Less portable but no secret juggling.

Wire up whichever fits your workflow once the image builds successfully.
