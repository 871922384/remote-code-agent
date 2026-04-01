param(
  [string]$WorkDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
  [string]$NodeEntry = "server.js",
  [string]$FrpcExe = "frpc.exe",
  [string]$FrpcConfig = "frpc.toml",
  [string]$UiUrl = "http://agent.xujinlong.asia",
  [int]$AppPort = 3333
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:nodeProc = $null
$script:frpcProc = $null
$script:isStopping = $false
$script:timer = $null
$script:logBox = $null
$script:statusLabel = $null
$script:startButton = $null
$script:stopButton = $null
$script:lastNodeState = "stopped"
$script:lastFrpcState = "stopped"

function Get-LogDir {
  return (Join-Path $WorkDir "runlogs")
}

function Get-StateFilePath {
  return (Join-Path (Ensure-LogDir) "controller-state.json")
}

function Ensure-LogDir {
  $logDir = Get-LogDir
  if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  }
  return $logDir
}

function Write-ControllerLog {
  param(
    [Parameter(Mandatory = $true)][string]$Message
  )

  try {
    $logDir = Ensure-LogDir
    $controllerLog = Join-Path $logDir "controller.log"
    Add-Content -Path $controllerLog -Value ((Get-Date).ToString("s") + " " + $Message)
  } catch {}
}

function Write-StartupTrace {
  param(
    [Parameter(Mandatory = $true)][string]$Message
  )

  try {
    $logDir = Ensure-LogDir
    $traceLog = Join-Path $logDir "controller-trace.log"
    Add-Content -Path $traceLog -Value ((Get-Date).ToString("s") + " " + $Message)
    Write-ControllerLog "[trace] $Message"
  } catch {}
}

function Append-LogToTextBox {
  param(
    [Parameter(Mandatory = $true)][string]$Message
  )

  $timestamp = Get-Date -Format "HH:mm:ss"
  $script:logBox.AppendText("[$timestamp] $Message`r`n")
  $script:logBox.SelectionStart = $script:logBox.TextLength
  $script:logBox.ScrollToCaret()
}

function Invoke-ControlAction {
  param(
    [Parameter(Mandatory = $true)]$Control,
    [Parameter(Mandatory = $true)][scriptblock]$Action
  )

  if ($null -eq $Control) {
    return
  }

  if ($Control.InvokeRequired) {
    $null = $Control.BeginInvoke([System.Windows.Forms.MethodInvoker]$Action)
    return
  }

  & $Action
}

function Append-Log {
  param(
    [Parameter(Mandatory = $true)][string]$Message
  )

  Write-ControllerLog $Message

  if (-not $script:logBox) {
    return
  }

  Invoke-ControlAction -Control $script:logBox -Action {
    Append-LogToTextBox -Message $Message
  }
}

function Get-ConfiguredAppPort {
  $envPath = Join-Path $WorkDir ".env"
  if (Test-Path $envPath) {
    $lines = Get-Content -Path $envPath -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
      if ($line -match '^\s*PORT\s*=\s*(\d+)\s*$') {
        return [int]$Matches[1]
      }
    }
  }

  return $AppPort
}

