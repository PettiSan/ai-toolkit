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
    6. Deploys commands/, agents/ and claude/CLAUDE.md to ~/.claude/ (Desktop reads them there)
    7. Merges MCP entries into claude_desktop_config.json
    8. Applies deny rules to ~/.claude/settings.json (defense in depth)

    Run as your normal user. No admin needed.

.PARAMETER SkipPackages
    Skip the global npm install of MCP packages. Use if they are already installed.

.PARAMETER SkipDenyRules
    Skip applying permissions.deny rules to settings.json.

.PARAMETER RestoreSettings
    Restore the full Desktop settings.json from the versioned snapshot
    (claude/settings.windows.json). Backs up any existing settings.json first.
    Use on a fresh machine. Off by default so a normal run never clobbers a live
    settings.json that is newer than the snapshot.

.PARAMETER DeployOnly
    Re-sync mode: copy files only (launchers, hooks, commands, agents, CLAUDE.md) and
    skip everything else -- prerequisite checks, CredentialManager install, npm packages,
    the five token prompts, scheduled-task registration, the Desktop config merge and the
    deny rules. Use this after pulling changes to commands/, agents/ or claude/CLAUDE.md.

    Why it exists: deploying those three is what keeps ~/.claude in sync with this repo,
    so it has to be cheap enough to actually run. A full run costs five Read-Host prompts
    and rewrites claude_desktop_config.json, which is enough friction to get skipped --
    and skipping it is exactly how the Windows profile drifted from the repo in the first
    place.

.NOTES
    After this script: quit Claude Desktop completely (tray -> Quit) and reopen.
#>
[CmdletBinding()]
param(
    [switch]$SkipPackages,
    [switch]$SkipDenyRules,
    [switch]$RestoreSettings,
    [switch]$DeployOnly
)

$ErrorActionPreference = "Stop"

# -DeployOnly reuses the existing skip switches where they already exist, and adds guards
# below for the steps that had none.
if ($DeployOnly) {
    $SkipPackages  = $true
    $SkipDenyRules = $true
}

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  [ER] $msg" -ForegroundColor Red }

if ($DeployOnly) {
    Write-Step "Skipping prerequisites, CredentialManager and token prompts (-DeployOnly)"
} else {

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

}  # end of the -DeployOnly guard opened before step 1

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
if ($DeployOnly) {
    Write-Step "Skipping scheduled-task registration (-DeployOnly)"
} else {
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
}  # end of the -DeployOnly guard for step 5b

# --- 5c. Deploy Claude Code hooks ---
Write-Step "Deploying Claude Code hooks"

$hooksDest = "$env:USERPROFILE\.claude\hooks"
$repoHooks = Join-Path $PSScriptRoot "..\claude\hooks"
if (Test-Path $repoHooks) {
    New-Item -ItemType Directory -Path $hooksDest -Force | Out-Null
    Get-ChildItem -Path $repoHooks -Filter "*.js" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $hooksDest -Force
        Write-OK "deployed hook $($_.Name)"
    }
} else {
    Write-Warn "claude/hooks not found at $repoHooks -- skipping hook deploy"
}

# --- 5d. Restore full settings.json from snapshot (opt-in) ---
if ($RestoreSettings) {
    Write-Step "Restoring settings.json from snapshot (-RestoreSettings)"

    $settingsLive = "$env:USERPROFILE\.claude\settings.json"
    $snapshot = Join-Path $PSScriptRoot "..\claude\settings.windows.json"
    if (-not (Test-Path $snapshot)) {
        Write-Err "snapshot not found at $snapshot"
        exit 1
    }
    New-Item -ItemType Directory -Path (Split-Path $settingsLive) -Force | Out-Null
    if (Test-Path $settingsLive) {
        $bak = "$settingsLive.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
        Copy-Item -Path $settingsLive -Destination $bak -Force
        Write-OK "backed up existing settings.json -> $(Split-Path $bak -Leaf)"
    }
    Copy-Item -Path $snapshot -Destination $settingsLive -Force
    Write-OK "restored settings.json from snapshot"
}

# --- 5e. Deploy commands and agents ---
# setup.sh symlinks these on Linux/WSL; on Windows there was no install path at all, so
# commands and agents shipped in this repo never reached the Desktop profile. Copy, not
# symlink: Windows symlinks need Developer Mode or admin, and every other asset here
# (launchers, hooks, settings snapshot) is already deployed by copy.
Write-Step "Deploying commands and agents"

# No Resolve-Path here: over a UNC clone (\\wsl.localhost\...) it returns a
# provider-qualified path ("Microsoft.PowerShell.Core\FileSystem::\\...") that leaks into
# messages and breaks when handed to native commands. Step 5c uses the same plain form.
$repoRoot = Join-Path $PSScriptRoot ".."
foreach ($kind in @("commands", "agents")) {
    $srcDir = Join-Path $repoRoot $kind
    if (-not (Test-Path $srcDir)) {
        Write-Warn "$kind/ not found at $srcDir -- skipping"
        continue
    }
    $dstDir = "$env:USERPROFILE\.claude\$kind"
    New-Item -ItemType Directory -Path $dstDir -Force | Out-Null

    # File-by-file on purpose -- NEVER mirror-with-delete. ~/.claude/agents legitimately
    # holds local-only agents that are not versioned here (e.g. teste-eco.md); wiping the
    # directory to match the repo would destroy them.
    $files = @(Get-ChildItem -Path $srcDir -Filter "*.md" -File)
    if ($files.Count -eq 0) {
        Write-Warn "no .md files in $kind/ -- nothing to deploy"
        continue
    }
    foreach ($f in $files) {
        Copy-Item -Path $f.FullName -Destination $dstDir -Force
        Write-OK "deployed $kind/$($f.Name)"
    }
}
# Global CLAUDE.md. setup.sh symlinks this on Linux; without an equivalent here the Windows
# copy was hand-edited for months and diverged from the repo in both directions. The repo is
# the source of truth -- but back up first, so a hand-edit that was never pushed is recoverable
# instead of silently destroyed (same caution as -RestoreSettings).
$claudeMdSrc = Join-Path $repoRoot "claude\CLAUDE.md"
$claudeMdDst = "$env:USERPROFILE\.claude\CLAUDE.md"
if (Test-Path $claudeMdSrc) {
    if ((Test-Path $claudeMdDst) -and
        (Get-FileHash $claudeMdSrc).Hash -ne (Get-FileHash $claudeMdDst).Hash) {
        $bak = "$claudeMdDst.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
        Copy-Item -Path $claudeMdDst -Destination $bak -Force
        Write-Warn "existing CLAUDE.md differed from the repo -- backed up to $(Split-Path $bak -Leaf)"
    }
    Copy-Item -Path $claudeMdSrc -Destination $claudeMdDst -Force
    Write-OK "deployed claude/CLAUDE.md"
} else {
    Write-Warn "claude/CLAUDE.md not found at $claudeMdSrc -- skipping"
}

Write-Warn "commands, agents and CLAUDE.md are only rescanned on boot -- quit Claude Desktop completely and reopen"

# --- 6. Merge MCP entries into claude_desktop_config.json ---
if ($DeployOnly) {
    Write-Step "Skipping Claude Desktop config merge (-DeployOnly)"
} else {
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
}  # end of the -DeployOnly guard for step 6

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
        "Read(**/.env.*)"
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
