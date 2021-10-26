provider "vsphere" {
  user                 = "${var.vsphere_user}"
  password             = "${var.vsphere_password}"
  vsphere_server       = "${var.vsphere_server}"
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "${var.vsphere_datacenter}"
}

data "vsphere_datastore" "ds" {
  name          = "${var.vsphere_datastore}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_compute_cluster" "cl" {
  name          = "${var.vsphere_compute_cluster}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "net_mgmt" {
  name          = "${var.net_mgmt}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "net_aci_infra" {
  name          = "${var.net_aci_infra}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.vsphere_template}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_machine" "ocp_master" {
  count            = 1
  name             = "${var.ocp_master_name}"
  resource_pool_id = "${data.vsphere_compute_cluster.cl.resource_pool_id}"
  datastore_id     = "${data.vsphere_datastore.ds.id}"

  num_cpus = 8
  memory   = 24576
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.net_mgmt.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  network_interface {
    network_id   = "${data.vsphere_network.net_aci_infra.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label = "disk0"
    size  = "${data.vsphere_virtual_machine.template.disks.0.size}"
  }

  folder = "${var.folder}"

  clone {
    linked_clone  = "true"
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${var.ocp_master_name}"
        domain    = "${var.domain_name}"
      }

      network_interface {
        ipv4_address = "${var.ocp_master_address}"
        ipv4_netmask = "27"
      }

      network_interface {}

    ipv4_gateway  = "${var.gateway}"
    dns_server_list = "${var.dns_list}"
    dns_suffix_list = "${var.dns_search}"   

    }
  }

  provisioner "remote-exec" {
    inline = ["sleep 1"]

    connection {
      type     = "ssh"
      user     = "${var.ssh_user}"
      password = "${var.ssh_password}"
    }
  }

  provisioner "local-exec" {
    command = "sshpass -p ${var.ssh_password} ssh-copy-id -i ${var.ssh_key_public} -o StrictHostKeyChecking=no ${var.ssh_user}@${self.guest_ip_addresses.0}"
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.guest_ip_addresses.0},' --private-key ${var.ssh_key_private} ocp_master.yml"
  }
}

resource "vsphere_virtual_machine" "ocp_worker" {
  count            = 1
  name             = "${var.ocp_worker_name}"
  resource_pool_id = "${data.vsphere_compute_cluster.cl.resource_pool_id}"
  datastore_id     = "${data.vsphere_datastore.ds.id}"

  num_cpus = 2
  memory   = 8192
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.net_mgmt.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }
 
  network_interface {
    network_id   = "${data.vsphere_network.net_aci_infra.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label = "disk0"
    size  = "${data.vsphere_virtual_machine.template.disks.0.size}"
  }

  folder = "${var.folder}"

  clone {
    linked_clone  = "true"
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${var.ocp_worker_name}"
        domain    = "${var.domain_name}"
      }

      network_interface {
        ipv4_address = "${var.ocp_worker_address}"
        ipv4_netmask = "27"
      }
   
      network_interface {}

    ipv4_gateway  = "${var.gateway}"
    dns_server_list = "${var.dns_list}"
    dns_suffix_list = "${var.dns_search}"

    }
  }

  provisioner "remote-exec" {
    inline = ["sleep 1"]

    connection {
      type     = "ssh"
      user     = "${var.ssh_user}"
      password = "${var.ssh_password}"
    }
  }

  provisioner "local-exec" {
    command = "sshpass -p ${var.ssh_password} ssh-copy-id -i ${var.ssh_key_public} -o StrictHostKeyChecking=no ${var.ssh_user}@${self.guest_ip_addresses.0}"
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.guest_ip_addresses.0},' --private-key ${var.ssh_key_private} ocp_worker.yml"
  }
}


