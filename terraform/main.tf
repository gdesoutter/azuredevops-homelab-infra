resource "null_resource" "os_disk" {
  for_each = var.vm_catalog

  triggers = {
    vm_name  = each.key
    host     = var.hyperv_host
    user     = var.hyperv_user
    password = var.hyperv_password
  }

  connection {
    type     = "winrm"
    host     = self.triggers.host
    user     = self.triggers.user
    password = self.triggers.password
    port     = 5986
    https    = true
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -Command \"if (-not (Test-Path 'C:\\Hyper-V\\VHDs\\${self.triggers.vm_name}.vhdx')) { New-VHD -Path 'C:\\Hyper-V\\VHDs\\${self.triggers.vm_name}.vhdx' -ParentPath 'C:\\Hyper-V\\Templates\\Server2025_Master.vhdx' -Differencing } else { Write-Host 'Le disque existe deja' }\""
    ]
  }

  provisioner "remote-exec" {
    when   = destroy
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -Command \"Remove-Item -Path 'C:\\Hyper-V\\VHDs\\${self.triggers.vm_name}.vhdx' -Force -ErrorAction SilentlyContinue\""
    ]
  }
}

resource "hyperv_machine_instance" "vm" {
  for_each = var.vm_catalog

  name                 = each.key
  generation           = 2
  processor_count      = each.value.vcpu
  static_memory        = true
  memory_startup_bytes = each.value.ram_mb * 1024 * 1024

  depends_on = [null_resource.os_disk]

  hard_disk_drives {
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
    path                = "C:\\Hyper-V\\VHDs\\${each.key}.vhdx"
  }

  network_adaptors {
    name        = "eth0"
    switch_name = each.value.switch_name
  }

  vm_firmware {
    enable_secure_boot   = "On"
    secure_boot_template = "MicrosoftWindows"
    boot_order {
      boot_type           = "HardDiskDrive"
      controller_number   = 0
      controller_location = 0
    }
  }
}

resource "null_resource" "onboarding" {
  for_each = var.vm_catalog

  triggers = {
    vm_id       = hyperv_machine_instance.vm[each.key].id 
    script_hash = filebase64sha256("${path.module}/scripts/install_arc.ps1")
  }

  connection {
    type     = "winrm"
    user     = "Administrateur"
    password = var.vm_admin_password
    host     = hyperv_machine_instance.vm[each.key].network_adaptors[0].ip_addresses[0]
    https    = true
    insecure = true
    timeout  = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -Command \"if (-not (Test-Path 'C:\\Temp')) { New-Item -ItemType Directory -Path 'C:\\Temp' -Force }\"",
      "powershell.exe -Command \"Set-Service -Name WinRM -StartupType Automatic\""
    ]
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_arc.ps1"
    destination = "C:/Temp/install_arc.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -Command \"$s = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(var.client_secret)}')); & C:/Temp/install_arc.ps1 -TenantId '${var.tenant_id}' -ClientId '${var.client_id}' -ClientSecret $s -ResourceGroup '${var.resource_group}' -Location '${var.location}' -ResourceName '${each.key}' -SubscriptionId '${var.subscription_id}'\""
    ]
  }
}