function Get-RuntimeState {
  $statePath = Get-StateFilePath
  if (!(Test-Path $statePath)) {
    return $null
  }

  try {
    return (Get-Content -Path $statePath -Raw -ErrorAction Stop | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Save-RuntimeState {
  $state = [ordered]@{
    workspace = $WorkDir
    port = Get-ConfiguredAppPort
    nodePid = if ($script:nodeProc -and $script:nodeProc.Process -and -not $script:nodeProc.Process.HasExited) { $script:nodeProc.Process.Id } else { $null }
    frpcPid = if ($script:frpcProc -and $script:frpcProc.Process -and -not $script:frpcProc.Process.HasExited) { $script:frpcProc.Process.Id } else { $null }
    startedAt = (Get-Date).ToString("o")
  }

  $stateJson = $state | ConvertTo-Json
  Set-Content -Path (Get-StateFilePath) -Value $stateJson -Encoding UTF8
}

function Clear-RuntimeState {
  Remove-Item -Path (Join-Path (Ensure-LogDir) "controller-state.json") -Force -ErrorAction SilentlyContinue
}

function New-ProcessLogPaths {
  param(
    [Parameter(Mandatory = $true)][string]$Tag
  )

  $logDir = Ensure-LogDir
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
  return [pscustomobject]@{
    RedirectStandardOutputPath = Join-Path $logDir "$Tag-$stamp-out.log"
    RedirectStandardErrorPath = Join-Path $logDir "$Tag-$stamp-err.log"
  }
}

function Get-ProcessLogTail {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$Lines = 3
  )

  if (!(Test-Path $Path)) {
    return ""
  }

  $tail = Get-Content -Path $Path -Tail $Lines -ErrorAction SilentlyContinue
  if ($null -eq $tail) {
    return ""
  }

  return (($tail | Where-Object { $_ -and $_.Trim() }) -join " | ")
}

function Get-ProcState {
  param(
    [Parameter(Mandatory = $false)]$ProcRef
  )

  if ($null -eq $ProcRef) {
    return "stopped"
  }

  if ($null -eq $ProcRef.Process) {
    return "stopped"
  }

  if ($ProcRef.Process.HasExited) {
    return "stopped"
  }

  return "running"
}

function Stop-ProcessByPid {
  param(
    [Parameter(Mandatory = $false)][Nullable[int]]$Pid,
    [Parameter(Mandatory = $true)][string]$Reason
  )

  if ($null -eq $Pid) {
    return
  }

  $process = Get-Process -Id $Pid -ErrorAction SilentlyContinue
  if ($null -eq $process) {
    return
  }

  Append-Log "Stopping PID $Pid ($Reason)..."
  try {
    Stop-Process -Id $Pid -Force -ErrorAction Stop
  } catch {
    Append-Log "Failed to stop PID ${Pid}: $($_.Exception.Message)"
  }
}

function Clear-StaleManagedProcesses {
  $state = Get-RuntimeState
  if ($null -eq $state) {
    return
  }

  Stop-ProcessByPid -Pid $state.frpcPid -Reason "stale frpc from controller-state.json"
  Stop-ProcessByPid -Pid $state.nodePid -Reason "stale node from controller-state.json"
  Clear-RuntimeState
}

function Clear-AppPortOwner {
  param(
    [Parameter(Mandatory = $true)][int]$Port
  )

  $owners = @(Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
    Where-Object { $_.OwningProcess } |
    Select-Object -ExpandProperty OwningProcess -Unique)

  foreach ($ownerPid in $owners) {
    Stop-ProcessByPid -Pid $ownerPid -Reason "port $Port owner"
  }
}

function Update-UiStateCore {
  $nodeState = Get-ProcState -ProcRef $script:nodeProc
  $frpcState = Get-ProcState -ProcRef $script:frpcProc

  $nodeText = if ($nodeState -eq "running") { "Node: Running" } else { "Node: Stopped" }
  $frpcText = if ($frpcState -eq "running") { "frpc: Running" } else { "frpc: Stopped" }
  $script:statusLabel.Text = "$nodeText | $frpcText"

  $allRunning = ($nodeState -eq "running" -and $frpcState -eq "running")
  $allStopped = ($nodeState -eq "stopped" -and $frpcState -eq "stopped")

  $script:startButton.Enabled = -not $allRunning
  $script:stopButton.Enabled = -not $allStopped
}

function Update-UiState {
  if ($null -eq $script:statusLabel -or $null -eq $script:startButton -or $null -eq $script:stopButton) {
    return
  }

  Invoke-ControlAction -Control $script:statusLabel -Action {
    Update-UiStateCore
  }
}

function Start-TrackedProcess {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $false)][string]$Arguments = "",
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$Tag
  )

  $logPaths = New-ProcessLogPaths -Tag $Tag

  $proc = Start-Process `
    -FilePath $FilePath `
    -ArgumentList $Arguments `
    -WorkingDirectory $WorkingDirectory `
    -PassThru `
    -RedirectStandardOutput $logPaths.RedirectStandardOutputPath `
    -RedirectStandardError $logPaths.RedirectStandardErrorPath

  return [pscustomobject]@{
    Process = $proc
    Tag = $Tag
    RedirectStandardOutputPath = $logPaths.RedirectStandardOutputPath
    RedirectStandardErrorPath = $logPaths.RedirectStandardErrorPath
    ExitLogged = $false
  }
}

function Sync-ManagedProcess {
  param(
    [Parameter(Mandatory = $false)]$ManagedProc
  )

  if ($null -eq $ManagedProc) {
    return
  }

  if ($null -eq $ManagedProc.Process) {
    return
  }

  if (-not $ManagedProc.Process.HasExited) {
    return
  }

  if ($ManagedProc.ExitLogged) {
    return
  }

  $ManagedProc.ExitLogged = $true
  Append-Log "$($ManagedProc.Tag) exited with code $($ManagedProc.Process.ExitCode)"

  $stderrTail = Get-ProcessLogTail -Path $ManagedProc.RedirectStandardErrorPath
  if ($stderrTail) {
    Append-Log "$($ManagedProc.Tag) stderr tail | $stderrTail"
  }

  $stdoutTail = Get-ProcessLogTail -Path $ManagedProc.RedirectStandardOutputPath
  if ($stdoutTail) {
    Append-Log "$($ManagedProc.Tag) stdout tail | $stdoutTail"
  }
}

