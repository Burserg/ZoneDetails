#Requires -Version 5
<#
.SYNOPSIS
    Populates the (gitignored) Libs/ folder with the Ace3 libraries ZoneDetails needs,
    so the addon can be run/tested from a source checkout.

.DESCRIPTION
    Downloads the Ace3 library bundle and copies the libraries this addon depends on into
    Libs/. Uses only built-in PowerShell cmdlets (Invoke-WebRequest + Expand-Archive) -- no
    svn/git/bash required.

    This is a LOCAL DEVELOPMENT convenience only. Released builds get their libraries from
    the externals declared in .pkgmeta via the CurseForge packager; Libs/ is gitignored and
    never committed.

.EXAMPLE
    .\fetch-libs.ps1
#>
$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$libs   = Join-Path $root 'Libs'
$zipUrl = 'https://github.com/WoWUIDev/Ace3/archive/refs/heads/master.zip'

# Libraries ZoneDetails loads (see the .toc files). Each must exist in the Ace3 bundle.
$needed = @(
    'LibStub', 'CallbackHandler-1.0',
    'AceAddon-3.0', 'AceConsole-3.0', 'AceDB-3.0', 'AceDBOptions-3.0',
    'AceEvent-3.0', 'AceGUI-3.0', 'AceLocale-3.0', 'AceConfig-3.0'
)

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("zd-libs-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    $zip = Join-Path $tmp 'ace3.zip'
    Write-Host "Downloading Ace3 libraries ..."
    Invoke-WebRequest -Uri $zipUrl -OutFile $zip

    Write-Host "Extracting ..."
    Expand-Archive -Path $zip -DestinationPath $tmp -Force

    # The zip extracts to a single top-level folder (e.g. Ace3-master). Find it by looking
    # for a known lib subfolder so a renamed root doesn't break us.
    $src = Get-ChildItem -Path $tmp -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'AceAddon-3.0') } |
        Select-Object -First 1
    if (-not $src) { throw "Could not locate the extracted Ace3 source folder." }

    New-Item -ItemType Directory -Force -Path $libs | Out-Null
    foreach ($lib in $needed) {
        $from = Join-Path $src.FullName $lib
        if (-not (Test-Path $from)) { Write-Warning "Not found in bundle: $lib"; continue }
        $to = Join-Path $libs $lib
        if (Test-Path $to) { Remove-Item -Recurse -Force $to }
        Copy-Item -Recurse -Force $from $to
        Write-Host "  + $lib"
    }
    Write-Host "Done. Libs/ populated for local development."
}
finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
