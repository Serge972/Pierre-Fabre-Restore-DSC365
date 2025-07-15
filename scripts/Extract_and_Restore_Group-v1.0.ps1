<#
------------------------------------------------------------
Auteur       : Serge THEZENAS
Fonction     : Consultant M365
Client       : Client Pierre FABRE
Projet       : Extract + Restore + Notifications TEAMS + Logs HTML
Module       : AZURE AD
Date         : 2025-07-13
Objectif     : Exporter la configuration AZURE AD d'un groupe, le restaurer à son état d'origine,
               générer un rapport HTML, et notifier par Teams et par mail.
Script ID    : AZUREAD-EXTRACT-RESTORE-GROUP-v1.0
------------------------------------------------------------


#>


# ========================================
# Script Extract_User.ps1
# Extraction + Restauration DSC complète avec logs et notifications
# ========================================

# === Paramètres pré-remplis ===
$FilePS1_M365TenantConfig        = "C:\Export_Complet\Baseline_AZUREAD_ENTRAID_M365DSC_ExportConf_2025-07-08_10-15-50\M365TenantConfig.ps1"
$TargetGroupDisplayName = "sg-IT"  # ← Remplacez par le nom du groupe
$OutputPs1Path           = "C:\Script_complet\Scripts OK - PF Juin 2025\TEMPLATE_RESTO_OK\GROUP\TEST_GROUP\Restore_Group_$TargetGroupDisplayName.ps1"

$ApplicationId           = "d8675be3-7948-43f5-b523-65cb92f49cc6"
$TenantId                = "M365x49418703.onmicrosoft.com"
$CertificateThumbprint   = "75957FDE297FEACA776AC429A970578B18CF0A66"

# === Configuration des logs et notifications ===
$LogDirectory = "C:\Script_complet\Scripts OK - PF Juin 2025\TEMPLATE_RESTO_OK\GROUP\TEST_GROUP\LOG"
$LogFile = "$LogDirectory\GroupRestore_$TargetGroupDisplayName_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
$ScriptStartTime = Get-Date

# === Configuration des logs HTML ===
$HtmlLogFile = "$LogDirectory\GroupRestore_$TargetGroupDisplayName_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').html"
$LogEntries = @()

# Webhooks Teams
$TeamsWebhookUrl = "https://m365x49418703.webhook.office.com/webhookb2/877876d7-2e60-490a-b390-2a7403c7e1d4@2a7dac32-723b-4d53-896c-4e864cd60080/IncomingWebhook/8c995232c0f84915bac3ca7d63e037e2/dc813e09-d917-4eae-b0bc-a22f08502f80/V2q9U5WkfbJA0489cQOcvAkIOrIwYrpogorKb1oxYfASQ1"
$CriticalChangesWebhookUrl = "https://m365x49418703.webhook.office.com/webhookb2/877876d7-2e60-490a-b390-2a7403c7e1d4@2a7dac32-723b-4d53-896c-4e864cd60080/IncomingWebhook/dd3c61c0a9514c4f895c2d2100d2677b/dc813e09-d917-4eae-b0bc-a22f08502f80/V2hcH5pCsWCYqxJ8iPyaf7YyXjxnuP6zu-nGrujWT4JSk1"


# -------------------------
# Fonction de logging avancée avec HTML
# -------------------------
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
    <title>Rapport de Restauration Groupe - $TargetGroupDisplayName</title>  # ← Changé
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
        <h1>🔄 Rapport de Restauration Groupe M365DSC</h1>
        <p><strong>Groupe:</strong> $TargetGroupDisplayName</p>
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
        <p>Généré par Extract_User_Enhanced.ps1 - M365DSC User Restore</p>
    </div>
</body>
</html>
"@

    Set-Content -Path $HtmlLogFile -Value $HtmlContent -Encoding UTF8
}


