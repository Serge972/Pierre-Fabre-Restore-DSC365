<#
------------------------------------------------------------
Auteur       : Serge THEZENAS
Fonction     : Consultant M365
Client       : Client Pierre FABRE
Projet       : Export + Notifications + HTML Diff
Module       : INTUNE
Date         : 2025-05-15
Objectif     : Ajout API
Script       : Authentification par certificat.
Script ID    : INTUNE v1.1
------------------------------------------------------------
#>


# =========================
# Microsoft Graph Permissions Script (AppOnly + Certificat)
# =========================

# --- CONFIGURATION ---
$AppId      = "d8675be3-7948-43f5-b523-65cb92f49cc6"
$TenantId   = "2a7dac32-723b-4d53-896c-4e864cd60080"
$ClientId   = "d8675be3-7948-43f5-b523-65cb92f49cc6"
$Thumbprint = "75957FDE297FEACA776AC429A970578B18CF0A66"
$LogPath    = ".\GraphPermissionsLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# --- Permissions App-Only valides à attribuer ---
$Permissions = @(

"DeviceManagementApps.ReadWrite.All"
"DeviceManagementConfiguration.ReadWrite.All"
"DeviceManagementManagedDevices.ReadWrite.All"
"DeviceManagementServiceConfig.Read.All"
"DeviceManagementRBAC.Read.All"
"Directory.ReadWrite.All"
)

# =========================
# 1. Connexion à Graph
# =========================
Write-Host "`n[*] Connexion à Microsoft Graph avec certificat..." -ForegroundColor Cyan

$Cert = Get-ChildItem -Path "Cert:\CurrentUser\My\$Thumbprint"
if (-not $Cert) {
    Write-Error "❌ Certificat introuvable avec le thumbprint $Thumbprint"
    exit 1
}

Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $Cert

if (-not (Get-MgContext)) {
    Write-Error "❌ Connexion échouée à Microsoft Graph."
    exit 1
}

# =========================
# 2. Récupération SP Graph & SP de l'app
# =========================
Write-Host "[*] Récupération du SP Microsoft Graph..." -ForegroundColor Cyan
$GraphSP = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

Write-Host "[*] Récupération ou création du SP de l'application..." -ForegroundColor Cyan
$TargetSP = Get-MgServicePrincipal -Filter "AppId eq '$AppId'"
if (-not $TargetSP) {
    Write-Host "[*] SP introuvable, création..." -ForegroundColor Yellow
    $TargetSP = New-MgServicePrincipal -AppId $AppId
    Start-Sleep -Seconds 5
    $TargetSP = Get-MgServicePrincipal -Filter "AppId eq '$AppId'"
}
Write-Host "[✔] SP Application ID : $($TargetSP.Id)" -ForegroundColor Green

# =========================
# Attribution des permissions
# =========================
Write-Host "`n[*] Attribution des permissions..." -ForegroundColor Cyan

# Récupération du service principal de Microsoft Graph
$GraphSP = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

# Vérification que le service principal de Graph est récupéré correctement
if (-not $GraphSP) {
    Write-Host "[!] Service Principal Microsoft Graph non trouvé !" -ForegroundColor Red
    exit 1
}

foreach ($permName in $Permissions) {
    # Récupérer les rôles associés à la permission demandée
    $role = $GraphSP.AppRoles | Where-Object {
        $_.Value -eq $permName -and $_.AllowedMemberTypes -contains "Application"
    }

    if ($role) {
        # Vérifier si le rôle a déjà été attribué
        $alreadyAssigned = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $TargetSP.Id `
            | Where-Object { $_.AppRoleId -eq $role.Id -and $_.ResourceId -eq $GraphSP.Id }

        if (-not $alreadyAssigned) {
            try {
                # Spécifier explicitement les IDs
                New-MgServicePrincipalAppRoleAssignment `
                    -PrincipalId $TargetSP.Id `
                    -ServicePrincipalId $TargetSP.Id `
                    -ResourceId $GraphSP.Id `
                    -AppRoleId $role.Id `
                    -ErrorAction Stop

                Write-Host "[✓] $permName ajouté avec succès" -ForegroundColor Green
                Add-Content -Path $LogPath -Value "[SUCCESS] $permName ajouté"
            } catch {
                Write-Host "[!] Échec pour $permName : $_" -ForegroundColor Red
                Add-Content -Path $LogPath -Value "[ERROR] $permName : $_"
            }
        } else {
            Write-Host "[=] Déjà présent : $permName" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[!] Permission non trouvée dans Graph : $permName" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "[WARNING] Permission non trouvée : $permName"
    }
}



# =========================
# 4. Fin
# =========================
Write-Host "`n[✔] Terminé. Log : $LogPath" -ForegroundColor Cyan
Write-Host "[⚠️] Pensez à accorder le **consentement administrateur** depuis le portail Entra ID." -ForegroundColor Yellow