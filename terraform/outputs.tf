output "vm_names" {
  description = "Liste des VMs déployées"
  value = [for vm in hyperv_machine_instance.vm : vm.name]
}

output "vm_ips" {
  description = "Mappage des IPs par VM"
  value = {
    for key, vm in hyperv_machine_instance.vm : key => vm.network_adaptors[0].ip_addresses[0]
  }
}