<#
    system_status.ps1  -  Rapport d'état du système (Windows)

    Affiche un état complet du système : OS, mémoire, CPU, disques,
    réseau, processus, avec alertes sur seuils et export optionnel.

    EXEMPLES
        .\system.ps1                             Rapport local
        .\system.ps1 -Computers SVR01, SVR02     Rapport à distance (WinRM)
        .\system.ps1 -ExportPath .\rapport.txt   Rapport + export .txt et .csv
        .\system.ps1 -Threshold 85               Seuil d'alerte personnalisé
        .\system.ps1 -NoKey                      Masque la clé d'activation complète
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline)]
    [Alias('CN', 'ComputerName')]
    [string[]]$Computers,

    [string]$ExportPath,

    [ValidateRange(1, 100)]
    [int]$Threshold = 90,

    [switch]$NoKey
)

$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

$script:core = {
    param($Threshold, $IsLocal, $ExportPath, $NoKey)

    $reportLines   = [System.Collections.Generic.List[string]]::new()
    $reportObjects = [System.Collections.Generic.List[object]]::new()
    $alerts        = [System.Collections.Generic.List[object]]::new()

    function Write-Log {
        param([string]$Text = "", [string]$Color = "")
        $reportLines.Add($Text)
        if ($IsLocal) {
            if ($Color) { Write-Host $Text -ForegroundColor $Color }
            else { Write-Host $Text }
        }
    }

    function Show-Section {
        param([string]$Title)
        $pad = [Math]::Max(2, 52 - $Title.Length)
        Write-Log "" -Color ''
        Write-Log ("===== {0}{1}" -f $Title, ("=" * ($pad - 1))) -Color Cyan
    }

    function Add-Record {
        param([string]$Section, [string]$Clef, $Valeur)
        $reportObjects.Add([pscustomobject]@{
            Section = $Section
            Clef    = $Clef
            Valeur  = [string]$Valeur
        })
    }

    function Add-Alert {
        param([string]$Section, [string]$Label, [double]$Value)
        if ($Value -lt $Threshold) { return }
        $niveau  = if ($Value -ge ($Threshold + 10)) { 'CRITIQUE' } else { 'ATTENTION' }
        $couleur = if ($niveau -eq 'CRITIQUE') { 'Red' } else { 'Yellow' }
        $alerts.Add([pscustomobject]@{
            Section = $Section
            Label = $Label
            Valeur = ("{0} %" -f [math]::Round($Value, 1))
            Niveau = $niveau
        })
        Add-Record 'Alerte' ("{0} ({1})" -f $Label, $niveau) ("{0} %" -f [math]::Round($Value, 1))
        Write-Log ("  [!!] {0} : {1} % se réserve à {2}" -f $Label, [math]::Round($Value, 1), $niveau) -Color $couleur
    }

    # ------------------------------------------------------------------
    # Données de base
    # ------------------------------------------------------------------
    $os   = Get-CimInstance Win32_OperatingSystem
    $comp = Get-CimInstance Win32_ComputerSystem

    Write-Log ("=" * 60)
    Write-Log "                ÉTAT DU SYSTÈME"
    Write-Log ("=" * 60)

    # ------------------------------------------------------------------
    # SYSTÈME
    # ------------------------------------------------------------------
    Show-Section "SYSTÈME"

    Write-Log ("Hôte               : {0}" -f $comp.Name)
    Write-Log ("OS                 : {0} ({1})" -f $os.Caption, $os.OSArchitecture)
    Write-Log ("Version / Build    : {0} / {1}" -f $os.Version, $os.BuildNumber)
    Write-Log ("Fabricant          : {0}" -f $comp.Manufacturer)
    Write-Log ("Modèle             : {0}" -f $comp.Model)
    Write-Log ("Rapport généré le  : {0}" -f (Get-Date))

    Add-Record 'Système' 'Hôte'       $comp.Name
    Add-Record 'Système' 'OS'         $os.Caption
    Add-Record 'Système' 'Build'      $os.BuildNumber
    Add-Record 'Système' 'Modèle'     ("{0} {1}" -f $comp.Manufacturer, $comp.Model)

    if ($os.LastBootUpTime) {
        $uptime = (Get-Date) - $os.LastBootUpTime
        Write-Log ("Dernier démarrage  : {0}" -f $os.LastBootUpTime)
        Write-Log ("Uptime             : {0} j {1} h {2} min" -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
        Add-Record 'Système' 'Dernier démarrage' $os.LastBootUpTime
    }

    # ------------------------------------------------------------------
    # LICENCE / ACTIVATION
    # ------------------------------------------------------------------
    Show-Section "LICENCE / ACTIVATION"

    $lic = $null
    try {
        $lic = Get-CimInstance SoftwareLicensingProduct |
            Where-Object { $_.ApplicationID -eq '55c92734-d682-4d71-983e-d6ec3f16059f' -and $_.PartialProductKey } |
            Select-Object -First 1
    } catch { }

    if (-not $lic) {
        Write-Log "Produit Windows : introuvable (service SPP indisponible ?)"
        Add-Record 'Licence' 'Produit' 'Introuvable'
    } else {
        $channel = (($lic.Description -split ',')[-1]).Trim() -replace '\s+channel$', ''
        $statusLabels = @{
            0 = 'Non activée'
            1 = 'Activée'
            2 = 'Période de grâce (OOB)'
            3 = 'Période de grâce (OOT)'
            4 = 'Non authentique'
            5 = 'Notification'
            6 = 'Grâce prolongée'
        }
        $statusCode  = [int]$lic.LicenseStatus
        $statusLabel = if ($statusLabels.ContainsKey($statusCode)) { $statusLabels[$statusCode] } else { "Inconnu ($statusCode)" }
        $statusColor = if ($statusCode -eq 1)      { 'Green' }
                       elseif ($statusCode -in 2,3) { 'Yellow' }
                       else                         { 'Red' }

        Write-Log ("Produit            : {0}" -f $lic.Name)
        Write-Log ("Canal              : {0}" -f $channel)
        Write-Log ("Statut             : {0}" -f $statusLabel) -Color $statusColor
        Write-Log ("Suffixe de clé     : *****-{0}" -f $lic.PartialProductKey)

        Add-Record 'Licence' 'Produit'        $lic.Name
        Add-Record 'Licence' 'Canal'          $channel
        Add-Record 'Licence' 'Statut'         $statusLabel
        Add-Record 'Licence' 'Suffixe de clé' $lic.PartialProductKey

        if ($statusCode -ne 1) {
            $licNiveau = if ($statusCode -in 2, 3) { 'ATTENTION' } else { 'CRITIQUE' }
            $alerts.Add([pscustomobject]@{
                Section = 'Licence'
                Label   = 'Activation Windows'
                Valeur  = $statusLabel
                Niveau  = $licNiveau
            })
            Add-Record 'Alerte' ("Activation Windows ({0})" -f $licNiveau) $statusLabel
            Write-Log ("  [!!] Windows n'est pas correctement activé : {0}" -f $statusLabel) -Color $statusColor
        }

        # Clé complète : jamais écrite dans le CSV (Add-Record ci-dessus) ni si -NoKey
        $fullKey = $null
        $keySource = 'registre (système)'
        try {
            $fullKey = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform' -ErrorAction Stop).BackupProductKeyDefault
        } catch { }
        if (-not $fullKey) {
            $keySource = 'OEM (BIOS)'
            try {
                $fullKey = (Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey
            } catch {
                $keySource = 'inaccessible (droits administrateur requis)'
            }
        }

        if ($NoKey) {
            Write-Log "Clé complète       : masquée (-NoKey)"
        } elseif ($fullKey) {
            $formattedKey = ($fullKey -replace '[^\w-]', '').ToUpperInvariant()
            Write-Log ("Clé complète       : {0}" -f $formattedKey) -Color DarkGray
            Write-Log ("  (source : {0} - donnée sensible)" -f $keySource) -Color DarkGray
        } else {
            Write-Log ("Clé complète       : {0}" -f $keySource)
        }
    }

    # ------------------------------------------------------------------
    # MÉMOIRE
    # ------------------------------------------------------------------
    Show-Section "MÉMOIRE"

    $totalGB = $os.TotalVisibleMemorySize / 1MB
    $freeGB  = $os.FreePhysicalMemory / 1MB
    $usedGB  = $totalGB - $freeGB
    $usedPct = if ($totalGB -gt 0) { [math]::Round($usedGB / $totalGB * 100, 1) } else { 0 }

    Write-Log ("Total            : {0,8:N2} Go" -f $totalGB)
    Write-Log ("Utilisée         : {0,8:N2} Go ({1,5:N1} %)" -f $usedGB, $usedPct)
    Write-Log ("Libre            : {0,8:N2} Go" -f $freeGB)

    Add-Record 'Mémoire' 'Total'  ("{0:N2} Go" -f $totalGB)
    Add-Record 'Mémoire' 'Utilisée' ("{0:N2} Go ({1:N1} %)" -f $usedGB, $usedPct)

    Add-Alert 'Mémoire' 'Mémoire utilisée' $usedPct

    # ------------------------------------------------------------------
    # CPU
    # ------------------------------------------------------------------
    Show-Section "CPU"

    $cpuNames = (Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name -Unique) -join ' / '
    $cpuFirst = Get-CimInstance Win32_Processor | Select-Object -First 1

    Write-Log ("Processeur       : {0}" -f $cpuNames)
    Write-Log ("Cœurs            : {0}" -f $cpuFirst.NumberOfCores)
    Write-Log ("Cœurs logiques   : {0}" -f $cpuFirst.NumberOfLogicalProcessors)

    Add-Record 'CPU' 'Processeur'   $cpuNames
    Add-Record 'CPU' 'Cœurs'        $cpuFirst.NumberOfCores
    Add-Record 'CPU' 'Cœurs logiques' $cpuFirst.NumberOfLogicalProcessors

    $cpuLoad = $null
    try {
        $a = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
        Start-Sleep -Milliseconds 800
        $b = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
        $cpuLoad = [math]::Round(($a + $b) / 2, 1)
    } catch { }

    if ($null -ne $cpuLoad) {
        Write-Log ("Charge            : {0,5:N1} % (moyenne sur 2 mesures)" -f $cpuLoad)
        Add-Record 'CPU' 'Charge' ("{0:N1} %" -f $cpuLoad)
        Add-Alert 'CPU' 'Charge CPU' $cpuLoad
    } else {
        Write-Log "Charge            : indisponible"
    }

    # ------------------------------------------------------------------
    # DISQUES
    # ------------------------------------------------------------------
    Show-Section "DISQUES"

    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        Where-Object { $_.Size -gt 0 } |
        Sort-Object DeviceID

    if (-not $disks) {
        Write-Log "Aucun disque local détecté."
    }

    foreach ($d in $disks) {
        $tGB = $d.Size / 1GB
        $fGB = $d.FreeSpace / 1GB
        $uGB = $tGB - $fGB
        $pct = if ($tGB -gt 0) { [math]::Round($uGB / $tGB * 100, 1) } else { 0 }

        $volName = if ($d.VolumeName) { $d.VolumeName } else { '-' }
        Write-Log ("{0}  [{1}]" -f $d.DeviceID, $volName)
        Write-Log ("  Système de fichiers : {0}" -f $d.FileSystem)
        Write-Log ("  Total  : {0,8:N2} Go" -f $tGB)
        Write-Log ("  Utilisé: {0,8:N2} Go  ({1,5:N1} %)" -f $uGB, $pct)
        Write-Log ("  Libre  : {0,8:N2} Go" -f $fGB)

        Add-Record 'Disque' $d.DeviceID ("{0:N2} Go utilisés / {1:N2} Go ({2:N1} %)" -f $uGB, $tGB, $pct)
        Add-Alert 'Disque' ("Disque {0}" -f $d.DeviceID) $pct
    }

    # ------------------------------------------------------------------
    # RÉSEAU
    # ------------------------------------------------------------------
    Show-Section "RÉSEAU"

    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Sort-Object Name

    if (-not $adapters) {
        Write-Log "Aucun adaptateur réseau actif."
    }

    foreach ($nic in $adapters) {
        $ips = (Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty IPAddress) -join ', '
        if (-not $ips) { $ips = '-' }
        $speed = if ($nic.LinkSpeed) { $nic.LinkSpeed } else { '-' }

        Write-Log ("{0}  ({1})" -f $nic.Name, $nic.InterfaceDescription)
        Write-Log ("  Vitesse : {0}   MAC : {1}" -f $speed, $nic.MacAddress)
        Write-Log ("  IP v4   : {0}" -f $ips)

        Add-Record 'Réseau' $nic.Name ("{0} - {1}" -f $ips, $speed)
    }

    # ------------------------------------------------------------------
    # PROCESSUS
    # ------------------------------------------------------------------
    Show-Section "TOP 5 PROCESSUS (MÉMOIRE)"

    Get-Process |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 5 |
        ForEach-Object {
            $rGB = $_.WorkingSet64 / 1GB
            $pct = if ($totalGB -gt 0) { [math]::Round($rGB / $totalGB * 100, 1) } else { 0 }
            Write-Log ("{0,-22}  PID {1,-7}  {2,8:N2} Go  ({3,5:N1} %)" -f $_.ProcessName, $_.Id, $rGB, $pct)
            Add-Record 'Processus' $_.ProcessName ("{0:N2} Go ({1:N1} %) - PID {2}" -f $rGB, $pct, $_.Id)
        }

    # ------------------------------------------------------------------
    # RÉSUMÉ / ALERTES
    # ------------------------------------------------------------------
    Show-Section "RÉSUMÉ"

    if ($alerts.Count -eq 0) {
        Write-Log ("  Système en ordre : aucun seuil dépassé (seuil {0} %)." -f $Threshold) -Color Green
    } else {
        Write-Log ("  {0} alerte(s) détectée(s) (seuil {1} %) :" -f $alerts.Count, $Threshold) -Color Yellow
        foreach ($a in $alerts) {
            $couleur = if ($a.Niveau -eq 'CRITIQUE') { 'Red' } else { 'Yellow' }
            Write-Log ("   [{0}] {1} : {2}" -f $a.Niveau, $a.Label, $a.Valeur) -Color $couleur
        }
    }

    Write-Log ("=" * 60)
    Write-Log "               FIN DU RAPPORT"
    Write-Log ("=" * 60)

    # ------------------------------------------------------------------
    # EXPORT (local uniquement)
    # ------------------------------------------------------------------
    if ($IsLocal -and $ExportPath) {
        $dir = Split-Path -Path $ExportPath -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        ($reportLines.ToArray() -join [Environment]::NewLine) |
            Out-File -FilePath $ExportPath -Encoding utf8

        $csvPath = [System.IO.Path]::ChangeExtension($ExportPath, 'csv')
        $reportObjects | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8

        Write-Log ""
        Write-Log ("Export écrit : {0}" -f $ExportPath) -Color DarkGray
        Write-Log ("Export écrit : {0}" -f $csvPath) -Color DarkGray
    }

    if (-not $IsLocal) {
        Write-Output ($reportLines.ToArray() -join [Environment]::NewLine)
    }
}

# ======================================================================
# Exécution principale
# ======================================================================
$targets = @($Computers | Where-Object { $_ })
if (-not $targets) {
    $targets = @($env:COMPUTERNAME)
}

$localName = $env:COMPUTERNAME.ToUpperInvariant()
$allLocal  = (($targets | Where-Object { $_.ToUpperInvariant() -ne $localName }).Count -eq 0)

if ($allLocal) {
    & $script:core -Threshold $Threshold -IsLocal $true -ExportPath $ExportPath -NoKey:$NoKey
} else {
    try {
        $results = Invoke-Command -ComputerName $targets -ScriptBlock $script:core -ArgumentList $Threshold, $false, $null, $NoKey
        $texts = @($results)
        for ($i = 0; $i -lt $texts.Count; $i++) {
            if ($texts[$i] -is [System.Management.Automation.ErrorRecord]) {
                Write-Host ("[ÉCHEC] {0} : {1}" -f $targets[$i], $texts[$i].Exception.Message) -ForegroundColor Red
            } else {
                Write-Host ""
                Write-Host ("=== RAPPORT : {0} ===" -f $targets[$i]) -ForegroundColor Cyan
                Write-Host $texts[$i]
            }
        }
    } catch {
        Write-Host ("Impossible de contacter la/les machine(s) distante(s), WINRM est-il activé ?") -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}