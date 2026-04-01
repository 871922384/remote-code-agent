const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const script = fs.readFileSync(
  path.join(__dirname, '..', 'agent-control.ps1'),
  'utf8'
);

test('controller script includes file-backed controller logging', () => {
  assert.match(script, /controller\.log/);
  assert.match(script, /function Write-ControllerLog/);
});

test('controller script marshals textbox writes onto the UI thread', () => {
  assert.match(script, /\.InvokeRequired/);
  assert.match(script, /BeginInvoke\(/);
  assert.match(script, /Append-LogToTextBox/);
});

test('controller script avoids background-thread PowerShell event handlers for process output', () => {
  assert.doesNotMatch(script, /add_OutputDataReceived/);
  assert.doesNotMatch(script, /add_ErrorDataReceived/);
  assert.doesNotMatch(script, /add_Exited/);
  assert.match(script, /RedirectStandardOutputPath/);
  assert.match(script, /Get-ProcessLogTail/);
});

test('controller script uses per-run process log files instead of reusing fixed stdout handles', () => {
  assert.match(script, /Get-Date -Format "yyyyMMdd-HHmmss-fff"/);
  assert.match(script, /\$Tag-\$stamp-out\.log/);
  assert.match(script, /\$Tag-\$stamp-err\.log/);
  assert.doesNotMatch(script, /Join-Path \$logDir "\$Tag\.log"/);
  assert.doesNotMatch(script, /Join-Path \$logDir "\$Tag\.err\.log"/);
});
