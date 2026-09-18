#Requires -Version 7.0
<#
.SYNOPSIS
    Generates TypeDoc documentation from the SDK files in ./src.

.DESCRIPTION
    src/modlib.ts and src/sdk.d.ts are the SDK source of truth. If either file
    is missing, PortalSDK.zip or an existing ./tmp extraction is used as a
    compatibility fallback.
#>

[CmdletBinding()]
param(
    [string]$ZipPath = 'PortalSDK.zip',
    [string]$TempDir = 'tmp',
    [string]$SrcDir = 'src',
    [string]$DocsDir = 'docs',
    [switch]$SkipExtraction,
    [switch]$ForceExtraction,
    [switch]$CleanTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

try {
    if (Test-Path -LiteralPath $DocsDir) {
        Remove-Item -LiteralPath $DocsDir -Recurse -Force
    }

    $sdkDest = Join-Path $SrcDir 'sdk.d.ts'
    $modlibDest = Join-Path $SrcDir 'modlib.ts'

    if (-not (Test-Path -LiteralPath $sdkDest) -or -not (Test-Path -LiteralPath $modlibDest)) {
        $tempExists = Test-Path -LiteralPath $TempDir
        $archiveExists = Test-Path -LiteralPath $ZipPath

        if ($ForceExtraction -or (-not $SkipExtraction -and -not $tempExists -and $archiveExists)) {
            Write-Step "Extracting $ZipPath"
            if ($tempExists) {
                Remove-Item -LiteralPath $TempDir -Recurse -Force
            }
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $TempDir -Force
        }

        $sdkSource = Join-Path $TempDir 'code/types/mod/index.d.ts'
        $modlibSource = Join-Path $TempDir 'code/modlib/index.ts'
        if (-not (Test-Path -LiteralPath $sdkSource) -or -not (Test-Path -LiteralPath $modlibSource)) {
            throw "SDK source files are required at '$sdkDest' and '$modlibDest'."
        }

        New-Item -ItemType Directory -Path $SrcDir -Force | Out-Null
        Copy-Item -LiteralPath $sdkSource -Destination $sdkDest -Force
        Copy-Item -LiteralPath $modlibSource -Destination $modlibDest -Force
    }
    else {
        Write-Step "Using SDK sources from '$SrcDir'"
    }

    $referenceDirective = '/// <reference path="./sdk.d.ts" />'
    $content = Get-Content -LiteralPath $modlibDest -Raw
    if ($content -notmatch [regex]::Escape($referenceDirective)) {
        Set-Content -LiteralPath $modlibDest -Value "$referenceDirective`n`n$content" -NoNewline -Encoding utf8
    }

    if ($CleanTemp -and (Test-Path -LiteralPath $TempDir)) {
        Remove-Item -LiteralPath $TempDir -Recurse -Force
    }

    Write-Step 'Generating documentation with TypeDoc and clean-jsdoc-theme'
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        & pnpm exec typedoc --options typedoc.json
    }
    elseif (Get-Command npx -ErrorAction SilentlyContinue) {
        & npx typedoc --options typedoc.json
    }
    else {
        throw 'Neither pnpm nor npx was found on PATH. Install Node.js/pnpm to run typedoc.'
    }

    if ($LASTEXITCODE -ne 0) {
        throw "typedoc exited with code $LASTEXITCODE"
    }

    Write-Step 'Done.'
}
catch {
    Write-Error "generate-docs.ps1 failed: $_"
    exit 1
}
