param(
  [ValidateSet("", "menu", "start", "stop", "status", "validate")]
  [string]$Action = "",
  [int]$Port = 0
)

# PsiphonOverMITM by @b3hnamrjd
# Telegram Channel : https://t.me/B3hnamR
# https://github.com/B3hnamR/PsiphonOverMITM

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir = Split-Path -Parent $ScriptPath
$WorkDir = Join-Path $ScriptDir "runtime"
$XrayDir = Join-Path $ScriptDir "xray"
$CertGeneratorPath = Join-Path $ScriptDir "MITM-DomainFronting-14\Xray-config\certificate_generator.bat"
$ConfigPath = Join-Path $ScriptDir "psiphon-helper@patterniha.json"
$RuntimeConfigPath = Join-Path $WorkDir "PsiphonOverMITM.runtime.json"
$PidPath = Join-Path $WorkDir "PsiphonOverMITM.pid"
$PortPath = Join-Path $WorkDir "PsiphonOverMITM.port"
$LogPath = Join-Path $WorkDir "PsiphonOverMITM.out.log"
$ErrPath = Join-Path $WorkDir "PsiphonOverMITM.err.log"
$MainLogPath = Join-Path $ScriptDir "PsiphonOverMITM.log"
$PreferredXrayVersion = "26.4.25"
$script:QuietConsole = $false
$script:PortWasExplicit = $false

function Write-Log([string]$Level, [string]$Message) {
  $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $Level, $Message
  try { Add-Content -LiteralPath $MainLogPath -Value $line -Encoding UTF8 } catch {}
}

function Write-Info([string]$Message) {
  Write-Log "INFO" $Message
  if (-not $script:QuietConsole) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
}

function Write-Ok([string]$Message) {
  Write-Log "OK" $Message
  if (-not $script:QuietConsole) { Write-Host "[OK] $Message" -ForegroundColor Green }
}

function Write-Warn([string]$Message) {
  Write-Log "WARN" $Message
  if (-not $script:QuietConsole) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
}

function Write-Step([string]$Message) {
  Write-Log "STEP" $Message
  if (-not $script:QuietConsole) { Write-Host "==> $Message" -ForegroundColor Cyan }
}

function Show-Banner {
  Write-Host ""
  Write-Host " PsiphonOverMITM" -ForegroundColor Cyan
  Write-Host " by @b3hnamrjd | https://github.com/B3hnamR/PsiphonOverMITM" -ForegroundColor DarkGray
  Write-Host " Psiphon upstream proxy: 127.0.0.1:$Port" -ForegroundColor DarkGray
  Write-Host ""
}

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Administrator {
  if (Test-IsAdministrator) { return $true }
  Write-Host ""
  Write-Host "Administrator access is required." -ForegroundColor Red
  Write-Host "Right-click Run-PsiphonOverMITM.bat and choose 'Run as administrator'." -ForegroundColor Yellow
  Write-Log "ERROR" "Administrator access is required."
  return $false
}

