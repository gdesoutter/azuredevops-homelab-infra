# Hybrid Lab : Hyper-V Provisioning & Azure Arc Onboarding

Ce projet automatise le déploiement d'un serveur sur un Hyper-V local via Azure Devops, Terraform et l'enrolle automatiquement sur Azure Arc. 

---

## 🏗️ Architecture du Projet

Le flux d'automatisation est piloté par Azure DevOps et se décompose en trois phases :

1. **Extraction des Secrets** : Le pipeline récupère les identifiants sensibles (Service Principal Arc, accès Hyper-V) depuis **Azure Key Vault**.
2. **Infrastructure as Code** : Terraform provisionne la VM sur l'hôte Hyper-V (IP: `192.168.1.120`) et configure le stockage via un disque différencié.
3. **Hybrid Onboarding** : Un script PowerShell installe l'agent Azure Arc et gère la phase d'initialisation.

## 🛠️ Stack Technique

* **IaC** : Terraform (Provider Hyper-V)
* **Orchestration** : Azure DevOps Pipelines
* **OS Cible** : Windows Server 2025
* **Connectivité** : Azure Arc (Agent v1.60+)
* **Sécurité** : Azure Key Vault

## 📂 Structure du Répertoire

```text
.
├── terraform/
│   ├── main.tf          # Définition des ressources Hyper-V
│   ├── variables.tf     # Variables d'entrée (Secrets & Config)
│   ├── outputs.tf       # Export du nom et de l'IP de la machine
│   └── install_arc.ps1  # Script d'installation de l'agent Arc
├── azure-pipelines.yml  # Pipeline CI/CD (Terraform Apply)
└── README.md            # Documentation
```

## ⚙️ Configuration & Prérequis

### 1. Variables Key Vault
Le pipeline (`azure-pipelines.yml`) nécessite un Key Vault nommé `KV-labguillaume` avec les secrets suivants :
* `hyperv-password` : Accès à l'hôte physique.
* `spn-client-id` / `spn-client-secret` : Identité du Service Principal pour Azure Arc.

### 2. Focus sur la Robustesse (Onboarding)
Le script `install_arc.ps1` inclut une boucle de surveillance spécifique. L'agent Azure Arc nécessite souvent entre **10 et 15 minutes** pour s'initialiser. Le script attend que le verrou disparaisse avant de tenter la connexion finale à Azure.

### 3. Environnement d'Exécution (Runner)
Le pipeline s'appuie sur un agent **Azure DevOps Self-Hosted** (`HOMELAB-WSTOOLS`). 
* **Localisation** : Exécuté localement sur mon homelab.
* **Rôle** : Permet à Azure DevOps de communiquer avec l'hôte Hyper-V (`192.168.1.120`) et d'initier les sessions WinRM.
* 
## 🚀 Utilisation

Pour déclencher un déploiement, j'effectue simplement un push sur la branche `main` :

```bash
git add .
git commit -m "feat: déploiement nouveau serveur arc"
git push origin main
```

---
