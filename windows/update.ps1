<#
.SYNOPSIS
  Brings this computer's Acapella up to date with origin/main in one go.

.DESCRIPTION
  The whole of a "git pull and update the app" request as one command, so a session runs it
  once and reports what it printed instead of doing each step by hand:

    1. fetch origin and fast-forward this checkout to origin/main
    2. read the commit the installed exe was built from
    3. skip the build when nothing that goes into the app changed since that commit
    4. otherwise publish.ps1 (with its self-test), install.ps1, then read the version back
    5. update this computer's row in docs/COMPUTERS.md

  It never commits or pushes: COMPUTERS.md is left modified for the session to commit once
  Dave says so, and the other computers still need thinking about (COMPUTERS.md step 5).

  install.ps1 force-stops the app, losing any dictation in progress, so run -CheckOnly first
  and ask Dave before the real run whenever it says a rebuild is needed.

.PARAMETER CheckOnly
  Fetch and report what an update would do, changing nothing.

.PARAMETER Force
  Rebuild and reinstall even when the installed build already matches.
#>
param(
    [switch]$CheckOnly,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

function Invoke-Git {
    $out = & git @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed:`n$out" }
    $out
}

$exePath = Join-Path $env:LOCALAPPDATA 'Programs\Acapella\Acapella.exe'
function Get-InstalledCommit {
    if (-not (Test-Path $exePath)) { return $null }
    $v = (Get-Item $exePath).VersionInfo.ProductVersion
    if ($v -match '\+([0-9a-f]{7,40})') { return $Matches[1] }
    return $null
}

$computer = hostname
Write-Host "computer   $computer"

# 1. Pull. Only a fast-forward: a checkout with its own commits or edits is someone's work.
Invoke-Git fetch origin --quiet | Out-Null
$dirty = Invoke-Git status --porcelain --untracked-files=no
if ($dirty) { throw "this checkout has uncommitted changes; commit or set them aside first:`n$($dirty -join "`n")" }

$head   = (Invoke-Git rev-parse HEAD).Trim()
$target = (Invoke-Git rev-parse origin/main).Trim()
& git merge-base --is-ancestor $head $target
if ($LASTEXITCODE -ne 0) {
    throw "HEAD ($($head.Substring(0,7))) has commits origin/main doesn't; merge them to main first, then update"
}
$incoming = @(Invoke-Git log --oneline "$head..$target")
Write-Host "checkout   $($head.Substring(0,7)) -> $($target.Substring(0,7))  ($($incoming.Count) new commit(s))"
$incoming | ForEach-Object { Write-Host "             $_" }

# 2-3. What's installed, and does the difference touch the app at all?
$installed = Get-InstalledCommit
if (-not $installed) {
    Write-Host 'installed  nothing (or a build with no commit stamp)'
    $needsBuild = $true
} else {
    $installed = (Invoke-Git rev-parse $installed).Trim()
    Write-Host "installed  $($installed.Substring(0,7))"
    # Only what goes into the exe; scripts, tests and docs beside it don't need a rebuild.
    & git diff --quiet $installed $target -- windows/src windows/Directory.Build.props windows/Directory.Packages.props windows/global.json shared
    $needsBuild = $LASTEXITCODE -ne 0
}
if ($Force) { $needsBuild = $true }

if ($CheckOnly) {
    if (-not $needsBuild) {
        Write-Host 'result     no rebuild needed: nothing that goes into the app changed since the installed build'
    } else {
        Write-Host 'result     rebuild needed; installing will force-stop Acapella, so ask Dave before the real run'
    }
    return
}

if ($head -ne $target) { Invoke-Git merge --ff-only --quiet $target | Out-Null }

if (-not $needsBuild) {
    Write-Host 'result     up to date: nothing that goes into the app changed since the installed build, so no rebuild'
    return
}

# 4. Build, install, and check the exe now says what we built.
$sw = [Diagnostics.Stopwatch]::StartNew()
$log = [Collections.Generic.List[string]]::new()
try {
    & (Join-Path $PSScriptRoot 'publish.ps1') *>&1 | ForEach-Object { $log.Add("$_") }
} catch {
    $log | Select-Object -Last 30 | ForEach-Object { Write-Host $_ }
    throw
}
Write-Host "published  self-test passed ($([int]$sw.Elapsed.TotalSeconds)s)"
& (Join-Path $PSScriptRoot 'install.ps1') | Out-Null
$now = Get-InstalledCommit
if (-not $now -or -not $target.StartsWith($now)) { throw "installed exe reports $now, expected $($target.Substring(0,7))" }
Write-Host "installed  $($target.Substring(0,7)), running"

# 5. This computer's row in COMPUTERS.md: Computer | OS | App | Installed build | Updated
$doc   = Join-Path $repo 'docs\COMPUTERS.md'
$lines = Get-Content $doc
$row   = $lines | Where-Object { $_ -like "| $computer |*" } | Select-Object -First 1
if ($row) {
    $cells = $row.Split('|')
    $cells[4] = " $($target.Substring(0,7)) "
    $cells[5] = " $(Get-Date -Format 'dd/MM/yyyy') "
    $lines = $lines | ForEach-Object { if ($_ -eq $row) { $cells -join '|' } else { $_ } }
    [IO.File]::WriteAllLines($doc, [string[]]$lines, [Text.UTF8Encoding]::new($false))
    Write-Host 'recorded   docs/COMPUTERS.md row updated (not committed)'
} else {
    Write-Host "recorded   no row for $computer in docs/COMPUTERS.md; add one by hand"
}
Write-Host 'result     updated'
