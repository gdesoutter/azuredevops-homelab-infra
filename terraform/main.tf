# --- 1. Création du Disque OS (Bypass du bug de copie) ---
resource "null_resource" "os_disk" {
  # C'est ICI la correction : On stocke tout ce dont on a besoin pour le destroy dans la mémoire de la ressource
  triggers = {
    vm_name  = var.vm_name
    host     = var.hyperv_host
    user     = var.hyperv_user
    password = var.hyperv_password
  }

  connection {
    type     = "winrm"
    # On utilise self.triggers au lieu de var pour que ça marche au destroy
    host     = self.triggers.host
    user     = self.triggers.user
    password = self.triggers.password
    port     = 5986
    https    = true
    insecure = true
  }

  # CRÉATION : On crée le disque de différenciation
  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -Command \"New-VHD -Path 'C:\\Hyper-V\\VHDs\\${self.triggers.vm_name}.vhdx' -ParentPath 'C:\\Hyper-V\\Templates\\Server2025_Master.vhdx' -Differencing\""
    ]
  }

  # DESTRUCTION : On nettoie le fichier
  provisioner "remote-exec" {
    when    = destroy
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -Command \"Remove-Item -Path 'C:\\Hyper-V\\VHDs\\${self.triggers.vm_name}.vhdx' -Force -ErrorAction SilentlyContinue\""    ]
  }
}

# --- 2. La Machine Virtuelle ---
resource "hyperv_machine_instance" "vm" {
  name = var.vm_name
  generation = 2
  
  processor_count = 2
  static_memory   = true
  memory_startup_bytes = 4294967296 # 4GB

  # On attend que le disque soit créé physiquement par le script
  depends_on = [null_resource.os_disk]

  hard_disk_drives {
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
    path                = "C:\\Hyper-V\\VHDs\\${var.vm_name}.vhdx"
  }

  # Réseau
  network_adaptors {
    name        = "eth0"
    switch_name = "Lab-Internal" # <--- Vérifie bien ce nom sur ton Hyper-V !
  }

  vm_firmware {
    enable_secure_boot = "On"
    secure_boot_template = "MicrosoftWindows" 
    boot_order {
      boot_type           = "HardDiskDrive"
      controller_number   = 0
      controller_location = 0
    }
  }
}

# --- 3. Provisioning (Installation Arc) ---
resource "null_resource" "onboarding" {
  triggers = {
    vm_id = hyperv_machine_instance.vm.id
  }

  connection {
    type     = "winrm"
    user     = "Administrator"          # User de ta Golden Image
    password = var.vm_admin_password    # Password de ta Golden Image
    host     = hyperv_machine_instance.vm.network_adaptors[0].ip_addresses[0]
    https    = true
    insecure = true
  }

  # Upload du script
  provisioner "file" {
    source      = "${path.module}/scripts/install_arc.ps1"
    destination = "C:/Temp/install_arc.ps1"
  }

  # Exécution du script
  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File C:/Temp/install_arc.ps1 -TenantId '${var.tenant_id}' -ClientId '${var.client_id}' -ClientSecret '${var.client_secret}' -ResourceGroup '${var.resource_group}' -Location '${var.location}' -ResourceName '${var.vm_name}'"
    ]
  }
}