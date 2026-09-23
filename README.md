# powershell_Admin

Scripts d'administration Windows en PowerShell.

<p>
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License MIT">
  <img src="https://img.shields.io/badge/PowerShell-5391FE?style=flat-square&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/badge/Platform-Windows-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Windows">
  <a href="https://pyrecore.github.io/portfolio/"><img src="https://img.shields.io/badge/Portfolio-pyrecore.github.io-58a6ff?style=flat-square&logo=github&logoColor=white" alt="Portfolio"></a>
</p>

Scripts d'administration Windows en PowerShell.

## Structure

```
powershel_Admin/
└── system/          Script system_status.ps1 + guide terminal + documentation
```

## Contenu

| Dossier | Description |
| --- | --- |
| `system/` | Rapport d'état du système (`system_status.ps1`), guide terminal et README détaillé |

## Démarrage rapide

Depuis le dossier `system/` :

```powershell
.\system_status.ps1                          # Rapport local
.\system_status.ps1 -NoKey                   # Masque la clé d'activation
.\system_status.ps1 -ExportPath .\rapport.txt  # Export .txt + .csv
.\system_status.ps1 -Computers PC1, PC2      # Rapports à distance (WinRM)
```

## Documentation

- Lisez [system/README.md](system/README.md) pour tous les détails du script, ses paramètres et le guide terminal.

## License

[MIT](LICENSE)