# -------------------------
# Fonction d'envoi Teams pour restauration groupe
# -------------------------
function Send-GroupRestoreTeamsNotification {
    param (
        [string]$Message,
        [string]$Status,
        [string]$WebhookUrl = $TeamsWebhookUrl,
        [string]$GroupDisplayName = $TargetGroupDisplayName,  # ← Changé
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
        "summary"    = "Restauration Groupe M365DSC"  # ← Changé
        "sections"   = @(
            @{
                "activityTitle"    = "👥 Restauration DSC - Groupe AzureAD/EntraID"  # ← Changé
                "activitySubtitle" = "Statut : $Status"
                "activityImage"    = "https://raw.githubusercontent.com/Serge972/logosDSC365/main/Azure.png"
                "facts"            = @(
                    @{ "name" = "👥 Groupe"; "value" = $GroupDisplayName },  # ← Changé
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
    
    Send-GroupRestoreTeamsNotification -Message $ErrorMessage -Status "Failure" -WebhookUrl $CriticalChangesWebhookUrl -Step $Step -Details $Details
}

# -------------------------
# Début du script principal
# -------------------------
Write-LogMessage "========================================" "INFO" "Startup"
Write-LogMessage "DÉMARRAGE - Script Extract_Group Enhanced" "INFO" "Startup"  # ← Changé
Write-LogMessage "Groupe cible: $TargetGroupDisplayName" "INFO" "Startup"  # ← Changé
Write-LogMessage "Fichier de configuration: $FilePS1_M365TenantConfig" "INFO" "Startup"
Write-LogMessage "========================================" "INFO" "Startup"

# Notification de démarrage
Send-GroupRestoreTeamsNotification -Message "Démarrage de la restauration groupe" -Status "Info" -Step "🚀 Initialisation"  # ← Changé le nom de la fonction

# === Étape 1 : Vérification du fichier source ===
Write-LogMessage "ÉTAPE 1: Vérification du fichier source" "INFO" "FileValidation"

if (-not (Test-Path $FilePS1_M365TenantConfig)) {
    $ErrorMsg = "Le fichier $FilePS1_M365TenantConfig n'existe pas."
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "1️⃣ Vérification fichier source"
    exit 1
}

Write-LogMessage "Fichier source trouvé et accessible" "SUCCESS" "FileValidation"
Send-GroupRestoreTeamsNotification -Message "Fichier de configuration M365DSC trouvé et accessible" -Status "Success" -Step "1️⃣ Vérification fichier source"

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

$resourceName = "AADGroup-$TargetGroupDisplayName"  # ← Changé
Write-LogMessage "Recherche du bloc ressource: $resourceName" "INFO" "ContentAnalysis"

# === Étape 3 : Extraction du bloc AADGroup ===
Write-LogMessage "ÉTAPE 3: Extraction du bloc AADGroup" "INFO" "BlockExtraction"  # ← Changé

# Recherche du bloc AADGroup
$startIndex = $content.IndexOf("AADGroup `"$resourceName`"")  # ← Changé
if ($startIndex -lt 0) {
    $ErrorMsg = "Aucun bloc AADGroup trouvé pour $TargetGroupDisplayName"  # ← Changé
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "3️⃣ Extraction bloc AADGroup"
    exit 1
}

Write-LogMessage "Bloc AADGroup trouvé à l'index: $startIndex" "SUCCESS" "BlockExtraction"  # ← Changé


$braceStartIndex = $content.IndexOf("{", $startIndex)
if ($braceStartIndex -lt 0) {
    $ErrorMsg = "Accolade ouvrante introuvable."
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "3️⃣ Extraction bloc AADUser"
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
    $ErrorMsg = "Impossible d'extraire le bloc AADUser."
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "3️⃣ Extraction bloc AADUser"
    exit 1
}

$blockSize = [math]::Round($rawBlock.Length / 1KB, 2)
Write-LogMessage "Bloc AADUser extrait avec succès. Taille: $blockSize KB" "SUCCESS" "BlockExtraction"

# === Étape 4 : Nettoyage et transformation du bloc ===
Write-LogMessage "ÉTAPE 4: Nettoyage et transformation du bloc" "INFO" "BlockProcessing"

# Nettoyage et remplacement des variables
$cleanedBlockLines = $rawBlock -split "`n" | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^\s*Password\s*=') { 
        Write-LogMessage "Ligne Password supprimée pour sécurité" "WARNING" "BlockProcessing"
        return 
    }
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

# Construction du script RestoreGroup.ps1
$scriptContent = @"
Configuration RestoreGroup  
{
$paramBlock

    Import-DscResource -ModuleName Microsoft365DSC

    Node localhost
    {
        AADGroup `"$resourceName`" {  
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
    Send-GroupRestoreTeamsNotification -Message "Script RestoreGroup.ps1 généré avec succès" -Status "Success" -Step "6️⃣ Génération script" -Details $Details
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
    Write-LogMessage "Script RestoreGroup.ps1 chargé avec succès" "SUCCESS" "DSCCompilation"  # ← Changé
    
    $compilationStart = Get-Date
    RestoreGroup -ApplicationId $ApplicationId -CertificateThumbprint $CertificateThumbprint -TenantId $TenantId  # ← Changé
    $compilationEnd = Get-Date
    $compilationDuration = [math]::Round(($compilationEnd - $compilationStart).TotalSeconds, 2)
    
    Write-LogMessage "Compilation DSC réussie en $compilationDuration secondes" "SUCCESS" "DSCCompilation"
    
    $Details = @{
        "⏱️ Durée compilation" = "$compilationDuration secondes"
        "🔑 ApplicationId" = $ApplicationId
        "🏢 TenantId" = $TenantId
    }
    Send-GroupRestoreTeamsNotification -Message "Compilation DSC terminée avec succès" -Status "Success" -Step "7️⃣ Compilation DSC" -Details $Details  # ← Changé le nom de la fonction
}
catch {
    $ErrorMsg = "Erreur compilation/chargement DSC: $($_.Exception.Message)"
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "7️⃣ Compilation DSC" -Exception $_.Exception.Message
    exit 1
}

# === Étape 8 : Application de la configuration ===
Write-LogMessage "ÉTAPE 8: Application de la configuration DSC" "INFO" "DSCApplication"

try {
    $applicationStart = Get-Date
    Start-DscConfiguration -Path .\RestoreGroup -Wait -Verbose -Force  # ← Changé
    $applicationEnd = Get-Date
    $applicationDuration = [math]::Round(($applicationEnd - $applicationStart).TotalSeconds, 2)
    
    Write-LogMessage "Configuration DSC appliquée avec succès en $applicationDuration secondes" "SUCCESS" "DSCApplication"
    
    $Details = @{
        "⏱️ Durée application" = "$applicationDuration secondes"
        "✅ Statut" = "Configuration appliquée"
        "📁 Chemin config" = ".\RestoreGroup"  # ← Changé
    }
    Send-GroupRestoreTeamsNotification -Message "Configuration DSC appliquée avec succès" -Status "Success" -Step "8️⃣ Application DSC" -Details $Details  # ← Changé le nom de la fonction
}
catch {
    $ErrorMsg = "Échec application de la configuration DSC: $($_.Exception.Message)"
    Send-CriticalErrorNotification -ErrorMessage $ErrorMsg -Step "8️⃣ Application DSC" -Exception $_.Exception.Message
    exit 1
}

# === Résumé final ===
$ScriptEndTime = Get-Date
$TotalDuration = [math]::Round(($ScriptEndTime - $ScriptStartTime).TotalSeconds, 2)

Write-LogMessage "========================================" "INFO" "Completion"
Write-LogMessage "SUCCÈS - Restauration utilisateur terminée" "SUCCESS" "Completion"
Write-LogMessage "Durée totale: $TotalDuration secondes" "INFO" "Completion"
Write-LogMessage "Fichier de log: $LogFile" "INFO" "Completion"
Write-LogMessage "========================================" "INFO" "Completion"


# Génération du rapport HTML
Generate-HtmlReport
Write-LogMessage "Rapport HTML généré: $HtmlLogFile" "SUCCESS" "HtmlReport"


# Notification finale de succès
Write-LogMessage "SUCCÈS - Restauration groupe terminée" "SUCCESS" "Completion"  # ← Changé

# Notification finale de succès
$FinalDetails = @{
    "⏱️ Durée totale" = "$TotalDuration secondes"
    "👥 Groupe restauré" = $TargetGroupDisplayName  # ← Changé
    "📋 Fichier log" = $LogFile
    "📊 Rapport HTML" = $HtmlLogFile
    "✅ Statut final" = "SUCCÈS COMPLET"
}

Send-GroupRestoreTeamsNotification -Message "🎉 Restauration groupe terminée avec succès !" -Status "Success" -Step "✅ Finalisation" -Details $FinalDetails  # ← Changé le nom de la fonction