$Phase = 'AfterInstall'
$OutputRoot = 'C:\MS_DATA\AVD-Language-State'

$ErrorActionPreference = 'Stop'
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fffffff')
$captureDir = Join-Path $OutputRoot "$stamp-$Phase"
New-Item -ItemType Directory -Path $captureDir -ErrorAction Stop | Out-Null
$failures = New-Object 'System.Collections.Generic.List[string]'

function Save-Capture {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    $path = Join-Path $captureDir $Name
    try {
        & $Action *> $path
    }
    catch {
        $_ | Format-List * -Force | Out-File -LiteralPath $path -Append -Encoding utf8
        $failures.Add("${Name}: $($_.Exception.Message)")
        Write-Warning "Capture failed: $Name. See $path"
    }
}

@(
    "Phase=$Phase"
    "Computer=$env:COMPUTERNAME"
    "Identity=$([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    "StartedUTC=$([DateTime]::UtcNow.ToString('o'))"
    "StartedLocal=$([DateTimeOffset]::Now.ToString('o'))"
    "PowerShellVersion=$($PSVersionTable.PSVersion)"
) | Out-File -LiteralPath (Join-Path $captureDir 'CaptureInfo.txt') -Encoding utf8

Save-Capture 'InstalledLanguage.txt' {
    Get-InstalledLanguage -ErrorAction Stop | Format-List *
}
Save-Capture 'SystemPreferredUILanguage.txt' {
    Get-SystemPreferredUILanguage -ErrorAction Stop | Format-List *
}
Save-Capture 'SystemLocale.txt' {
    Get-WinSystemLocale -ErrorAction Stop | Format-List *
}
Save-Capture 'TimeZone.txt' {
    Get-TimeZone -ErrorAction Stop | Format-List *
}
Save-Capture 'MUI-UILanguages.txt' {
    $key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\MUI\UILanguages'
    if (Test-Path -LiteralPath "Registry::$key") {
        & reg.exe query $key /s
        if ($LASTEXITCODE -ne 0) {
            throw "reg.exe query failed for $key with exit code $LASTEXITCODE"
        }
    }
    else {
        "REGISTRY_KEY_ABSENT: $key"
    }
}
Save-Capture 'LanguageOverlay.txt' {
    $key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\LanguageOverlay'
    if (Test-Path -LiteralPath "Registry::$key") {
        & reg.exe query $key /s
        if ($LASTEXITCODE -ne 0) {
            throw "reg.exe query failed for $key with exit code $LASTEXITCODE"
        }
    }
    else {
        "REGISTRY_KEY_ABSENT: $key"
    }
}

if ($failures.Count -gt 0) {
    $failures | Out-File -LiteralPath (Join-Path $captureDir 'CaptureErrors.txt') -Encoding utf8
    'Status=Incomplete' | Out-File -LiteralPath (Join-Path $captureDir 'CaptureInfo.txt') -Append -Encoding utf8
    throw "Language state capture was incomplete. See $captureDir"
}

@(
    'Status=Complete'
    "FinishedUTC=$([DateTime]::UtcNow.ToString('o'))"
) | Out-File -LiteralPath (Join-Path $captureDir 'CaptureInfo.txt') -Append -Encoding utf8
Write-Output "Language state saved to $captureDir"
