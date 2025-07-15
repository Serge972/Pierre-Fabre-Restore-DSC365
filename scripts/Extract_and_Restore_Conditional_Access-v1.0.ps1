<#
------------------------------------------------------------
Auteur       : Serge THEZENAS
Fonction     : Consultant M365
Client       : Client Pierre FABRE
Projet       : Extract + Restore + Notifications TEAMS + Logs HTML
Module       : AZURE AD - Conditional Access
Date         : 2025-07-13
Objectif     : Exporter la configuration d'un accès conditionnel AZURE AD, le restaurer,
               générer un rapport HTML, et notifier par Teams et par mail.
Script ID    : AZUREAD-EXTRACT-RESTORE-CONDITIONALACCESS-v1.0
------------------------------------------------------------
#>

# ========================================
# Script Extract_ConditionalAccess.ps1 - Version Enhanced (Chrono & rapport HTML robustes)
# Extraction + Restauration DSC complète avec logs et notifications
# ========================================

$ScriptStartTime = Get-Date

# === Étape 0 : Nettoyage, vérification et mise à jour conditionnelle des modules DSC nécessaires ===

# ➡️ Ce script doit être exécuté en tant qu’Administrateur
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "🚫 Ce script doit être exécuté en tant qu’administrateur. Arrêt." -ForegroundColor Red
    exit 1
}

# -- DÉFINITIONS DES VERSIONS MINIMALES REQUISES --
$requiredModules = @{
    "Microsoft365DSC" = "1.25.709.1"
    "DSCParser"       = "2.0.0.17"
    "MicrosoftTeams"  = "7.0.0"
}

