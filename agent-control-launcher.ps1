Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$workDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path $workDir "runlogs"
if (!(Test-Path $logDir)) {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

try {
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
