# system (powershell_Admin)

Scripts et guide d'administration Windows en PowerShell pour le système.

## Contenu du dossier

| Fichier | Description |
| --- | --- |
| `system_status.ps1` | Rapport d'état du système : OS, RAM, CPU, disques, réseau, processus, licence/activation, alertes, export |
| `guide_terminal.txt` | Guide/cheatsheet du terminal PowerShell : navigation, fichiers/dossiers, exécution de scripts, `./`, encodage UTF-8 |
| `system.ps1~` | Ancienne version (bash) conservée pour historique |
| `.system.ps1.un~` | Fichier de sauvegarde éditeur |

## system_status.ps1

Affiche un rapport complet de la machine :

- **Système** : OS, version/build, fabricant, modèle, uptime
- **Licence / Activation** : produit, canal, statut, clé d'activation (complète ou masquée)
- **Mémoire** : totale / utilisée / libre + pourcentage
- **CPU** : modèle, cœurs, charge réelle (%)
- **Disques** : tous les volumes, espace utilisé/libre + pourcentage
- **Réseau** : adaptateurs actifs, IP, MAC, vitesse
- **Processus** : top 5 consommateurs de RAM
- **Alertes** : seuils de charge (RAM/CPU/disque), niveau ATTENTION / CRITIQUE

### Exemples

```powershell
.\system_status.ps1                          # Rapport local
.\system_status.ps1 -Threshold 80            # Seuil d'alerte à 80 %
.\system_status.ps1 -NoKey                   # Masque la clé d'activation
.\system_status.ps1 -ExportPath .\rapport.txt  # Export .txt + .csv
.\system_status.ps1 -Computers PC1, PC2      # Rapports à distance (WinRM)
```

### Paramètres

| Paramètre | Description |
| --- | --- |
| `-Computers` | Liste de machines distantes (Invoke-Command / WinRM) |
| `-ExportPath` | Chemin du fichier d'export (écrit `.txt` et `.csv`) |
| `-Threshold` | Seuil d'alerte en % (défaut : 90) |
| `-NoKey` | Masque la clé d'activation complète à l'écran |

### Notes

- Nécessite de sauvegarder le fichier en **UTF-8 avec BOM** pour l'affichage correct des accents sous PowerShell 5.1.
- La clé d'activation complète n'est **jamais** écrite dans l'export CSV.
- La lecture de la charge CPU prend ~1 s (2 mesures espacées de 800 ms).

## Guide terminal

`guide_terminal.txt` contient les bases indispensables :

- Exécuter un script avec `.\` et la politique d'exécution (`ExecutionPolicy`)
- Navigation de dossiers (`pwd`, `cd`, `ls`)
- Création / copie / déplacement / renommage / suppression de fichiers et dossiers
- Gestion de l'encodage et des accents
- Pipeline `|`, variables d'environnement, boucles, recherche
- Raccourcis clavier et aide (`Get-Help`, `Get-Command`)