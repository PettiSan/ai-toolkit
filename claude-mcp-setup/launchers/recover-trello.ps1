# recover-trello.ps1
# Forca o respawn do MCP do Trello: mata todos os processos node do Trello para o Claude Code
# subir novos na proxima chamada. Util para limpar processos zumbis/duplicados.
#
# ATENCAO: NAO conserta o 401 pos-suspend neste setup. Esse 401 vem do .mcp.json (npx) subir
# sem token porque TRELLO_API_KEY/TRELLO_TOKEN nao estao no ambiente do Windows; o respawn
# tambem sobe sem token. Para esse caso, abra uma sessao nova.

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
