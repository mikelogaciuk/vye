terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}
provider "libvirt" {
  uri = "qemu:///system"
}
resource "libvirt_volume" "distro-qcow2" {
  count  = var.hosts
  name   = "${var.distros[count.index]}.qcow2"
  pool   = "vye"
  source = "${path.module}/sources/${var.distros[count.index]}.qcow2"
  format = "qcow2"
}
resource "libvirt_cloudinit_disk" "commoninit" {
  count = var.hosts
  name  = "commoninit-${var.distros[count.index]}.iso"
  pool  = "vye"
  user_data = templatefile("${path.module}/templates/user_data.tpl", {
    host_name = var.distros[count.index]
    auth_key  = file("${path.module}/ssh/id_rsa.pub")
    api_key   = var.dev_stack_api_key
  })
  network_config = templatefile("${path.module}/templates/network_config.tpl", {
    interface = var.interface
    ip_addr   = var.ips[count.index]
    mac_addr  = var.macs[count.index]
  })
}
resource "libvirt_domain" "domain-distro" {
  count  = var.hosts
  name   = var.hostnames[count.index]
  memory = var.memory
  vcpu   = var.vcpu
  cpu {
    mode = "host-passthrough"
  }
  cloudinit = element(libvirt_cloudinit_disk.commoninit.*.id, count.index)

  network_interface {
    network_name = "default"
    addresses    = [var.ips[count.index]]
    mac          = var.macs[count.index]
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  console {
    type        = "pty"
    target_port = "1"
    target_type = "virtio"
  }
  disk {
    volume_id = element(libvirt_volume.distro-qcow2.*.id, count.index)
  }
}
