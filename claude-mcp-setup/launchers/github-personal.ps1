$ErrorActionPreference = "Stop"
$logDir = "$env:USERPROFILE\.claude\mcp-launchers"
$logFile = "$logDir\github-personal.log"
$stderrLog = "$logDir\github-personal-node-stderr.log"
function Log($msg) { Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')] $msg" -ErrorAction SilentlyContinue }

try {
    Log "=== launcher start (PID $PID) ==="
    Import-Module CredentialManager
    Log "module imported"

    $cred = Get-StoredCredential -Target "claude-github-pat-personal"
    if ($null -eq $cred) { Log "ERROR: credential not found"; throw "credential missing" }
    Log "credential OK (length=$($cred.GetNetworkCredential().Password.Length))"
    $env:GITHUB_PERSONAL_ACCESS_TOKEN = $cred.GetNetworkCredential().Password
    Log "env set"

    $nodeCmd = Get-Command node.exe -ErrorAction SilentlyContinue
    $nodeExe = if ($nodeCmd) { $nodeCmd.Source } else { "C:\Program Files\nodejs\node.exe" }
    $entry = "$env:APPDATA\npm\node_modules\@modelcontextprotocol\server-github\dist\index.js"

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
