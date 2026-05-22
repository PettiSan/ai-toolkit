# recover-trello.ps1
# Recuperacao on-demand do MCP do Trello apos suspend (sintoma: 401 em chamadas que antes funcionavam).
#
# Como funciona: o processo do MCP fica vivo-mas-zumbi depois do suspend. O Claude Code ve
# um servidor "vivo" e nao respawna. Este script MATA os processos do Trello; na proxima
# chamada ao Trello dentro do chat, o Claude Code respawna um processo limpo (comportamento validado).
#
# Uso: rode este script, depois retente qualquer acao do Trello no chat travado.
#      NAO precisa abrir sessao nova nem reiniciar o Desktop.

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
