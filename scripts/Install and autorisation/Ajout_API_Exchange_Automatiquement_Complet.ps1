<#
------------------------------------------------------------
Auteur       : Serge THEZENAS
Fonction     : Consultant M365
Client       : Client Pierre FABRE
Projet       : Export + Notifications + HTML Diff
Module       : EXCHANGE ONLINE
Date         : 2025-05-15
Objectif     : Ajout API
Script       : Authentification par certificat.
Script ID    : EXCHANGE ONLINE v1.1
------------------------------------------------------------
#>

# =========================
# Microsoft Graph Exchange Online App Permissions Script (AppOnly + Certificat)
# =========================

# --- CONFIGURATION ---
$AppId        = "d8675be3-7948-43f5-b523-65cb92f49cc6"
$TenantId     = "2a7dac32-723b-4d53-896c-4e864cd60080"
$Thumbprint   = "75957FDE297FEACA776AC429A970578B18CF0A66"
$LogFilePath  = ".\GraphPermissionsLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# --- Permissions Exchange Online à attribuer ---
$Permissions = @(
    "Mail.ReadWrite"
    "MailboxSettings.ReadWrite"
    "Mail.Send"
    "Contacts.ReadWrite"
)

# =========================
# Connexion à Microsoft Graph
# =========================
Write-Host "`n🔐 Connexion à Microsoft Graph via certificat..." -ForegroundColor Cyan

$Cert = Get-ChildItem -Path "Cert:\CurrentUser\My\$Thumbprint"
if (-not $Cert) {
    $msg = "❌ Certificat non trouvé avec le thumbprint $Thumbprint"
    Write-Host $msg -ForegroundColor Red
    Add-Content $LogFilePath -Value $msg
    Send-TeamsNotification -Message $msg -Status "Failure"
    exit 1
}

try {
    Connect-MgGraph -TenantId $TenantId -ClientId $AppId -Certificate $Cert
    Write-Host "✅ Connecté avec succès à Microsoft Graph." -ForegroundColor Green
    Send-TeamsNotification -Message "Connexion réussie à Microsoft Graph avec certificat." -Status "Success"
} catch {
    $msg = "❌ Erreur de connexion à Microsoft Graph : $_"
    Write-Host $msg -ForegroundColor Red
    Add-Content $LogFilePath -Value $msg
    Send-TeamsNotification -Message $msg -Status "Failure"
    exit 1
}

# =========================
# Préparation des Service Principals
# =========================
Write-Host "[*] Récupération du Service Principal Microsoft Graph..." -ForegroundColor Cyan
$GraphSP = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

Write-Host "[*] Récupération/Création du SP de l'application..." -ForegroundColor Cyan
$TargetSP = Get-MgServicePrincipal -Filter "AppId eq '$AppId'"
if (-not $TargetSP) {
    Write-Host "[+] SP non trouvé, création en cours..." -ForegroundColor Yellow
    $TargetSP = New-MgServicePrincipal -AppId $AppId
    Start-Sleep -Seconds 5
    $TargetSP = Get-MgServicePrincipal -Filter "AppId eq '$AppId'"
}
Write-Host "✔ SP Application ID : $($TargetSP.Id)" -ForegroundColor Green

# =========================
# Attribution des permissions Exchange Online
# =========================
Write-Host "`n[*] Attribution des permissions Exchange Online..." -ForegroundColor Cyan
$SuccessCount = 0
$FailureCount = 0

foreach ($perm in $Permissions) {
    $role = $GraphSP.AppRoles | Where-Object { $_.Value -eq $perm -and $_.AllowedMemberTypes -contains "Application" }

    if ($role) {
        $alreadyAssigned = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $TargetSP.Id `
            | Where-Object { $_.AppRoleId -eq $role.Id -and $_.ResourceId -eq $GraphSP.Id }

        if (-not $alreadyAssigned) {
            try {
                New-MgServicePrincipalAppRoleAssignment `
                    -PrincipalId $TargetSP.Id `
                    -ServicePrincipalId $TargetSP.Id `
                    -ResourceId $GraphSP.Id `
                    -AppRoleId $role.Id `
                    -ErrorAction Stop

                $msg = "[✓] $perm ajouté avec succès"
                Write-Host $msg -ForegroundColor Green
                Add-Content $LogFilePath -Value "[SUCCESS] $perm"
                $SuccessCount++
            } catch {
                $msg = "[!] Échec pour $perm : $_"
                Write-Host $msg -ForegroundColor Red
                Add-Content $LogFilePath -Value "[ERROR] $perm : $_"
                $FailureCount++
            }
        } else {
            Write-Host "[=] Déjà attribué : $perm" -ForegroundColor Yellow
        }
    } else {
        $msg = "[!] Permission inconnue dans Graph : $perm"
        Write-Host $msg -ForegroundColor Red
        Add-Content $LogFilePath -Value "[WARNING] $perm non trouvée"
        $FailureCount++
    }
}

# =========================
# Fin et notifications
# =========================
$msg = "✔ Attribution terminée : $SuccessCount succès, $FailureCount échec(s). Log : $LogFilePath"
Write-Host "`n$msg" -ForegroundColor Cyan
Write-Host "[⚠️] Pensez à accorder le **consentement administrateur** depuis Entra ID (si requis)." -ForegroundColor Yellow
