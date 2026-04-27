output "vm_dns" {
  description = "Cluster-internal DNS name for the VM (use this as ansible_host in the AAP inventory)."
  value       = "${var.vm_name}.${var.service_name}.${var.namespace}.svc.cluster.local"
}

output "ansible_inventory_snippet" {
  description = "Drop-in YAML for inventory.yml."
  value       = <<-EOT
    all:
      hosts:
        auto-hosts:
          ansible_host: ${var.vm_name}.${var.service_name}.${var.namespace}.svc.cluster.local
          ansible_user: ${var.vm_user}
          ansible_port: 22
  EOT
}
