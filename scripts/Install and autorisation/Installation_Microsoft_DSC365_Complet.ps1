# Autoriser l'exécution des scripts dans cette session
Set-ExecutionPolicy RemoteSigned -Scope Process -Force

# Fonction utilitaire pour installer un module s'il n'existe pas
function Ensure-ModuleInstalled {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "📦 Installation du module '$ModuleName'..."
        Install-Module -Name $ModuleName -Force
    } else {
        Write-Host "✅ Le module '$ModuleName' est déjà installé."
    }
}

# Fonction utilitaire pour mettre à jour un module si installé
function Ensure-ModuleUpdated {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )
    if (Get-Module -ListAvailable -Name $ModuleName) {
        Write-Host "🔄 Mise à jour du module '$ModuleName'..."
        Update-Module -Name $ModuleName
    } else {
        Write-Host "⚠️ Le module '$ModuleName' n'est pas installé, donc non mis à jour."
    }
}

# Vérification et installation des modules requis
Ensure-ModuleInstalled -ModuleName "Microsoft365DSC"
Ensure-ModuleInstalled -ModuleName "ReverseDSC"
Ensure-ModuleInstalled -ModuleName "MSAL.PS"
Ensure-ModuleInstalled -ModuleName "Microsoft.Graph"

# Importation du module principal
Import-Module -Name Microsoft365DSC -Force

# Mise à jour des dépendances Microsoft365DSC
Write-Host "🔧 Mise à jour des dépendances Microsoft365DSC..."
Update-M365DSCDependencies

# (Optionnel) Mise à jour des modules installés
Ensure-ModuleUpdated -ModuleName "Microsoft365DSC"
Ensure-ModuleUpdated -ModuleName "ReverseDSC"

Write-Host "✅ Environnement prêt pour capturer la configuration Microsoft 365 avec DSC."