function Ensure-Directory([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Initialize-Defaults {
  if ($Port -le 0) {
    $envPort = [Environment]::GetEnvironmentVariable("PSIPHON_HELPER_PORT")
    $parsed = 0
    if ([int]::TryParse($envPort, [ref]$parsed) -and $parsed -gt 0) {
      $script:Port = $parsed
      $script:PortWasExplicit = $true
    } else {
      $script:Port = 20808
      $script:PortWasExplicit = $false
    }
  } else {
    $script:PortWasExplicit = $true
  }
}

function Test-PortBindable([int]$TcpPort) {
  $listener = $null
  try {
    $address = [Net.IPAddress]::Parse("127.0.0.1")
    $listener = [Net.Sockets.TcpListener]::new($address, $TcpPort)
    $listener.Start()
    return $true
  } catch {
    Write-Log "WARN" "Port $TcpPort is not bindable: $($_.Exception.Message)"
    return $false
  } finally {
    if ($listener) { $listener.Stop() }
  }
}

function Select-UsablePort {
  if (Test-PortBindable $Port) { return }

  foreach ($candidate in @(21080, 28080, 18080, 31080, 38080, 10880)) {
    if (Test-PortBindable $candidate) {
      Write-Warn "Port 20808 is not available on this Windows system; using 127.0.0.1:$candidate instead."
      $script:Port = $candidate
      return
    }
  }
  throw "No usable local port was found for PsiphonOverMITM."
}

function Select-UsablePortForStatus {
  $oldQuiet = $script:QuietConsole
  $script:QuietConsole = $true
  try {
    Select-UsablePort
  } finally {
    $script:QuietConsole = $oldQuiet
  }
}

function Set-PropertyValue($Object, [string]$Name, $Value) {
  $prop = $Object.PSObject.Properties[$Name]
  if ($prop) {
    $Object.$Name = $Value
  } else {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  }
}

function Get-XrayVersion([string]$XrayExe) {
  if (-not (Test-Path -LiteralPath $XrayExe)) { return "" }
  try {
    $output = & $XrayExe version 2>$null | Select-Object -First 1
    if ([string]$output -match '^Xray\s+([0-9]+\.[0-9]+\.[0-9]+)') { return $Matches[1] }
  } catch {}
  return ""
}

function Compare-VersionString([string]$Left, [string]$Right) {
  try {
    $leftVersion = [Version]$Left
    $rightVersion = [Version]$Right
    return $leftVersion.CompareTo($rightVersion)
  } catch {
    return [string]::Compare($Left, $Right, $true)
  }
}

function Get-RequiredXrayVersion {
  if (-not (Test-Path -LiteralPath $ConfigPath)) { return $PreferredXrayVersion }
  try {
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($config.version.min) { return [string]$config.version.min }
  } catch {}
  return $PreferredXrayVersion
}

function Ensure-Xray {
  $xrayExe = Join-Path $XrayDir "xray.exe"
  $version = Get-XrayVersion $xrayExe
  if (-not $version) { throw "xray.exe not found: $xrayExe" }
  $required = Get-RequiredXrayVersion
  if ((Compare-VersionString $version $required) -lt 0) {
    throw "Xray version is $version, but this config requires at least $required."
  }
  if ($version -ne $PreferredXrayVersion) {
    Write-Warn "Xray version is $version. Preferred tested version is $PreferredXrayVersion."
  }
  return $xrayExe
}

function Build-RuntimeConfig {
  if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Config not found: $ConfigPath" }
  Ensure-Directory $WorkDir
  $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $remarks = [string]$config.remarks
  $outboundTags = @($config.outbounds | ForEach-Object { $_.tag })
  if ($remarks -notmatch "psiphon" -or $outboundTags -notcontains "tls-repack-akamai" -or $outboundTags -notcontains "tls-repack-fastly") {
    throw "This runner needs psiphon-helper@patterniha.json. Do not replace it with the general MITM-DomainFronting v14 config."
  }
  Set-PropertyValue $config "remarks" "PsiphonOverMITM"
  foreach ($inbound in $config.inbounds) {
    if ($inbound.tag -eq "mixed-in") {
      $inbound.port = $Port
      Set-PropertyValue $inbound "listen" "127.0.0.1"
      if ($inbound.settings) { Set-PropertyValue $inbound.settings "ip" "127.0.0.1" }
    }
  }
  $json = $config | ConvertTo-Json -Depth 100
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($RuntimeConfigPath, $json, $utf8NoBom)
  Write-Ok "Runtime config ready from $remarks."
}

function New-CertificateFiles([string]$XrayExe) {
  $crt = Join-Path $XrayDir "mycert.crt"
  $key = Join-Path $XrayDir "mycert.key"
  if ((Test-Path -LiteralPath $crt) -and (Test-Path -LiteralPath $key)) {
    Write-Ok "Certificate files already exist."
    return
  }

  if (-not (Test-Path -LiteralPath $CertGeneratorPath)) {
    throw "certificate_generator.bat not found: $CertGeneratorPath"
  }

  $certWorkDir = Join-Path $WorkDir "cert-generator"
  $certWorkXrayDir = Join-Path $certWorkDir "xray"
  Ensure-Directory $certWorkDir
  Ensure-Directory $certWorkXrayDir
  Copy-Item -LiteralPath $CertGeneratorPath -Destination (Join-Path $certWorkDir "certificate_generator.bat") -Force
  Copy-Item -LiteralPath $XrayExe -Destination (Join-Path $certWorkXrayDir "xray.exe") -Force
  Remove-Item -LiteralPath (Join-Path $certWorkDir "mycert.crt") -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath (Join-Path $certWorkDir "mycert.key") -Force -ErrorAction SilentlyContinue

  Push-Location $certWorkDir
  try {
    Write-Info "Generating private MITM certificate with MITM-DomainFronting-14 certificate_generator.bat"
    $output = cmd.exe /d /c "call certificate_generator.bat < nul" 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-Log "ERROR" (($output | Out-String).Trim())
      throw "Certificate generation failed."
    }
    $generatedCrt = Join-Path $certWorkDir "mycert.crt"
    $generatedKey = Join-Path $certWorkDir "mycert.key"
    if (-not ((Test-Path -LiteralPath $generatedCrt) -and (Test-Path -LiteralPath $generatedKey))) {
      Write-Log "ERROR" (($output | Out-String).Trim())
      throw "certificate_generator.bat finished but mycert.crt/mycert.key were not created."
    }
    Copy-Item -LiteralPath $generatedCrt -Destination $crt -Force
    Copy-Item -LiteralPath $generatedKey -Destination $key -Force
    Write-Ok "Certificate files generated by v14 generator."
  } finally {
    Pop-Location
  }
}

function Ensure-Certificate([string]$XrayExe) {
  Write-Step "Checking private MITM certificate"
  New-CertificateFiles $XrayExe
  $crt = Join-Path $XrayDir "mycert.crt"
  $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($crt)
  Write-Info "Only mycert.crt is installed into Local Machine Trusted Root; mycert.key stays private in the local xray folder."
  $existing = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Thumbprint -eq $cert.Thumbprint } | Select-Object -First 1
  if ($existing) {
    Write-Ok "Certificate is already trusted in Local Machine."
    return
  }
  & certutil.exe -addstore Root $crt | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Failed to install certificate into Local Machine Trusted Root." }
  Write-Ok "Certificate trusted for Local Machine."
}