function Start-AgentServices {
  if ((Get-ProcState -ProcRef $script:nodeProc) -eq "running" -or (Get-ProcState -ProcRef $script:frpcProc) -eq "running") {
    Append-Log "Services are already running."
    Update-UiState
    return
  }

  $nodePath = "node"
  $nodeArgs = $NodeEntry
  $frpcPath = Join-Path $WorkDir $FrpcExe
  $frpcArgs = "-c `"$FrpcConfig`""

  if (-not (Test-Path (Join-Path $WorkDir $NodeEntry))) {
    throw "Cannot find $NodeEntry in $WorkDir"
  }
  if (-not (Test-Path $frpcPath)) {
    throw "Cannot find $FrpcExe in $WorkDir"
  }
  if (-not (Test-Path (Join-Path $WorkDir $FrpcConfig))) {
    throw "Cannot find $FrpcConfig in $WorkDir"
  }

  $servicePort = Get-ConfiguredAppPort
  Clear-StaleManagedProcesses
  Clear-AppPortOwner -Port $servicePort

  try {
    Append-Log "Starting Node service..."
    $script:nodeProc = Start-TrackedProcess -FilePath $nodePath -Arguments $nodeArgs -WorkingDirectory $WorkDir -Tag "node"
    Append-Log "node logs -> $(Split-Path -Leaf $script:nodeProc.RedirectStandardOutputPath) / $(Split-Path -Leaf $script:nodeProc.RedirectStandardErrorPath)"
    Save-RuntimeState

    Start-Sleep -Milliseconds 500

    Append-Log "Starting frpc tunnel..."
    $script:frpcProc = Start-TrackedProcess -FilePath $frpcPath -Arguments $frpcArgs -WorkingDirectory $WorkDir -Tag "frpc"
    Append-Log "frpc logs -> $(Split-Path -Leaf $script:frpcProc.RedirectStandardOutputPath) / $(Split-Path -Leaf $script:frpcProc.RedirectStandardErrorPath)"
    Save-RuntimeState

    Start-Sleep -Milliseconds 500
    Update-UiState
  } catch {
    Stop-AgentServices
    throw
  }
}

function Stop-OneProcess {
  param(
    [Parameter(Mandatory = $false)]$ProcRef,
    [Parameter(Mandatory = $true)][string]$Tag
  )

  if ($null -eq $ProcRef) {
    return
  }
  if ($null -eq $ProcRef.Process) {
    return
  }
  if ($ProcRef.Process.HasExited) {
    return
  }

  Append-Log "Stopping $Tag (PID $($ProcRef.Process.Id))..."
  try {
    Stop-Process -Id $ProcRef.Process.Id -Force -ErrorAction Stop
  } catch {
    Append-Log "Failed to stop ${Tag}: $($_.Exception.Message)"
  }
}

function Stop-AgentServices {
  if ($script:isStopping) {
    return
  }

  $script:isStopping = $true
  try {
    Stop-OneProcess -ProcRef $script:frpcProc -Tag "frpc"
    Stop-OneProcess -ProcRef $script:nodeProc -Tag "node"
    Clear-AppPortOwner -Port (Get-ConfiguredAppPort)
    $script:frpcProc = $null
    $script:nodeProc = $null
    Clear-RuntimeState
    Update-UiState
    Append-Log "All managed processes stopped."
  } finally {
    $script:isStopping = $false
  }
}

function Build-Form {
  $form = New-Object System.Windows.Forms.Form
  $form.Text = "Remote Agent Controller"
  $form.Width = 880
  $form.Height = 620
  $form.StartPosition = "CenterScreen"
  $form.BackColor = [System.Drawing.Color]::FromArgb(16, 20, 30)
  $form.ForeColor = [System.Drawing.Color]::FromArgb(230, 236, 252)
  $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

  $header = New-Object System.Windows.Forms.Label
  $header.Text = "Remote Agent Desktop Controller"
  $header.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14)
  $header.AutoSize = $true
  $header.Location = New-Object System.Drawing.Point(18, 16)
  $form.Controls.Add($header)

  $sub = New-Object System.Windows.Forms.Label
  $sub.Text = "Open this window to start Node + frpc. Closing the window stops both."
  $sub.AutoSize = $true
  $sub.Location = New-Object System.Drawing.Point(20, 46)
  $sub.ForeColor = [System.Drawing.Color]::FromArgb(160, 176, 214)
  $form.Controls.Add($sub)

  $script:statusLabel = New-Object System.Windows.Forms.Label
  $script:statusLabel.Text = "Node: Stopped | frpc: Stopped"
  $script:statusLabel.AutoSize = $true
  $script:statusLabel.Location = New-Object System.Drawing.Point(20, 82)
  $script:statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(170, 255, 198)
  $form.Controls.Add($script:statusLabel)

  $script:startButton = New-Object System.Windows.Forms.Button
  $script:startButton.Text = "Start Services"
  $script:startButton.Width = 120
  $script:startButton.Height = 32
  $script:startButton.Location = New-Object System.Drawing.Point(20, 112)
  $script:startButton.BackColor = [System.Drawing.Color]::FromArgb(44, 108, 74)
  $script:startButton.ForeColor = [System.Drawing.Color]::White
  $script:startButton.FlatStyle = "Flat"
  $script:startButton.Add_Click({
    try {
      Start-AgentServices
    } catch {
      Append-Log "Start failed: $($_.Exception.Message)"
      Update-UiState
    }
  })
  $form.Controls.Add($script:startButton)

  $script:stopButton = New-Object System.Windows.Forms.Button
  $script:stopButton.Text = "Stop Services"
  $script:stopButton.Width = 120
  $script:stopButton.Height = 32
  $script:stopButton.Location = New-Object System.Drawing.Point(150, 112)
  $script:stopButton.BackColor = [System.Drawing.Color]::FromArgb(112, 53, 63)
  $script:stopButton.ForeColor = [System.Drawing.Color]::White
  $script:stopButton.FlatStyle = "Flat"
  $script:stopButton.Add_Click({
    Stop-AgentServices
  })
  $form.Controls.Add($script:stopButton)

  $openUiButton = New-Object System.Windows.Forms.Button
  $openUiButton.Text = "Open Web UI"
  $openUiButton.Width = 120
  $openUiButton.Height = 32
  $openUiButton.Location = New-Object System.Drawing.Point(280, 112)
  $openUiButton.FlatStyle = "Flat"
  $openUiButton.Add_Click({
    Start-Process $UiUrl | Out-Null
    Append-Log "Opened $UiUrl"
  })
  $form.Controls.Add($openUiButton)

  $script:logBox = New-Object System.Windows.Forms.TextBox
  $script:logBox.Multiline = $true
  $script:logBox.ReadOnly = $true
  $script:logBox.ScrollBars = "Vertical"
  $script:logBox.WordWrap = $false
  $script:logBox.Font = New-Object System.Drawing.Font("Consolas", 10)
  $script:logBox.BackColor = [System.Drawing.Color]::FromArgb(10, 14, 22)
  $script:logBox.ForeColor = [System.Drawing.Color]::FromArgb(216, 233, 255)
  $script:logBox.Location = New-Object System.Drawing.Point(20, 160)
  $script:logBox.Size = New-Object System.Drawing.Size(824, 400)
  $form.Controls.Add($script:logBox)

  $form.Add_Shown({
    Append-Log "Controller opened. Starting services..."
    try {
      Start-AgentServices
      Start-Process $UiUrl | Out-Null
      Append-Log "Opened $UiUrl"
    } catch {
      Append-Log "Auto-start failed: $($_.Exception.Message)"
    }
    Update-UiState
  })

  $form.Add_FormClosing({
    Stop-AgentServices
  })

  $script:timer = New-Object System.Windows.Forms.Timer
  $script:timer.Interval = 1200
  $script:timer.Add_Tick({
    Sync-ManagedProcess -ManagedProc $script:nodeProc
    Sync-ManagedProcess -ManagedProc $script:frpcProc
    Update-UiState
  })
  $script:timer.Start()

  Update-UiState
  return $form
}

[System.Windows.Forms.Application]::EnableVisualStyles()
Write-StartupTrace "agent-control.ps1 entered"
try {
  $form = Build-Form
  Write-StartupTrace "form built, calling ShowDialog"
  [void]$form.ShowDialog()
  Write-StartupTrace "ShowDialog returned"
}
catch {
  $logDir = Ensure-LogDir
  $fatalLog = Join-Path $logDir "controller-fatal.log"
  Add-Content -Path $fatalLog -Value ((Get-Date).ToString("s") + " " + $_.Exception.ToString())
  Write-ControllerLog ("[fatal] " + $_.Exception.ToString())
  Write-StartupTrace ("fatal error: " + $_.Exception.Message)
  throw
}
finally {
  Write-StartupTrace "agent-control.ps1 finally"
  if ($script:timer) {
    $script:timer.Stop()
    $script:timer.Dispose()
  }
}
