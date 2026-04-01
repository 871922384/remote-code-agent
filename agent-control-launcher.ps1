Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms

$workDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path $workDir "runlogs"
if (!(Test-Path $logDir)) {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Get-ControllerMutexName {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  $normalizedPath = $Path.ToLowerInvariant()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalizedPath)
  $md5 = [System.Security.Cryptography.MD5]::Create()
  try {
    $hashBytes = $md5.ComputeHash($bytes)
  } finally {
    $md5.Dispose()
  }

  $hash = [System.BitConverter]::ToString($hashBytes).Replace("-", "")
  return "RemoteAgentController-$hash"
}

$script:controllerMutex = $null
try {
  $mutexName = Get-ControllerMutexName -Path $workDir
  $createdNew = $false
  $script:controllerMutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
  if (-not $createdNew) {
    [System.Windows.Forms.MessageBox]::Show(
      "Remote Agent Controller is already running.",
      "Remote Agent Controller",
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    return
  }

  & (Join-Path $workDir "agent-control.ps1")
}
catch {
  $msg = $_.Exception.ToString()
  $line = "{0} {1}" -f (Get-Date -Format s), $msg
  Add-Content -Path (Join-Path $logDir "controller-startup-error.log") -Value $line

  Write-Host "[Agent Controller] Start failed." -ForegroundColor Red
  Write-Host $msg -ForegroundColor Red
  Write-Host ""
  Write-Host "Error has been saved to runlogs\controller-startup-error.log"
  Read-Host "Press Enter to exit"
}
finally {
  if ($script:controllerMutex) {
    try {
      $script:controllerMutex.ReleaseMutex()
    } catch {}
    $script:controllerMutex.Dispose()
  }
}