function Get-RunningProcess {
  if (-not (Test-Path -LiteralPath $PidPath)) { return $null }
  $rawPid = (Get-Content -LiteralPath $PidPath -Raw).Trim()
  $pidNumber = 0
  if (-not [int]::TryParse($rawPid, [ref]$pidNumber)) { return $null }
  try {
    $proc = Get-Process -Id $pidNumber -ErrorAction Stop
    $expected = (Join-Path $XrayDir "xray.exe").ToLowerInvariant()
    try {
      $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$pidNumber" -ErrorAction Stop
      if ($cim.ExecutablePath -and $cim.ExecutablePath.ToLowerInvariant() -ne $expected) { return $null }
    } catch {}
    return $proc
  } catch {
    return $null
  }
}

function Test-TcpPort([int]$TcpPort) {
  try {
    $client = [Net.Sockets.TcpClient]::new()
    $async = $client.BeginConnect("127.0.0.1", $TcpPort, $null, $null)
    $ok = $async.AsyncWaitHandle.WaitOne(800)
    if ($ok) { $client.EndConnect($async) }
    $client.Close()
    return [bool]$ok
  } catch {
    return $false
  }
}

function Wait-Port([int]$TcpPort, [int]$Seconds) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    if (Test-TcpPort $TcpPort) { return $true }
    Start-Sleep -Milliseconds 400
  }
  return $false
}

function Start-Helper {
  Initialize-Defaults
  if (-not (Assert-Administrator)) { exit 5 }
  Write-Step "Preparing PsiphonOverMITM startup"
  try {
    Ensure-Directory $WorkDir
    Write-Step "Checking Xray core"
    $xrayExe = Ensure-Xray
    Write-Step "Checking local upstream proxy port"
    Select-UsablePort
    Write-Step "Building runtime config from psiphon-helper@patterniha.json"
    Build-RuntimeConfig
    Ensure-Certificate $xrayExe
    Write-Step "Starting Xray with Psiphon helper config"
    $running = Get-RunningProcess
    if (-not $running) {
      Remove-Item -LiteralPath $LogPath -Force -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath $ErrPath -Force -ErrorAction SilentlyContinue
      $proc = Start-Process -FilePath $xrayExe `
        -ArgumentList @("run", "-config", $RuntimeConfigPath) `
        -WorkingDirectory $XrayDir `
        -WindowStyle Hidden `
        -RedirectStandardOutput $LogPath `
        -RedirectStandardError $ErrPath `
        -PassThru
      Set-Content -LiteralPath $PidPath -Value $proc.Id -Encoding ASCII
      Set-Content -LiteralPath $PortPath -Value $Port -Encoding ASCII
      if (-not (Wait-Port $Port 10)) {
        Start-Sleep -Milliseconds 500
        $alive = $false
        try {
          $alive = -not (Get-Process -Id $proc.Id -ErrorAction Stop).HasExited
        } catch {}
        $details = ""
        if (Test-Path -LiteralPath $ErrPath) { $details = (Get-Content -LiteralPath $ErrPath -Raw -ErrorAction SilentlyContinue).Trim() }
        if (-not $details -and (Test-Path -LiteralPath $LogPath)) { $details = (Get-Content -LiteralPath $LogPath -Raw -ErrorAction SilentlyContinue).Trim() }
        Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue
        if (-not $details) { $details = "Port 127.0.0.1:$Port did not open." }
        throw $details
      }
    } else {
      if (-not (Test-TcpPort $Port)) {
        throw "PID file exists, but 127.0.0.1:$Port is not reachable. Stop and start again."
      }
      Write-Ok "PsiphonOverMITM is already running."
    }
  } finally {
    $script:QuietConsole = $false
  }
  Write-Host ""
  Write-Host "PsiphonOverMITM is active." -ForegroundColor Green
  Write-Host ("Set Psiphon upstream proxy to: 127.0.0.1:{0}" -f $Port) -ForegroundColor Cyan
  Write-Host "Use this as Psiphon's upstream proxy only; do not set Windows system proxy for this mode." -ForegroundColor DarkGray
  Write-Host ""
}

