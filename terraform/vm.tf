resource "kubernetes_manifest" "cloud_init" {
  manifest = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "${var.vm_name}-cloud-init"
      namespace = var.namespace
    }
    type = "Opaque"
    stringData = {
      userdata = <<-EOT
        #cloud-config
        user: ${var.vm_user}
        chpasswd: { expire: False }
        ssh_authorized_keys:
          - ${var.ssh_public_key}
      EOT
    }
  }
}

resource "kubernetes_manifest" "vm" {
  manifest = {
    apiVersion = "kubevirt.io/v1"
    kind       = "VirtualMachine"
    metadata = {
      name      = var.vm_name
      namespace = var.namespace
    }
    spec = {
      running = true

      dataVolumeTemplates = [{
        metadata = {
          name = "${var.vm_name}-rootdisk"
        }
        spec = {
          sourceRef = {
            kind      = "DataSource"
            name      = var.data_source_name
            namespace = "openshift-virtualization-os-images"
          }
          storage = {
            resources = {
              requests = {
                storage = var.root_disk_size
              }
            }
          }
        }
      }]

      template = {
        metadata = {
          labels = {
            "kubevirt.io/domain"  = var.vm_name
            "vm.kubevirt.io/name" = var.vm_name
          }
        }
        spec = {
          hostname  = var.vm_name
          subdomain = var.service_name

          domain = {
            cpu = {
              cores = var.cpu_cores
            }
            memory = {
              guest = var.memory
            }
            devices = {
              disks = [
                {
                  name = "rootdisk"
                  disk = { bus = "virtio" }
                },
                {
                  name = "cloudinitdisk"
                  disk = { bus = "virtio" }
                }
              ]
              interfaces = [{
                name       = "default"
                masquerade = {}
              }]
            }
          }

          networks = [{
            name = "default"
            pod  = {}
          }]

          volumes = [
            {
              name = "rootdisk"
              dataVolume = {
                name = "${var.vm_name}-rootdisk"
              }
            },
            {
              name = "cloudinitdisk"
              cloudInitNoCloud = {
                secretRef = {
                  name = "${var.vm_name}-cloud-init"
                }
              }
            }
          ]
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.cloud_init]
}
