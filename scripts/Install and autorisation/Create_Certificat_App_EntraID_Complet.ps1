# ==== CONFIGURATION ====
$CertName       = "SharepointJuillet2025_cert"
$CertPath       = "C:\certificat"
$PfxPasswordRaw = "648q4*s[+RFfN,Uy_P5z!"  # À adapter si besoin
$ImportToLocalMachine = $true    # 👉 True = LocalMachine, False = CurrentUser

# ==== PRÉPARATION ====
if (-not (Test-Path -Path $CertPath)) {
    New-Item -ItemType Directory -Path $CertPath | Out-Null
}

$SecurePwd = ConvertTo-SecureString -String $PfxPasswordRaw -AsPlainText -Force
$StoreLocation = if ($ImportToLocalMachine) { "Cert:\LocalMachine\My" } else { "Cert:\CurrentUser\My" }

# ==== VÉRIFICATION EXISTENCE CERTIFICAT ====
$existingCert = Get-ChildItem -Path $StoreLocation | Where-Object { $_.Subject -eq "CN=$CertName" }

if ($existingCert) {
    Write-Host "⚠️ Le certificat '$CertName' existe déjà dans $StoreLocation. Aucune action de création effectuée." -ForegroundColor Yellow
    $cert = $existingCert
} else {
    Write-Host "🛠️ Création du certificat auto-signé '$CertName'..."
    $cert = New-SelfSignedCertificate `
        -Subject "CN=$CertName" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeySpec Signature `
        -KeyLength 2048 `
        -NotAfter (Get-Date).AddYears(2) `
        -FriendlyName $CertName
}

# ==== EXPORT .CER & .PFX ====
$CerPath = Join-Path $CertPath "$CertName.cer"
$PfxPath = Join-Path $CertPath "$CertName.pfx"

Export-Certificate -Cert $cert -FilePath $CerPath -Force | Out-Null

# Pour éviter les erreurs si la clé n’est pas exportable :
try {
    Export-PfxCertificate -Cert $cert -FilePath $PfxPath -Password $SecurePwd -Force | Out-Null
}
catch {
    Write-Error "❌ Échec de l'export PFX. La clé privée n'est peut-être pas exportable sur cette version de Windows."
    exit 1
}

# ==== IMPORT PFX (optionnel, si import dans LocalMachine) ====
if ($ImportToLocalMachine) {
    Write-Host "🔄 Importation du certificat dans le magasin : LocalMachine\My"
    Import-PfxCertificate -FilePath $PfxPath -CertStoreLocation "Cert:\LocalMachine\My" -Password $SecurePwd -Exportable | Out-Null
}

# ==== INFOS ====
Write-Host "`n✅ Certificat prêt dans : $StoreLocation"
Write-Host "📄 Export .cer     : $CerPath"
Write-Host "🔐 Export .pfx     : $PfxPath"
Write-Host "🔑 Thumbprint      : $($cert.Thumbprint)"
Write-Host "📌 Mot de passe .pfx : $PfxPasswordRaw`n"