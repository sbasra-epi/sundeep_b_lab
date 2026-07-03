# ================================
# Unified Installed Apps Inventory
# Outputs to: $env:USERPROFILE\Downloads\installed_apps.txt
# ================================

$downloadsFolder = Join-Path $env:USERPROFILE 'Downloads'
$outputFile = Join-Path $downloadsFolder 'installed_apps.txt'

function Get-InstalledSoftware {
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $results = foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object -Property @{Name='DisplayName';Expression={$_.DisplayName}}, @{Name='DisplayVersion';Expression={$_.DisplayVersion}}, @{Name='Publisher';Expression={$_.Publisher}}, @{Name='InstallDate';Expression={$_.InstallDate}}, @{Name='Source';Expression={'Registry'}}
    }

    return $results | Sort-Object DisplayName -Unique
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('Installed Apps Inventory')
$lines.Add("Generated: $(Get-Date -Format g)")
$lines.Add('')

$lines.Add('=== Registry / Win32 Apps ===')
$regApps = Get-InstalledSoftware
if ($regApps) {
    foreach ($app in $regApps) {
        $lines.Add("$($app.DisplayName) | Version: $($app.DisplayVersion) | Publisher: $($app.Publisher) | InstallDate: $($app.InstallDate)")
    }
} else {
    $lines.Add('No registry-based apps found.')
}

$lines.Add('')
$lines.Add('=== Microsoft Store / AppX / MSIX Apps ===')
$appxApps = Get-AppxPackage | Select-Object -Property @{Name='DisplayName';Expression={$_.Name}}, @{Name='DisplayVersion';Expression={$_.Version}}, @{Name='Publisher';Expression={$_.Publisher}}, @{Name='InstallDate';Expression={''}}, @{Name='Source';Expression={'AppX'}}
if ($appxApps) {
    foreach ($app in $appxApps | Sort-Object DisplayName) {
        $lines.Add("$($app.DisplayName) | Version: $($app.DisplayVersion) | Publisher: $($app.Publisher)")
    }
} else {
    $lines.Add('No AppX/MSIX apps found.')
}

$lines.Add('')
$lines.Add('=== Winget Packages ===')
try {
    $wingetOutput = winget list 2>$null
    if ($wingetOutput) {
        $lines.AddRange([string[]]$wingetOutput)
    } else {
        $lines.Add('winget returned no output.')
    }
} catch {
    $lines.Add('winget not found or failed to run.')
}

$lines.Add('')
$lines.Add('=== Chocolatey Packages ===')
try {
    $chocoOutput = choco list -lo 2>$null
    if ($chocoOutput) {
        $lines.AddRange([string[]]$chocoOutput)
    } else {
        $lines.Add('Chocolatey returned no output.')
    }
} catch {
    $lines.Add('Chocolatey not found or failed to run.')
}

$lines | Set-Content -Path $outputFile -Encoding UTF8
Write-Output "Inventory complete. Text file saved to $outputFile"
