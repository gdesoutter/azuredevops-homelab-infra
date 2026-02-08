# --- 1. Création du Disque OS ---
resource "null_resource" "os_disk" {
  triggers = {
    vm_name  = var.vm_name
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
      "powershell.exe -ExecutionPolicy Bypass -Command \"New-VHD -Path 'C:\\Hyper-V\\VHDs\\${self.triggers.vm_name}.vhdx' -ParentPath 'C:\\Hyper-V\\Templates\\Server2025_Master.vhdx' -Differencing\""
    ]
  }

  provisioner "remote-exec" {
    when    = destroy
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -Command \"Remove-Item -Path 'C:\\Hyper-V\\VHDs\\${self.triggers.vm_name}.vhdx' -Force -ErrorAction SilentlyContinue\""
    ]
  }
}

# --- 2. La Machine Virtuelle Hyper-V ---
resource "hyperv_machine_instance" "vm" {
  name            = var.vm_name
  generation      = 2
  processor_count = 2
  static_memory   = true
  memory_startup_bytes = 4294967296 

  depends_on = [null_resource.os_disk]

  hard_disk_drives {
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
    path                = "C:\\Hyper-V\\VHDs\\${var.vm_name}.vhdx"
  }

  network_adaptors {
    name        = "eth0"
    switch_name = "Lab-External" 
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

# --- 3. Provisioning (Onboarding Auto) ---
resource "null_resource" "onboarding" {
  triggers = {
    vm_id       = hyperv_machine_instance.vm.id
    script_hash = filebase64sha256("${path.module}/scripts/install_arc.ps1")
  }

  connection {
    type     = "winrm"
    user     = "Administrateur"      
    password = var.vm_admin_password    
    host     = hyperv_machine_instance.vm.network_adaptors[0].ip_addresses[0]
    https    = true
    insecure = true
    timeout  = "15m" # On augmente à 15 min car Server 2025 peut être lent au premier boot
  }

  # A. Préparation de l'environnement
  provisioner "remote-exec" {
    inline = [
      "powershell.exe -Command \"if (-not (Test-Path 'C:\\Temp')) { New-Item -ItemType Directory -Path 'C:\\Temp' -Force }\"",
      "powershell.exe -Command \"Set-Service -Name WinRM -StartupType Automatic\""
    ]
  }

  # B. Copie du script
  provisioner "file" {
    source      = "${path.module}/scripts/install_arc.ps1"
    destination = "C:/Temp/install_arc.ps1"
  }

  # C. Exécution Automatique
  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File C:/Temp/install_arc.ps1 -TenantId \"${var.tenant_id}\" -ClientId \"${var.client_id}\" -ClientSecret \"${var.client_secret}\" -ResourceGroup \"${var.resource_group}\" -Location \"${var.location}\" -ResourceName \"${var.vm_name}\""
    ]
  }
}