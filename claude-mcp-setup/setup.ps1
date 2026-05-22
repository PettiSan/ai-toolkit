#Requires -Version 5.1
<#
.SYNOPSIS
    Setup Claude Desktop MCP servers on Windows, backed by Windows Credential Manager.

.DESCRIPTION
    End-to-end install:
    1. Verifies prerequisites (Node.js, npm)
    2. Installs the CredentialManager PowerShell module
    3. Installs MCP server packages globally via npm
    4. Prompts for tokens and stores them in CredMan (DPAPI)
    5. Copies launchers to ~/.claude/mcp-launchers/
    6. Merges MCP entries into claude_desktop_config.json
    7. Applies deny rules to ~/.claude/settings.json (defense in depth)

    Run as your normal user. No admin needed.

.PARAMETER SkipPackages
    Skip the global npm install of MCP packages. Use if they are already installed.

.PARAMETER SkipDenyRules
    Skip applying permissions.deny rules to settings.json.

.NOTES
    After this script: quit Claude Desktop completely (tray -> Quit) and reopen.
#>
[CmdletBinding()]
param(
    [switch]$SkipPackages,
    [switch]$SkipDenyRules
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  [ER] $msg" -ForegroundColor Red }

# --- 1. Prerequisites ---
Write-Step "Checking prerequisites"

$node = Get-Command node.exe -ErrorAction SilentlyContinue
if (-not $node) { Write-Err "Node.js not found. Install from https://nodejs.org and re-run."; exit 1 }
Write-OK "node: $($node.Source)"

$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npm) { Write-Err "npm not found. Reinstall Node.js."; exit 1 }
Write-OK "npm available"

$desktopConfig = "$env:APPDATA\Claude\claude_desktop_config.json"
$desktopDir = Split-Path $desktopConfig
if (-not (Test-Path $desktopDir)) {
    Write-Warn "Claude Desktop folder not found at $desktopDir -- creating (Desktop must be installed for this to work at runtime)"
    New-Item -ItemType Directory -Path $desktopDir -Force | Out-Null
}

# --- 2. CredentialManager module ---
Write-Step "Installing CredentialManager PowerShell module"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    }
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    if (-not (Get-Module -ListAvailable -Name CredentialManager)) {
        Install-Module -Name CredentialManager -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module CredentialManager
    Write-OK "CredentialManager module ready"
} catch {
    Write-Err "Failed to install CredentialManager: $($_.Exception.Message)"
    exit 1
}

# --- 3. npm packages ---
if ($SkipPackages) {
    Write-Step "Skipping npm package install (-SkipPackages)"
} else {
    Write-Step "Installing MCP packages globally via npm"
    $packages = @("@modelcontextprotocol/server-github", "@delorenj/mcp-server-trello")
    foreach ($pkg in $packages) {
        Write-Host "  installing $pkg ..."
        & npm install -g $pkg | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Err "npm install of $pkg failed"; exit 1 }
        Write-OK "installed $pkg"
    }
}

# --- 4. Store tokens in CredMan ---
Write-Step "Storing tokens in Windows Credential Manager"
Write-Host "  Input is hidden. Press Enter on empty value to skip a target." -ForegroundColor Gray

