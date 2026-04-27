resource "kubernetes_manifest" "headless_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = var.service_name
      namespace = var.namespace
    }
    spec = {
      clusterIP = "None"
      selector = {
        "kubevirt.io/domain" = var.vm_name
      }
      ports = [{
        name       = "ssh"
        port       = 22
        targetPort = 22
        protocol   = "TCP"
      }]
    }
  }
}
