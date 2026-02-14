output "vm_name" {
  description = "Nom de la machine"
  value       = hyperv_machine_instance.vm.name
}

output "vm_ip" {
  value = hyperv_machine_instance.vm.network_adaptors[0].ip_addresses[0]
}