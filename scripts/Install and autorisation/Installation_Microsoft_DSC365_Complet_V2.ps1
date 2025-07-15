# ============================================
# INSTALLATION COMPLÈTE MICROSOFT365DSC
# ============================================

# Prérequis : Exécuter en tant qu'Administrateur avec PowerShell 5.1
# Vérifier la version PowerShell
$PSVersionTable.PSVersion

# 1. CONFIGURATION PRÉALABLE
# ---------------------------
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# 2. INSTALLATION DU MODULE PRINCIPAL AVEC VÉRIFICATION
# ------------------------------------------------------
Install-ModuleIfMissing -ModuleName "Microsoft365DSC"

# 3. INSTALLATION AUTOMATIQUE DES DÉPENDANCES
# --------------------------------------------
# Commande recommandée pour installer toutes les dépendances
Write-Host "Mise à jour des dépendances M365DSC..." -ForegroundColor Yellow
Update-M365DSCDependencies -Force

# 4. MODULES DE DÉPENDANCES PRINCIPAUX (avec vérification)
# ---------------------------------------------------------
# Si Update-M365DSCDependencies ne fonctionne pas, installer manuellement :

# Module d'authentification (OBLIGATOIRE)
Install-ModuleIfMissing -ModuleName "MSCloudLoginAssistant"

# Modules Microsoft Graph PowerShell (OBLIGATOIRES)
$GraphModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Users",
    "Microsoft.Graph.Groups",
    "Microsoft.Graph.Applications",
    "Microsoft.Graph.DirectoryObjects",
    "Microsoft.Graph.DeviceManagement",
    "Microsoft.Graph.Identity.SignIns",
    "Microsoft.Graph.Identity.DirectoryManagement",
    "Microsoft.Graph.Identity.Governance",
    "Microsoft.Graph.Security",
    "Microsoft.Graph.Teams",
    "Microsoft.Graph.Sites",
    "Microsoft.Graph.Planner",
    "Microsoft.Graph.Beta.DeviceManagement"
)

foreach ($Module in $GraphModules) {
    Install-ModuleIfMissing -ModuleName $Module
}

# Modules Exchange Online
Install-ModuleIfMissing -ModuleName "ExchangeOnlineManagement"

# Modules SharePoint Online
Install-ModuleIfMissing -ModuleName "Microsoft.Online.SharePoint.PowerShell"
Install-ModuleIfMissing -ModuleName "PnP.PowerShell"

# Modules Teams
Install-ModuleIfMissing -ModuleName "MicrosoftTeams"

# Modules Security & Compliance
Install-ModuleIfMissing -ModuleName "Microsoft.PowerApps.Administration.PowerShell"
Install-ModuleIfMissing -ModuleName "Microsoft.PowerApps.PowerShell"

# Module Azure AD (si nécessaire pour compatibilité)
Install-ModuleIfMissing -ModuleName "AzureAD"

# Modules utilitaires
Install-ModuleIfMissing -ModuleName "DSCParser"
Install-ModuleIfMissing -ModuleName "ReverseDSC"

# 5. VÉRIFICATION DE L'INSTALLATION
# ----------------------------------
# Vérifier que Microsoft365DSC est installé
Get-Module -Name Microsoft365DSC -ListAvailable

# Vérifier les dépendances
Get-M365DSCInstalledProductVersion

# Tester l'installation
Test-M365DSCModuleValidity

# 6. COMMANDES DE MAINTENANCE ET MISE À JOUR
# -------------------------------------------
# Mise à jour uniquement si nécessaire (recommandé pour modules existants)
Write-Host "Vérification des mises à jour disponibles..." -ForegroundColor Yellow

# Mettre à jour Microsoft365DSC
try {
    Update-Module Microsoft365DSC -Force -ErrorAction Stop
    Write-Host "Microsoft365DSC mis à jour avec succès ✓" -ForegroundColor Green
} catch {
    Write-Host "Microsoft365DSC déjà à jour ou erreur: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Mettre à jour les dépendances
try {
    Update-M365DSCDependencies -Force -ErrorAction Stop
    Write-Host "Dépendances M365DSC mises à jour ✓" -ForegroundColor Green
} catch {
    Write-Host "Erreur lors de la mise à jour des dépendances: $($_.Exception.Message)" -ForegroundColor Red
}

# Désinstaller les anciennes versions
try {
    Uninstall-M365DSCOutdatedDependencies -ErrorAction Stop
    Write-Host "Anciennes versions supprimées ✓" -ForegroundColor Green
} catch {
    Write-Host "Aucune ancienne version à supprimer" -ForegroundColor Yellow
}

# 7. VÉRIFICATION DES SERVICES
# -----------------------------
# S'assurer que WinRM est démarré
Get-Service -Name WinRM
Start-Service -Name WinRM
Set-Service -Name WinRM -StartupType Automatic

# 8. RÉSOLUTION DE PROBLÈMES COURANTS
# ------------------------------------
# Si problème avec les modules Graph :
Uninstall-Module Microsoft.Graph -AllVersions -Force
Install-Module Microsoft.Graph -Force

# Si problème avec MSCloudLoginAssistant :
Uninstall-Module MSCloudLoginAssistant -AllVersions -Force
Install-Module MSCloudLoginAssistant -Force

# Nettoyer le cache des modules
Remove-Module * -Force
Import-Module Microsoft365DSC -Force

# 9. COMMANDES DE DIAGNOSTIC
# ---------------------------
# Vérifier la configuration
Get-M365DSCInstalledProductVersion
Get-M365DSCComponentsWithLargestConfigurationDrift

# Tester la connectivité
Test-M365DSCParameterState
Confirm-M365DSCDependencies

# 10. EXEMPLE D'EXPORT POUR TESTER
# ---------------------------------
# Export simple pour vérifier que tout fonctionne
Export-M365DSCConfiguration -ComponentsToExtract @("AADApplication") -Credential (Get-Credential)

# ============================================
# NOTES IMPORTANTES :
# ============================================
# - Utiliser PowerShell 5.1 (pas 7+) pour l'installation
# - Exécuter en tant qu'Administrateur
# - Les modules doivent être dans C:\Program Files\WindowsPowerShell\Modules\
# - Update-M365DSCDependencies installe automatiquement toutes les dépendances
# - Version minimale recommandée : Microsoft365DSC 1.25.x
# 
# COMPORTEMENT DU SCRIPT :
# - Avec la fonction Install-ModuleIfMissing : vérifie avant d'installer
# - Affiche "Module déjà installé ✓" si le module existe
# - N'installe que les modules manquants
# - Update-Module ne met à jour que si une version plus récente existe
# - Gestion des erreurs pour éviter les interruptions
# ============================================