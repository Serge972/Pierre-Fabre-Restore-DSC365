# Pierre-Fabre-Restore-DSC365
Pierre Fabre


# 🔐 Script M365DSC - Restauration Accès Conditionnel Azure AD

## Présentation

Ce script PowerShell permet :

- D'extraire une configuration **Conditional Access** d’un environnement **Azure Active Directory / EntraID** à l’aide de Microsoft365DSC.
- De restaurer une de ces stratégies via **DSC (Desired State Configuration)**.
- De générer un **rapport HTML détaillé** des opérations effectuées.
- D’envoyer des **notifications structurées** via Microsoft Teams.

---

## 🛠 Fonctionnalités

- 🔍 Extraction précise d'une seule stratégie nommée
- ✅ Nettoyage et mise à jour automatique des modules nécessaires
- 💬 Notifications Teams (succès, avertissements, échecs critiques)
- 📜 Logs détaillés (texte + HTML)
- ⏱ Mesure du temps total d'exécution
- 🔧 Application native de la configuration M365DSC via MOF

---

## 📂 Structure du projet
📁 Script/
├── Extract_ConditionalAccess.ps1
├── README.md
├── CHANGELOG.md
├── Publish-Package.ps1
└── Output/
├── Logs/
└── HTMLReports/




---

## ⚙️ Prérequis

- PowerShell 5.1 (obligatoire pour DSC local)
- Permissions d’administrateur
- Modules requis : `Microsoft365DSC`, `MicrosoftTeams`, `DSCParser`
- Un **App Registration avec certificat** disposant de l’accès à Microsoft Graph :
  - ApplicationId
  - TenantId
  - Certificate Thumbprint

---

## 🚀 Utilisation

.\Extract_ConditionalAccess.ps1

text

📌 Le script s'exécute avec vérification automatique des modules & dépendances.

---

## 📑 Paramètres clés (préremplis dans le script)

| Paramètre                  | Description                               |
|---------------------------|-------------------------------------------|
| `$ApplicationId`          | ID de l’application (App reg Graph)       |
| `$CertificateThumbprint` | Empreinte numérique de votre certificat   |
| `$TenantId`               | Nom de domaine Azure (ex : tenant.onmicrosoft.com) |
| `$TargetConditionalAccessName` | Nom exact de la stratégie ciblée |

---

## 📝 Fichier généré

- **`RestoreConditionalAccess.ps1`** : script DSC généré automatiquement
- **`localhost.mof`** : configuration compilée avec la stratégie sélectionnée
- **`*.log`, `*.html`** : trace complète lisible et exploitable

---

## 📬 Notifications

Les notifications Teams sont envoyées à :

- 📢 Canal standard : `$TeamsWebhookUrl`
- 🚨 Canal alertes critiques : `$CriticalChangesWebhookUrl`

---

## ✅ Exemple de résultat

![html-report-preview](https://raw.githubusercontent.com/Serge972/logosDSC365/main/example_html_dsc_preview.png)

---

## 🛡 Sécurité et permissions

Vérifiez que votre App Registration a au moins les permissions suivantes :

- `Policy.Read.All`, `Policy.ReadWrite.ConditionalAccess`
- `Directory.Read.All`
- Utilisation d’un **certificat privé associé au clientId**

---

## 🤝 Auteurs

- 👨‍💼 Serge THÉZÉNAS – Consultant M365 chez Pierre Fabre

---

## 📄 Licence

Ce script est fourni à usage interne client. Pour tout usage public, merci de contacter le développeur.

---
