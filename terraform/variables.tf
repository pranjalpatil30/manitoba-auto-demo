variable "kubeconfig_path" {
  description = "Path to a kubeconfig already logged into the OpenShift sandbox (e.g. via 'oc login')."
  type        = string
  default     = "~/.kube/config"
}

variable "namespace" {
  description = "OpenShift namespace where the VM and Service will be created."
  type        = string
  default     = "pranjalpatil-ibm-dev"
}

variable "vm_name" {
  description = "Name of the VirtualMachine."
  type        = string
  default     = "rhel-10-demo-vm-terraform"
}

variable "service_name" {
  description = "Name of the headless Service that gives the VM stable cluster DNS. Must be different from any existing Service in the namespace."
  type        = string
  default     = "headless-tf"
}

variable "vm_user" {
  description = "Cloud-init user to create on the VM."
  type        = string
  default     = "rhel"
}

variable "ssh_public_key" {
  description = "SSH public key (single line) to inject via cloud-init for AAP to authenticate."
  type        = string
}

variable "data_source_name" {
  description = "DataSource for the root disk image (in openshift-virtualization-os-images)."
  type        = string
  default     = "rhel10"
}

variable "root_disk_size" {
  description = "Root disk size."
  type        = string
  default     = "30Gi"
}

variable "memory" {
  description = "VM memory."
  type        = string
  default     = "2Gi"
}

variable "cpu_cores" {
  description = "VM CPU cores."
  type        = number
  default     = 1
}
