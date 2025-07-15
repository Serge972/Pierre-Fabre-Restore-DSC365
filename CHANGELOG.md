# 📜 CHANGELOG – Script M365DSC Conditional Access Restore

## [v1.0] – 2025-07-13

### 🎉 Ajouté
- Extraction du bloc AADConditionalAccessPolicy depuis un export Microsoft365DSC
- Génération automatique du script RestoreConditionalAccess.ps1
- Nettoyage des anciennes versions de modules PowerShell
- Vérification des versions minimales requises
- Mise à jour automatique des dépendances via `Update-M365DSCDependencies`
- Application de la configuration DSC (MOF)
- Génération de logs `.log` et `.html`
- Envoi de notifications dans Microsoft Teams (suivi + erreurs critiques)
- Vérification de la restauration post-application via Microsoft Graph

---

## Prochaine version [v1.1] - À venir

### 🔧 Prévu
- Support multi-stratégies (restaurer plusieurs accès conditionnels en une passe)
- Paramétrage du nom de stratégie via arguments CLI (`-CAName`)
- Ajout d’un rapport JSON pour intégration DevOps