# -- NETTOYAGE DES ANCIENNES VERSIONS (NE GARDE QUE LA DERNIÈRE) --
foreach ($module in $requiredModules.Keys) {
    $allVersions = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending
    if ($allVersions.Count -gt 1) {
        $latestVersion = $allVersions | Select-Object -First 1
        $olderVersions = $allVersions | Select-Object -Skip 1
        foreach ($old in $olderVersions) {
            try {
                if (Test-Path $old.ModuleBase) {
                    Remove-Item -Path $old.ModuleBase -Recurse -Force
                    Write-Host "🧹 Supprimé $module version $($old.Version) (conservé $($latestVersion.Version))" -ForegroundColor Gray
                }
            } catch {
                Write-Host "❌ Impossible de supprimer $module $($old.Version) : $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

# -- CONTRÔLE DES VERSIONS INSTALLÉES --
$updateRequired = $false
$modulesToInstall = @()

foreach ($module in $requiredModules.Keys) {
    $requiredVersion = [version]$requiredModules[$module]
    $installed = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1

    if (-not $installed) {
        Write-Host "❌ Le module $module est manquant. Il sera installé." -ForegroundColor Yellow
        $updateRequired = $true
        $modulesToInstall += $module
    }
    elseif ([version]$installed.Version -lt $requiredVersion) {
        Write-Host "🔄 $module est en version $($installed.Version), mise à jour requise (attendu ≥ $requiredVersion)." -ForegroundColor Yellow
        $updateRequired = $true
        $modulesToInstall += $module
    }
    else {
        Write-Host "✅ $module est à jour ($($installed.Version))." -ForegroundColor Green
    }
}

# -- INSTALLATION / MISE À JOUR DES MODULES SI BESOIN --
if ($updateRequired -and $modulesToInstall.Count -gt 0) {
    Write-Host "🔧 Mise à jour/installation des modules suivants : $($modulesToInstall -join ', ')" -ForegroundColor Cyan
    foreach ($module in $modulesToInstall) {
        try {
            Install-Module -Name $module -Force -Scope AllUsers -AllowClobber -ErrorAction Stop
            Write-Host "✔️ $module installé/mis à jour." -ForegroundColor Green
        } catch {
            Write-Host "❌ Échec pour $module : $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host "✅ Tous les modules requis sont installés et à jour." -ForegroundColor Green
}

# -- MISE À JOUR DES DÉPENDANCES DYNAMIQUES DE Microsoft365DSC --
try {
    Write-Host "🔄 Mise à jour des dépendances Microsoft365DSC via Update-M365DSCDependencies..." -ForegroundColor Cyan
    Update-M365DSCDependencies -Force -ErrorAction Stop
    Write-Host "✅ Dépendances Microsoft365DSC mises à jour avec succès." -ForegroundColor Green
} catch {
    Write-Host "❌ Échec lors de Update-M365DSCDependencies : $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# === Paramètres pré-remplis ===
$FilePS1_M365TenantConfig        = "C:\Export_Complet\Baseline_AZUREAD_ENTRAID_M365DSC_ExportConf_2025-07-08_10-15-50\M365TenantConfig.ps1"
$TargetConditionalAccessName     = "CA007 - MFA for Microsoft FORM"
$OutputPs1Path                   = "C:\Script_complet\Scripts OK - PF Juin 2025\TEMPLATE_RESTO_OK\CONDITIONALACCESS\RestoreConditionalAccess\RestoreConditionalAccess.ps1"
$ApplicationId                   = "d8675be3-7948-43f5-b523-65cb92f49cc6"
$TenantId                       = "M365x49418703.onmicrosoft.com"
$CertificateThumbprint          = "75957FDE297FEACA776AC429A970578B18CF0A66"

# === Log et notifications ===
$LogDirectory = "C:\Script_complet\Scripts OK - PF Juin 2025\TEMPLATE_RESTO_OK\CONDITIONALACCESS\log"
$LogFile = "$LogDirectory\ConditionalAccessRestore_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
$HtmlLogFile = "$LogDirectory\ConditionalAccessRestore_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').html"
$LogEntries = @()

# Webhooks Teams
$TeamsWebhookUrl = "https://m365x49418703.webhook.office.com/webhookb2/877876d7-2e60-490a-b390-2a7403c7e1d4@2a7dac32-723b-4d53-896c-4e864cd60080/IncomingWebhook/8c995232c0f84915bac3ca7d63e037e2/dc813e09-d917-4eae-b0bc-a22f08502f80/V2q9U5WkfbJA0489cQOcvAkIOrIwYrpogorKb1oxYfASQ1"
$CriticalChangesWebhookUrl = "https://m365x49418703.webhook.office.com/webhookb2/877876d7-2e60-490a-b390-2a7403c7e1d4@2a7dac32-723b-4d53-896c-4e864cd60080/IncomingWebhook/dd3c61c0a9514c4f895c2d2100d2677b/dc813e09-d917-4eae-b0bc-a22f08502f80/V2hcH5pCsWCYqxJ8iPyaf7YyXjxnuP6zu-nGrujWT4JSk1"

# -------------------------------------------------
# Fonctions de log, rapport HTML, notifications Teams, erreurs critiques (identique à ta version)
# -------------------------------------------------

function Write-LogMessage {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",
        [string]$Component = "Main"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] [$Component] $Message"
    
    # Créer le répertoire de logs s'il n'existe pas
    if (-not (Test-Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }
    
    # Écrire dans le fichier de log texte
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
    
    # Ajouter à la collection pour HTML
    $Script:LogEntries += [PSCustomObject]@{
        Timestamp = $Timestamp
        Level = $Level
        Component = $Component
        Message = $Message
    }
    
    # Afficher à l'écran avec couleurs
    $Color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "DEBUG"   { "Gray" }
    }
    
    Write-Host $LogEntry -ForegroundColor $Color
}

# -------------------------
# Fonction de génération du rapport HTML
# -------------------------
function Generate-HtmlReport {
    $HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Rapport de Restauration Accès Conditionnel - $TargetConditionalAccessName</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .summary { background: white; padding: 15px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .logs-container { background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        table { width: 100%; border-collapse: collapse; }
        th { background-color: #2c3e50; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ecf0f1; }
        .INFO { border-left: 4px solid #3498db; }
        .SUCCESS { border-left: 4px solid #27ae60; background-color: #d5f4e6; }
        .WARNING { border-left: 4px solid #f39c12; background-color: #fef9e7; }
        .ERROR { border-left: 4px solid #e74c3c; background-color: #fadbd8; }
        .DEBUG { border-left: 4px solid #95a5a6; background-color: #f8f9fa; }
        .timestamp { color: #7f8c8d; font-size: 0.9em; }
        .component { background-color: #ecf0f1; padding: 4px 8px; border-radius: 4px; font-size: 0.8em; }
        .footer { text-align: center; color: #7f8c8d; margin-top: 20px; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔐 Rapport de Restauration Accès Conditionnel M365DSC</h1>
        <p><strong>Stratégie:</strong> $TargetConditionalAccessName</p>
        <p><strong>Date d'exécution:</strong> $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')</p>
    </div>
    
    <div class="summary">
        <h2>📊 Résumé d'exécution</h2>
        <p><strong>Durée totale:</strong> $TotalDuration secondes</p>
        <p><strong>Nombre d'entrées de log:</strong> $($LogEntries.Count)</p>
        <p><strong>Fichier de configuration:</strong> $FilePS1_M365TenantConfig</p>
        <p><strong>Script généré:</strong> $OutputPs1Path</p>
    </div>
    
    <div class="logs-container">
        <table>
            <thead>
                <tr>
                    <th>⏰ Horodatage</th>
                    <th>📋 Niveau</th>
                    <th>🔧 Composant</th>
                    <th>💬 Message</th>
                </tr>
            </thead>
            <tbody>
"@

    foreach ($entry in $LogEntries) {
        $HtmlContent += @"
                <tr class="$($entry.Level)">
                    <td class="timestamp">$($entry.Timestamp)</td>
                    <td><span class="component">$($entry.Level)</span></td>
                    <td>$($entry.Component)</td>
                    <td>$($entry.Message)</td>
                </tr>
"@
    }

    $HtmlContent += @"
            </tbody>
        </table>
    </div>
    
    <div class="footer">
        <p>Généré par Extract_ConditionalAccess_Enhanced.ps1 - M365DSC Conditional Access Restore</p>
    </div>
</body>
</html>
"@

    Set-Content -Path $HtmlLogFile -Value $HtmlContent -Encoding UTF8
}

# -------------------------
# Fonction d'envoi Teams pour restauration accès conditionnel
# -------------------------
function Send-ConditionalAccessRestoreTeamsNotification {
    param (
        [string]$Message,
        [string]$Status,
        [string]$WebhookUrl = $TeamsWebhookUrl,
        [string]$ConditionalAccessName = $TargetConditionalAccessName,
        [string]$Step = "",
        [System.Collections.Hashtable]$Details = $null
    )

    $Payload = @{
        "@type"      = "MessageCard"
        "@context"   = "http://schema.org/extensions"
        "themeColor" = switch ($Status) {
            "Success" { "00FF00" }
            "Failure" { "FF0000" }
            "Warning" { "FFFF00" }
            "Info"    { "0078D4" }
            default   { "808080" }
        }
        "summary"    = "Restauration Accès Conditionnel M365DSC"
        "sections"   = @(
            @{
                "activityTitle"    = "🔐 Restauration DSC - Accès Conditionnel AzureAD/EntraID"
                "activitySubtitle" = "Statut : $Status"
                "activityImage"    = "https://raw.githubusercontent.com/Serge972/logosDSC365/main/Azure.png"
                "facts"            = @(
                    @{ "name" = "🔐 Stratégie"; "value" = $ConditionalAccessName },
                    @{ "name" = "📋 Étape"; "value" = $Step },
                    @{ "name" = "💬 Message"; "value" = $Message },
                    @{ "name" = "⏰ Horodatage"; "value" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
                )
                "text"             = ""
            }
        )
    }

    # Ajouter des détails supplémentaires si fournis
    if ($Details -and $Details.Count -gt 0) {
        foreach ($detail in $Details.GetEnumerator()) {
            $Payload.sections[0].facts += @{ "name" = $detail.Key; "value" = $detail.Value }
        }
    }

    $JsonPayload = $Payload | ConvertTo-Json -Depth 4 -Compress
    
    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -ContentType 'application/json; charset=utf-8' -Body $JsonPayload
        Write-LogMessage "Notification Teams envoyée avec succès pour l'étape: $Step" "SUCCESS" "TeamsNotification"
    }
    catch {
        Write-LogMessage "Erreur d'envoi Teams pour l'étape $Step : $_" "ERROR" "TeamsNotification"
    }
}

# -------------------------
# Fonction de gestion des erreurs critiques
# -------------------------
function Send-CriticalErrorNotification {
    param (
        [string]$ErrorMessage,
        [string]$Step,
        [string]$Exception = ""
    )
    
    Write-LogMessage "ERREUR CRITIQUE dans l'étape '$Step': $ErrorMessage" "ERROR" "CriticalError"
    
    $Details = @{
        "🚨 Type d'erreur" = "CRITIQUE"
        "⚠️ Exception" = if ($Exception) { $Exception } else { "Non spécifiée" }
        "📁 Fichier log" = $LogFile
    }
    
    Send-ConditionalAccessRestoreTeamsNotification -Message $ErrorMessage -Status "Failure" -WebhookUrl $CriticalChangesWebhookUrl -Step $Step -Details $Details
}

# -------------------------
# Début du script principal
# -------------------------
Write-LogMessage "========================================" "INFO" "Startup"
Write-LogMessage "DÉMARRAGE - Script Extract_ConditionalAccess Enhanced" "INFO" "Startup"
Write-LogMessage "Stratégie d'accès conditionnel cible: $TargetConditionalAccessName" "INFO" "Startup"
Write-LogMessage "Fichier de configuration: $FilePS1_M365TenantConfig" "INFO" "Startup"
Write-LogMessage "========================================" "INFO" "Startup"



# === Étape 1 : Vérification du fichier source ===
Write-LogMessage "ÉTAPE 1: Vérification du fichier source" "INFO" "FileValidation"

if (-not (Test-Path $FilePS1_M365TenantConfig)) {
    $ErrorMsg = "Le fichier $FilePS1_M365TenantConfig n'existe pas."
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "1️⃣ Vérification fichier source"
    exit 1
}

Write-LogMessage "Fichier source trouvé et accessible" "SUCCESS" "FileValidation"
Send-ConditionalAccessRestoreTeamsNotification -Message "Fichier de configuration M365DSC trouvé et accessible" -Status "Success" -Step "1️⃣ Vérification fichier source"

# === Étape 2 : Lecture et analyse du contenu ===
Write-LogMessage "ÉTAPE 2: Lecture et analyse du contenu du fichier" "INFO" "ContentAnalysis"

try {
    $content = Get-Content -Path $FilePS1_M365TenantConfig -Raw
    $contentSize = [math]::Round($content.Length / 1KB, 2)
    Write-LogMessage "Contenu lu avec succès. Taille: $contentSize KB" "SUCCESS" "ContentAnalysis"
}
catch {
    $ErrorMsg = "Impossible de lire le fichier: $($_.Exception.Message)"
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "2️⃣ Lecture fichier" -Exception $_.Exception.Message
    exit 1
}

$resourceName = "AADConditionalAccessPolicy-$TargetConditionalAccessName"
Write-LogMessage "Recherche du bloc ressource: $resourceName" "INFO" "ContentAnalysis"

# === Étape 3 : Extraction du bloc AADConditionalAccessPolicy ===
Write-LogMessage "ÉTAPE 3: Extraction du bloc AADConditionalAccessPolicy" "INFO" "BlockExtraction"

# Recherche du bloc AADConditionalAccessPolicy
$startIndex = $content.IndexOf("AADConditionalAccessPolicy `"$resourceName`"")
if ($startIndex -lt 0) {
    $ErrorMsg = "Aucun bloc AADConditionalAccessPolicy trouvé pour $TargetConditionalAccessName"
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "3️⃣ Extraction bloc AADConditionalAccessPolicy"
    exit 1
}

Write-LogMessage "Bloc AADConditionalAccessPolicy trouvé à l'index: $startIndex" "SUCCESS" "BlockExtraction"

$braceStartIndex = $content.IndexOf("{", $startIndex)
if ($braceStartIndex -lt 0) {
    $ErrorMsg = "Accolade ouvrante introuvable."
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "3️⃣ Extraction bloc AADConditionalAccessPolicy"
    exit 1
}

Write-LogMessage "Accolade ouvrante trouvée à l'index: $braceStartIndex" "DEBUG" "BlockExtraction"

# Extraction du bloc entre accolades
function Extract-BlockContent {
    param (
        [string]$text,
        [int]$startIndex
    )
    $braceCount = 0
    $pos = $startIndex
    while ($pos -lt $text.Length) {
        if ($text[$pos] -eq '{') { $braceCount++ }
        elseif ($text[$pos] -eq '}') { $braceCount-- }
        $pos++
        if ($braceCount -eq 0) {
            return $text.Substring($startIndex, $pos - $startIndex)
        }
    }
    return $null
}

$rawBlock = Extract-BlockContent -text $content -startIndex $braceStartIndex
if (-not $rawBlock) {
    $ErrorMsg = "Impossible d'extraire le bloc AADConditionalAccessPolicy."
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "3️⃣ Extraction bloc AADConditionalAccessPolicy"
    exit 1
}

$blockSize = [math]::Round($rawBlock.Length / 1KB, 2)
Write-LogMessage "Bloc AADConditionalAccessPolicy extrait avec succès. Taille: $blockSize KB" "SUCCESS" "BlockExtraction"

# === Étape 4 : Nettoyage et transformation du bloc ===
Write-LogMessage "ÉTAPE 4: Nettoyage et transformation du bloc" "INFO" "BlockProcessing"

# Nettoyage et remplacement des variables
$cleanedBlockLines = $rawBlock -split "`n" | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '{' -or $line -eq '}') { return }
    $line = $line -replace '\$ConfigurationData\.NonNodeData\.ApplicationId', '$ApplicationId'
    $line = $line -replace '\$ConfigurationData\.NonNodeData\.CertificateThumbprint', '$CertificateThumbprint'
    $line = $line -replace '\$OrganizationName', '$TenantId'
    return $line
}

$processedLines = ($cleanedBlockLines | Where-Object { $_ -ne $null }).Count
Write-LogMessage "Transformation terminée. $processedLines lignes traitées" "SUCCESS" "BlockProcessing"

$indentedBlock = $cleanedBlockLines | ForEach-Object { "            $_" } | Out-String

# === Étape 5 : Génération du script de restauration ===
Write-LogMessage "ÉTAPE 5: Génération du script de restauration" "INFO" "ScriptGeneration"

# Bloc param() DSC
$paramBlock = @'
    param(
        [Parameter(Mandatory = $true)]
        [String]$ApplicationId,

        [Parameter(Mandatory = $true)]
        [String]$CertificateThumbprint,

        [Parameter(Mandatory = $true)]
        [String]$TenantId
    )
'@

# Construction du script RestoreConditionalAccess.ps1
$scriptContent = @"
Configuration RestoreConditionalAccess
{
$paramBlock

    Import-DscResource -ModuleName Microsoft365DSC

    Node localhost
    {
        AADConditionalAccessPolicy `"$resourceName`" {
$indentedBlock
        }
    }
}
"@

# === Étape 6 : Sauvegarde du script ===
Write-LogMessage "ÉTAPE 6: Sauvegarde du script de restauration" "INFO" "ScriptSave"

$dir = Split-Path -Path $OutputPs1Path -Parent
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-LogMessage "Répertoire créé: $dir" "INFO" "ScriptSave"
}

try {
    Set-Content -Path $OutputPs1Path -Value $scriptContent -Encoding UTF8
    $fileInfo = Get-Item $OutputPs1Path
    $fileSize = [math]::Round($fileInfo.Length / 1KB, 2)
    Write-LogMessage "Script sauvegardé avec succès. Taille: $fileSize KB" "SUCCESS" "ScriptSave"
    
    $Details = @{
        "📁 Chemin" = $OutputPs1Path
        "📊 Taille" = "$fileSize KB"
        "🔧 Lignes traitées" = $processedLines
    }
    Send-ConditionalAccessRestoreTeamsNotification -Message "Script RestoreConditionalAccess.ps1 généré avec succès" -Status "Success" -Step "6️⃣ Génération script" -Details $Details
}
catch {
    $ErrorMsg = "Erreur lors de la sauvegarde: $($_.Exception.Message)"
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "6️⃣ Sauvegarde script" -Exception $_.Exception.Message
    exit 1
}

# === Étape 7 : Chargement et compilation DSC ===
Write-LogMessage "ÉTAPE 7: Chargement et compilation DSC" "INFO" "DSCCompilation"

try {
    . $OutputPs1Path
    Write-LogMessage "Script RestoreConditionalAccess.ps1 chargé avec succès" "SUCCESS" "DSCCompilation"
    
    $compilationStart = Get-Date
    RestoreConditionalAccess -ApplicationId $ApplicationId -CertificateThumbprint $CertificateThumbprint -TenantId $TenantId
    $compilationEnd = Get-Date
    $compilationDuration = [math]::Round(($compilationEnd - $compilationStart).TotalSeconds, 2)
    
    Write-LogMessage "Compilation DSC réussie en $compilationDuration secondes" "SUCCESS" "DSCCompilation"
    
    $Details = @{
        "⏱️ Durée compilation" = "$compilationDuration secondes"
        "🔑 ApplicationId" = $ApplicationId
        "🏢 TenantId" = $TenantId
    }
    Send-ConditionalAccessRestoreTeamsNotification -Message "Compilation DSC terminée avec succès" -Status "Success" -Step "7️⃣ Compilation DSC" -Details $Details
}
catch {
    $ErrorMsg = "Erreur compilation/chargement DSC: $($_.Exception.Message)"
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "7️⃣ Compilation DSC" -Exception $_.Exception.Message
    exit 1
}

# === Étape 8 : Application directe de la configuration DSC (sans test préalable) ===
Write-LogMessage "ÉTAPE 8: Génération et application de la configuration DSC baseline" "INFO" "DSCApplication"

try {
    # Génération du fichier MOF à jour
    $MofOutputPath = "C:\Script_complet\Scripts OK - PF Juin 2025\TEMPLATE_RESTO_OK\CONDITIONALACCESS\RestoreMOF"
    if (-not (Test-Path $MofOutputPath)) { 
        New-Item -ItemType Directory -Path $MofOutputPath -Force | Out-Null 
    }
    $mofPath = Join-Path $MofOutputPath "localhost.mof"
    if (Test-Path $mofPath) { Remove-Item -Path $mofPath -Force -ErrorAction SilentlyContinue }
    
    . $OutputPs1Path
    RestoreConditionalAccess -ApplicationId $ApplicationId `
                             -CertificateThumbprint $CertificateThumbprint `
                             -TenantId $TenantId `
                             -OutputPath $MofOutputPath

    # Attente de génération du fichier MOF (max 10s)
    $mofWaitMax = 10
    $mofWaitCount = 0
    while (-not (Test-Path $mofPath) -and $mofWaitCount -lt $mofWaitMax) {
        Write-LogMessage "⏳ Attente génération du fichier MOF ($mofWaitCount/$mofWaitMax)..." "DEBUG" "DSCApplication"
        Start-Sleep -Seconds 1
        $mofWaitCount++
    }
    if (-not (Test-Path $mofPath)) {
        throw "❌ Le fichier MOF n’a pas été généré dans le dossier '$MofOutputPath' après $mofWaitMax secondes."
    } else {
        $mofInfo = Get-Item $mofPath
        Write-LogMessage "✅ Fichier MOF généré avec succès : $($mofInfo.FullName) - Taille : $([Math]::Round($mofInfo.Length / 1KB, 1)) KB" "SUCCESS" "DSCApplication"
    }

    # Application directe du fichier MOF (corrige toute dérive automatiquement)
    Write-LogMessage "Application de la configuration DSC via Start-DscConfiguration" "INFO" "DSCApplication"
    $applicationStart = Get-Date
    Start-DscConfiguration -Path $MofOutputPath -Wait -Verbose -Force
    $applicationEnd = Get-Date
    $applicationDuration = [math]::Round(($applicationEnd - $applicationStart).TotalSeconds, 2)
    Write-LogMessage "✅ Configuration DSC appliquée avec succès en $applicationDuration secondes." "SUCCESS" "DSCApplication"
}
catch {
    $ErrorMsg = "Erreur lors de la génération ou l'application de la configuration DSC : $($_.Exception.Message)"
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "8️⃣ DSCApplication" -Exception $_.Exception.Message
    exit 1
}



# === Étape 9 : Application de la configuration ===
Write-LogMessage "ÉTAPE 9: Application de la configuration DSC" "INFO" "DSCApplication"

try {
    $applicationStart = Get-Date
    Start-DscConfiguration -Path .\RestoreConditionalAccess -Wait -Verbose -Force
    $applicationEnd = Get-Date
    $applicationDuration = [math]::Round(($applicationEnd - $applicationStart).TotalSeconds, 2)
    
    Write-LogMessage "Configuration DSC appliquée avec succès en $applicationDuration secondes" "SUCCESS" "DSCApplication"
    
    $Details = @{
        "⏱️ Durée application" = "$applicationDuration secondes"
        "✅ Statut" = "Configuration appliquée"
        "📁 Chemin config" = ".\RestoreConditionalAccess"
    }
    Send-ConditionalAccessRestoreTeamsNotification -Message "Configuration DSC appliquée avec succès" -Status "Success" -Step "9️⃣ Application DSC" -Details $Details
}
catch {
    $ErrorMsg = "Échec application de la configuration DSC: $($_.Exception.Message)"
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "9️⃣ Application DSC" -Exception $_.Exception.Message
    exit 1
}

# === Étape 10 : Vérification post-application améliorée ===
Write-LogMessage "ÉTAPE 10: Vérification post-application" "INFO" "PostVerification"

try {
    # Paramètres de retry
    $maxRetries = 6
    $retryDelay = 10  # secondes
    $retryCount = 0
    $policyFound = $false
    
    Write-LogMessage "Démarrage de la vérification avec retry (max $maxRetries tentatives, délai $retryDelay sec)" "INFO" "PostVerification"
    
    do {
        $retryCount++
        Write-LogMessage "Tentative $retryCount/$maxRetries - Recherche de la stratégie..." "INFO" "PostVerification"
        
        try {
            # Reconnexion au Graph pour s'assurer de la fraîcheur des données
            if ($retryCount -gt 1) {
                Write-LogMessage "Reconnexion à Microsoft Graph pour actualiser les données" "INFO" "PostVerification"
                Disconnect-MgGraph -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Connect-MgGraph -ClientId $ApplicationId -TenantId $TenantId -CertificateThumbprint $CertificateThumbprint -NoWelcome
            }
            
            # Recherche de la stratégie avec différentes méthodes
            $newPolicy = $null
            
            # Méthode 1: Recherche par nom exact
            Write-LogMessage "Recherche par nom exact: '$TargetConditionalAccessName'" "DEBUG" "PostVerification"
            $newPolicy = Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq '$TargetConditionalAccessName'" -ErrorAction SilentlyContinue
            
            # Méthode 2: Si pas trouvé, recherche sans filtre puis filtrage manuel
            if (-not $newPolicy) {
                Write-LogMessage "Recherche sans filtre puis filtrage manuel..." "DEBUG" "PostVerification"
                $allPolicies = Get-MgIdentityConditionalAccessPolicy -All -ErrorAction SilentlyContinue
                $newPolicy = $allPolicies | Where-Object { $_.DisplayName -eq $TargetConditionalAccessName }
            }
            
            # Méthode 3: Recherche avec Contains si toujours pas trouvé
            if (-not $newPolicy) {
                Write-LogMessage "Recherche avec Contains..." "DEBUG" "PostVerification"
                $newPolicy = Get-MgIdentityConditionalAccessPolicy -Filter "contains(displayName, '$TargetConditionalAccessName')" -ErrorAction SilentlyContinue
            }
            
            if ($newPolicy) {
                $policyFound = $true
                Write-LogMessage "✅ SUCCÈS : L'accès conditionnel '$TargetConditionalAccessName' a été trouvé !" "SUCCESS" "PostVerification"
                Write-LogMessage "ID de la stratégie: $($newPolicy.Id)" "SUCCESS" "PostVerification"
                Write-LogMessage "État de la stratégie: $($newPolicy.State)" "SUCCESS" "PostVerification"
                Write-LogMessage "Date de création: $($newPolicy.CreatedDateTime)" "SUCCESS" "PostVerification"
                
                # Vérification détaillée des propriétés
                $policyDetails = @{
                    "🆔 ID stratégie" = $newPolicy.Id
                    "📊 État" = $newPolicy.State
                    "🕒 Date création" = $newPolicy.CreatedDateTime
                    "🔍 Tentative trouvée" = "$retryCount/$maxRetries"
                    "✅ Statut" = "Créée et vérifiée avec succès"
                }
                
                # Vérification des conditions et contrôles
                if ($newPolicy.Conditions) {
                    Write-LogMessage "Conditions configurées: Applications, Utilisateurs, Emplacements, etc." "INFO" "PostVerification"
                    $policyDetails["📋 Conditions"] = "Configurées"
                }
                
                if ($newPolicy.GrantControls) {
                    Write-LogMessage "Contrôles d'accès configurés: $($newPolicy.GrantControls.Operator)" "INFO" "PostVerification"
                    $policyDetails["🔐 Contrôles"] = $newPolicy.GrantControls.Operator
                }
                
                Send-ConditionalAccessRestoreTeamsNotification -Message "✅ Vérification post-application réussie" -Status "Success" -Step "🔍 Vérification finale" -Details $policyDetails
                
                break
            }
            else {
                Write-LogMessage "❌ Tentative $retryCount/$maxRetries : Stratégie non trouvée" "WARNING" "PostVerification"
                
                if ($retryCount -lt $maxRetries) {
                    Write-LogMessage "Attente de $retryDelay secondes avant la prochaine tentative..." "INFO" "PostVerification"
                    Start-Sleep -Seconds $retryDelay
                }
            }
        }
        catch {
            Write-LogMessage "Erreur lors de la tentative $retryCount : $($_.Exception.Message)" "WARNING" "PostVerification"
            if ($retryCount -lt $maxRetries) {
                Start-Sleep -Seconds $retryDelay
            }
        }
        
    } while (-not $policyFound -and $retryCount -lt $maxRetries)
    
    # Résultat final
    if (-not $policyFound) {
        Write-LogMessage "⚠️ ATTENTION : La stratégie n'a pas été trouvée après $maxRetries tentatives" "WARNING" "PostVerification"
        Write-LogMessage "Cela peut être dû à un délai de propagation dans Azure AD" "WARNING" "PostVerification"
        Write-LogMessage "Vérifiez manuellement dans le portail Azure AD dans quelques minutes" "WARNING" "PostVerification"
        
        # Vérification alternative via le module AzureAD si disponible
        try {
            if (Get-Module -ListAvailable -Name AzureAD) {
                Write-LogMessage "Tentative de vérification via le module AzureAD..." "INFO" "PostVerification"
                Import-Module AzureAD -Force
                Connect-AzureAD -TenantId $TenantId -ErrorAction SilentlyContinue
                $azureAdPolicy = Get-AzureADMSConditionalAccessPolicy | Where-Object { $_.DisplayName -eq $TargetConditionalAccessName }
                if ($azureAdPolicy) {
                    Write-LogMessage "✅ Stratégie trouvée via AzureAD module : $($azureAdPolicy.Id)" "SUCCESS" "PostVerification"
                    $policyFound = $true
                }
            }
        }
        catch {
            Write-LogMessage "Vérification AzureAD échouée: $($_.Exception.Message)" "DEBUG" "PostVerification"
        }
        
        $warningDetails = @{
            "⚠️ Statut" = "Stratégie non trouvée immédiatement"
            "🔍 Tentatives" = "$retryCount/$maxRetries"
            "⏱️ Délai total" = "$($retryCount * $retryDelay) secondes"
            "📋 Action recommandée" = "Vérification manuelle dans Azure AD"
            "🌐 Portail Azure" = "https://portal.azure.com/#blade/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/Policies"
        }
        
        Send-ConditionalAccessRestoreTeamsNotification -Message "⚠️ Stratégie non trouvée immédiatement - Vérification manuelle recommandée" -Status "Warning" -Step "🔍 Vérification finale" -Details $warningDetails
    }
}
catch {
    $ErrorMsg = "Erreur lors de la vérification post-application: $($_.Exception.Message)"
    Write-LogMessage $ErrorMsg "ERROR" "PostVerification"
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "🔍 Vérification finale" -Exception $_.Exception.Message
}

# === Fonction de vérification manuelle recommandée ===
function Show-ManualVerificationInstructions {
    Write-LogMessage "========================================" "INFO" "ManualVerification"
    Write-LogMessage "INSTRUCTIONS DE VÉRIFICATION MANUELLE" "INFO" "ManualVerification"
    Write-LogMessage "========================================" "INFO" "ManualVerification"
    Write-LogMessage "1. Ouvrez le portail Azure AD : https://portal.azure.com" "INFO" "ManualVerification"
    Write-LogMessage "2. Accédez à Azure AD > Sécurité > Accès conditionnel" "INFO" "ManualVerification"
    Write-LogMessage "3. Recherchez la stratégie : $TargetConditionalAccessName" "INFO" "ManualVerification"
    Write-LogMessage "4. Vérifiez l'état et la configuration" "INFO" "ManualVerification"
    Write-LogMessage "========================================" "INFO" "ManualVerification"
}

# Si la stratégie n'est pas trouvée, afficher les instructions
if (-not $policyFound) {
    Show-ManualVerificationInstructions
}

# === Étape 11 : Test de la stratégie (optionnel) ===
Write-LogMessage "ÉTAPE 11: Test de la stratégie (optionnel)" "INFO" "PolicyTest"

if ($policyFound -and $newPolicy) {
    try {
        # Test de base : récupération des détails
        $policyDetails = Get-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $newPolicy.Id
        
        if ($policyDetails) {
            Write-LogMessage "✅ Test réussi : Stratégie accessible par ID" "SUCCESS" "PolicyTest"
            Write-LogMessage "Nombre de conditions: $($policyDetails.Conditions.PSObject.Properties.Count)" "INFO" "PolicyTest"
            
            # Test des contrôles d'accès
            if ($policyDetails.GrantControls) {
                Write-LogMessage "Contrôles d'accès: $($policyDetails.GrantControls.BuiltInControls -join ', ')" "INFO" "PolicyTest"
            }
            
            # Test des contrôles de session
            if ($policyDetails.SessionControls) {
                Write-LogMessage "Contrôles de session configurés" "INFO" "PolicyTest"
            }
            
            $TestDetails = @{
                "🧪 Test" = "Accès par ID réussi"
                "📊 Conditions" = $policyDetails.Conditions.PSObject.Properties.Count
                "🔐 Contrôles" = if ($policyDetails.GrantControls) { "Configurés" } else { "Non configurés" }
                "✅ Statut test" = "Réussi"
            }
            
            Send-ConditionalAccessRestoreTeamsNotification -Message "Test de la stratégie réussi" -Status "Success" -Step "🧪 Test stratégie" -Details $TestDetails
        }
    }
    catch {
        Write-LogMessage "Erreur lors du test de la stratégie: $($_.Exception.Message)" "WARNING" "PolicyTest"
   }



try {
    $ScriptEndTime = Get-Date
    $TotalDuration = [math]::Round(($ScriptEndTime - $ScriptStartTime).TotalSeconds, 2)

    Write-LogMessage "SCRIPT TERMINÉ AVEC SUCCÈS en $TotalDuration secondes." "SUCCESS" "Completion"
    Generate-HtmlReport
    Write-LogMessage "Rapport HTML généré : $HtmlLogFile" "SUCCESS" "HtmlReport"
    Write-Host "`n🎉 Script terminé en $TotalDuration secondes. Rapport disponible : $HtmlLogFile" -ForegroundColor Green
} catch {
    $ScriptEndTime = Get-Date
    $TotalDuration = [math]::Round(($ScriptEndTime - $ScriptStartTime).TotalSeconds, 2)
    Write-LogMessage "SCRIPT TERMINÉ AVEC ÉCHEC en $TotalDuration secondes." "ERROR" "Completion"
    Generate-HtmlReport
    Write-Host "`n❌ Le script a terminé avec une erreur. Rapport disponible : $HtmlLogFile" -ForegroundColor Red
    exit 1
}
}
# --------- FIN DU SCRIPT ---------