function Stop-Helper {
  $proc = Get-RunningProcess
  if ($proc) {
    Write-Info "Stopping PsiphonOverMITM PID $($proc.Id)"
    Stop-Process -Id $proc.Id -Force
    Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $PortPath -Force -ErrorAction SilentlyContinue
    Write-Ok "PsiphonOverMITM stopped."
  } else {
    Write-Warn "PsiphonOverMITM is not running."
  }
}

function Show-Status {
  Initialize-Defaults
  if (Test-Path -LiteralPath $PortPath) {
    $savedPort = (Get-Content -LiteralPath $PortPath -Raw -ErrorAction SilentlyContinue).Trim()
    $parsedPort = 0
    if ([int]::TryParse($savedPort, [ref]$parsedPort) -and $parsedPort -gt 0) {
      $script:Port = $parsedPort
    }
  } else {
    try { Select-UsablePortForStatus } catch {}
  }
  $proc = Get-RunningProcess
  if ($proc) {
    Write-Host "PsiphonOverMITM: running, PID $($proc.Id)"
  } else {
    Write-Host "PsiphonOverMITM: stopped"
  }
  Write-Host "Proxy: 127.0.0.1:$Port reachable=$(Test-TcpPort $Port)"
  if (-not $proc) {
    Write-Host "Use the port shown here after Start; if 20808 is reserved, Start will use this fallback port."
  }
  Write-Host "Log: $MainLogPath"
}

function Test-Config {
  Initialize-Defaults
  $xrayExe = Ensure-Xray
  Select-UsablePort
  Build-RuntimeConfig
  New-CertificateFiles $xrayExe
  Push-Location $XrayDir
  try {
    & $xrayExe run -test -config $RuntimeConfigPath
    if ($LASTEXITCODE -ne 0) { throw "Xray config validation failed." }
  } finally {
    Pop-Location
  }
  Write-Ok "Configuration OK."
}

function Show-Menu {
  while ($true) {
    Show-Banner
    Write-Host ("Admin: {0}" -f ($(if (Test-IsAdministrator) { "YES" } else { "NO - use Run as administrator" })))
    Write-Host "Log: $MainLogPath"
    Write-Host ""
    Write-Host " [1] Start"
    Write-Host " [2] Stop"
    Write-Host " [3] Status"
    Write-Host " [0] Exit"
    $choice = Read-Host "Select"
    switch ($choice) {
      "1" { Start-Helper }
      "2" { Stop-Helper }
      "3" { Show-Status }
      "0" { return }
      default { Write-Warn "Unknown option." }
    }
  }
}

try {
  Initialize-Defaults
  Write-Log "INFO" ("Session started. Action={0}; Admin={1}" -f $Action, (Test-IsAdministrator))
  switch ($Action) {
    "" { Show-Menu }
    "menu" { Show-Menu }
    "start" { Start-Helper }
    "stop" { Stop-Helper }
    "status" { Show-Status }
    "validate" { Test-Config }
  }
  Write-Log "INFO" "Session finished successfully."
} catch {
  Write-Log "ERROR" $_.Exception.Message
  Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