$tokens = @(
    @{ Target="claude-github-pat-personal"; Label="GitHub fine-grained PAT (your personal account)" },
    @{ Target="claude-github-pat-smartcob"; Label="GitHub fine-grained PAT (SmartcobSolutions org)" },
    @{ Target="claude-trello-api-key";      Label="Trello API key" },
    @{ Target="claude-trello-token";        Label="Trello token (from same Power-Up page as API key)" },
    @{ Target="claude-figma-api-key";       Label="Figma PAT (optional)" }
)
foreach ($t in $tokens) {
    Write-Host ""
    Write-Host "  $($t.Label)" -ForegroundColor White
    Write-Host "  CredMan target: $($t.Target)" -ForegroundColor Gray
    $secure = Read-Host "  Paste value" -AsSecureString
    if ($secure.Length -eq 0) {
        Write-Warn "skipped"
        continue
    }
    New-StoredCredential -Target $t.Target -UserName "claude" `
        -SecurePassword $secure -Persist LocalMachine | Out-Null
    Write-OK "stored $($t.Target)"
}

# --- 5. Copy launchers ---
Write-Step "Copying launchers to user profile"

$dest = "$env:USERPROFILE\.claude\mcp-launchers"
New-Item -ItemType Directory -Path $dest -Force | Out-Null

$repoLaunchers = Join-Path $PSScriptRoot "launchers"
if (-not (Test-Path $repoLaunchers)) {
    Write-Err "launchers/ folder not found next to setup.ps1. Run from the claude-mcp-setup directory."
    exit 1
}
Get-ChildItem -Path $repoLaunchers -Filter "*.ps1" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $dest -Force
    Write-OK "copied $($_.Name)"
}

# --- 5b. Register orphan-cleanup scheduled task ---
Write-Step "Registering MCP orphan-cleanup scheduled task"

$cleanupScript = Join-Path $dest "cleanup-mcp-orphans.ps1"
if (Test-Path $cleanupScript) {
    # Register-ScheduledTask returns Access Denied in some contexts (writes to the task
    # library root); schtasks.exe registers reliably in the current-user context.
    $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $cleanupScript"
    & schtasks.exe /Create /TN "Claude MCP orphan cleanup" /TR $tr /SC HOURLY /MO 4 /F /IT /RL LIMITED | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-OK "scheduled task 'Claude MCP orphan cleanup' (every 4h)" }
    else { Write-Warn "could not register scheduled task (exit $LASTEXITCODE) -- see INSTALL.md to create it manually" }
} else {
    Write-Warn "cleanup-mcp-orphans.ps1 not found in $dest -- skipping task registration"
}

# --- 6. Merge MCP entries into claude_desktop_config.json ---
Write-Step "Updating Claude Desktop config"

$launcherPath = $dest
$ourMcps = [PSCustomObject]@{
    "github-personal" = [PSCustomObject]@{
        command = "powershell.exe"
        args = @("-NoProfile","-ExecutionPolicy","Bypass","-File","$launcherPath\github-personal.ps1")
    }
    "github-smartcob" = [PSCustomObject]@{
        command = "powershell.exe"
        args = @("-NoProfile","-ExecutionPolicy","Bypass","-File","$launcherPath\github-smartcob.ps1")
    }
    "trello" = [PSCustomObject]@{
        command = "powershell.exe"
        args = @("-NoProfile","-ExecutionPolicy","Bypass","-File","$launcherPath\trello.ps1")
    }
}

if (Test-Path $desktopConfig) {
    Write-OK "merging into existing config"
    $existing = Get-Content -Raw -Path $desktopConfig | ConvertFrom-Json
    if (-not $existing.PSObject.Properties['mcpServers']) {
        $existing | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([PSCustomObject]@{})
    }
    foreach ($prop in $ourMcps.PSObject.Properties) {
        if ($existing.mcpServers.PSObject.Properties[$prop.Name]) {
            $existing.mcpServers.($prop.Name) = $prop.Value
        } else {
            $existing.mcpServers | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
        }
    }
    $final = $existing
} else {
    Write-OK "creating new config"
    $final = [PSCustomObject]@{ mcpServers = $ourMcps }
}

$out = $final | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($desktopConfig, $out, [System.Text.UTF8Encoding]::new($false))
Write-OK "wrote $desktopConfig"

# --- 7. Deny rules ---
if ($SkipDenyRules) {
    Write-Step "Skipping deny rules (-SkipDenyRules)"
} else {
    Write-Step "Applying deny rules to ~/.claude/settings.json"

    $settingsPath = "$env:USERPROFILE\.claude\settings.json"
    $newRules = @(
        "Read(**/claude_desktop_config.json)",
        "Read(**/mcp-launchers/**)",
        "Read(**/.env)",
        "Read(**/.env.*)",
        "Bash(cat:**/.env)",
        "Bash(cat:**/.env.*)",
        "Bash(Get-Content:**/.env)",
        "Bash(Get-Content:**/.env.*)",
        "Bash(type:**/.env)",
        "Bash(type:**/.env.*)"
    )

    if (Test-Path $settingsPath) {
        $s = Get-Content -Raw -Path $settingsPath | ConvertFrom-Json
    } else {
        New-Item -ItemType Directory -Path (Split-Path $settingsPath) -Force | Out-Null
        $s = [PSCustomObject]@{}
    }

    if (-not $s.PSObject.Properties['permissions']) {
        $s | Add-Member -NotePropertyName 'permissions' -NotePropertyValue ([PSCustomObject]@{ deny = $newRules })
    } elseif (-not $s.permissions.PSObject.Properties['deny']) {
        $s.permissions | Add-Member -NotePropertyName 'deny' -NotePropertyValue $newRules
    } else {
        $merged = @((@($s.permissions.deny) + $newRules) | Sort-Object -Unique)
        $s.permissions.deny = $merged
    }

    $sOut = $s | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($settingsPath, $sOut, [System.Text.UTF8Encoding]::new($false))
    Write-OK "applied $($newRules.Count) deny rules"
}

# --- Done ---
Write-Step "Done"
Write-Host ""
Write-Host "Next:" -ForegroundColor White
Write-Host "  1. Quit Claude Desktop completely (tray icon -> Quit)"
Write-Host "  2. Reopen Claude Desktop"
Write-Host "  3. Test in a new conversation:"
Write-Host '       "Use mcp__github-personal to show README of <any-repo-you-own>"' -ForegroundColor Gray
Write-Host ""
