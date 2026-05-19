$ErrorActionPreference = "Stop"
$logDir = "$env:USERPROFILE\.claude\mcp-launchers"
$logFile = "$logDir\trello.log"
$stderrLog = "$logDir\trello-node-stderr.log"
function Log($msg) { Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')] $msg" -ErrorAction SilentlyContinue }

try {
    Log "=== launcher start (PID $PID) ==="
    Import-Module CredentialManager
    Log "module imported"

    $key = Get-StoredCredential -Target "claude-trello-api-key"
    if ($null -eq $key) { Log "ERROR: api-key not found"; throw "api-key missing" }
    Log "api-key OK (length=$($key.GetNetworkCredential().Password.Length))"

    $token = Get-StoredCredential -Target "claude-trello-token"
    if ($null -eq $token) { Log "ERROR: token not found"; throw "token missing" }
    Log "token OK (length=$($token.GetNetworkCredential().Password.Length))"

    $env:TRELLO_API_KEY = $key.GetNetworkCredential().Password
    $env:TRELLO_TOKEN   = $token.GetNetworkCredential().Password
    Log "env set"

    $nodeCmd = Get-Command node.exe -ErrorAction SilentlyContinue
    $nodeExe = if ($nodeCmd) { $nodeCmd.Source } else { "C:\Program Files\nodejs\node.exe" }
    $entry = "$env:APPDATA\npm\node_modules\@delorenj\mcp-server-trello\build\index.js"

    if (-not (Test-Path $nodeExe)) { Log "ERROR: node.exe not found at $nodeExe"; throw "node missing" }
    if (-not (Test-Path $entry))   { Log "ERROR: entry JS not found at $entry"; throw "entry missing" }

    Set-Content -Path $stderrLog -Value "" -Force -ErrorAction SilentlyContinue

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $nodeExe
    $psi.Arguments = """$entry"""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput  = $false
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError  = $true

    Log "spawning node + entry JS (CreateNoWindow=true)"
    $proc = [System.Diagnostics.Process]::Start($psi)
    Log "node spawned PID $($proc.Id)"
    $proc.WaitForExit()
    $stderrContent = $proc.StandardError.ReadToEnd()
    if ($stderrContent) { Add-Content -Path $stderrLog -Value $stderrContent }
    Log "node exited with $($proc.ExitCode), stderr captured: $($stderrContent.Length) bytes"
    exit $proc.ExitCode
} catch {
    Log "EXCEPTION: $($_.Exception.Message)"
    Log "TRACE: $($_.ScriptStackTrace)"
    exit 1
}
