resource "vkcs_networking_floatingip" "fip_compute2" {
  pool = data.vkcs_networking_network.extnet.name
}

resource "vkcs_compute_floatingip_associate" "fip_compute2" {
  floating_ip = vkcs_networking_floatingip.fip_compute2.address
  instance_id = vkcs_compute_instance.compute_2.id
}

output "instance_fip_compute2" {
  value = vkcs_networking_floatingip.fip_compute2.address
}
