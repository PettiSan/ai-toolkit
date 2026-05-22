# cleanup-mcp-orphans.ps1
# Faxina periodica: mata processos MCP (node) ORFAOS - aqueles cujo processo-pai ja morreu.
#
# Por que e seguro rodar sem supervisao: um MCP orfao (pai morto) nao esta conectado a
# nenhuma sessao viva - o pipe stdio com o pai esta quebrado e ninguem fala com ele.
# Alem disso, o Claude Code respawna MCP sob demanda, entao matar algo a mais nunca deixa
# uma sessao sem servidor: a proxima chamada sobe um novo.
#
# Limitacao conhecida: NAO pega processos abandonados no suspend cujo pai (a sessao do
# Claude) ainda esta aberto - esses so viram orfaos quando a sessao fecha, e ai a proxima
# rodada os recolhe. Para o caso agudo na sua sessao atual, use recover-trello.ps1.
#
# Agendado via Windows Task Scheduler (task "Claude MCP orphan cleanup").

$ErrorActionPreference = "Stop"
$log = "$env:USERPROFILE\.claude\mcp-launchers\cleanup-mcp.log"
function Log($m) { Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $m" -ErrorAction SilentlyContinue }

$pattern = 'mcp-server-trello|server-github|figma'
$allPids = (Get-CimInstance Win32_Process).ProcessId
$mcp     = Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match $pattern }
$orphans = $mcp | Where-Object { $allPids -notcontains $_.ParentProcessId }

Log "scan - mcp=$($mcp.Count) orphans=$($orphans.Count)"
foreach ($p in $orphans) {
    try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop; Log "killed orphan PID $($p.ProcessId)" }
    catch { Log "falha PID $($p.ProcessId): $($_.Exception.Message)" }
}
Log "done - matou $($orphans.Count) orfaos (mcp vivos restantes nao-orfaos preservados)"
