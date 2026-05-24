# recover-trello.ps1
# Forca o respawn do MCP do Trello: mata todos os processos node do Trello para subirem
# novos na proxima chamada. Util SOMENTE para limpar processos zumbis/duplicados (vazamento).
#
# ATENCAO: NAO conserta 401. No Desktop o token do Trello vem do Windows Credential Manager
# (trello.ps1 -> Get-StoredCredential), nao do ambiente. Um 401 significa token revogado/expirado;
# o conserto e regravar um token valido no CredMan (New-StoredCredential) + restart do Desktop,
# nao matar processos. O respawn rele o mesmo token do CredMan.

$ErrorActionPreference = "Stop"
$log = "$env:USERPROFILE\.claude\mcp-launchers\recover-trello.log"
function Log($m) { Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $m" -ErrorAction SilentlyContinue }

$procs = Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'mcp-server-trello' }
Log "recover start - encontrados $($procs.Count) processos trello"
Write-Output "Processos Trello encontrados: $($procs.Count)"

foreach ($p in $procs) {
    try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop; Log "killed PID $($p.ProcessId)" }
    catch { Log "falha ao matar PID $($p.ProcessId): $($_.Exception.Message)" }
}

Start-Sleep -Seconds 1
$left = (Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'mcp-server-trello' }).Count
Log "recover done - restantes $left"
Write-Output "Restantes: $left"
Write-Output "Agora retente uma acao do Trello no chat - o Claude Code respawna um processo limpo."
