<#
.SYNOPSIS
    Extracts PortalSDK.zip, stages source files, and generates TypeDoc documentation.

.DESCRIPTION
    PowerShell 7 port of generate-docs.sh. Extracts PortalSDK.zip, moves the
    required SDK/modlib files into ./src, patches modlib.ts with a triple-slash
    reference directive, and runs TypeDoc to build documentation.
#>

[CmdletBinding()]
param(
    [string]$ZipPath = 'PortalSDK.zip',
    [string]$TempDir = 'tmp',
    [string]$SrcDir = 'src',
    [string]$DocsDir = 'docs',
    [string]$ReadmePath = 'README.md',

    # Skip extraction entirely and reuse whatever is already in $TempDir.
    [switch]$SkipExtraction,

    # Force re-extraction even if $TempDir already exists, no prompt.
    [switch]$ForceExtraction,

    # Delete $TempDir after the run. Off by default so a slow extraction can be
    # reused via -SkipExtraction on a subsequent run.
    [switch]$CleanTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

try {
    # --- Remove old docs (always) ---------------------------------------------------
    if (Test-Path -LiteralPath $DocsDir) {
        Remove-Item -LiteralPath $DocsDir -Recurse -Force
    }
    # NOTE: Do NOT remove $SrcDir here. It is recreated fresh below (line 72) before
    # files are moved into it. Removing it here causes an empty src/ if the move fails.

    # --- Extraction checkpoint -------------------------------------------------------
    $tempExists = Test-Path -LiteralPath $TempDir

    $doExtract = $true
    if ($SkipExtraction) {
        if (-not $tempExists) {
            throw "-SkipExtraction was specified but '$TempDir' does not exist."
        }
        $doExtract = $false
        Write-Step "Skipping extraction (using existing '$TempDir')"
    }
    elseif ($tempExists -and -not $ForceExtraction) {
        $choice = Read-Host "'$TempDir' already exists from a previous run. Re-extract ${ZipPath}? (y/N)"
        if ($choice -notmatch '^(?i:y|yes)$')
        {
            $doExtract = $false
            Write-Step "Skipping extraction (using existing '$TempDir')"
        }
    }

    if ($doExtract) {
        Write-Step "Extracting $ZipPath"

        if (-not (Test-Path -LiteralPath $ZipPath)) {
            throw "Zip file not found: $ZipPath"
        }

        if ($tempExists) {
            Remove-Item -LiteralPath $TempDir -Recurse -Force
        }
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $TempDir -Force
    }

    # --- Create src directory if it doesn't exist ----------------------------------
    New-Item -ItemType Directory -Path $SrcDir -Force | Out-Null

    # --- Copy the required files to src folder --------------------------------------
    $sdkSource = Join-Path $TempDir 'code/types/mod/index.d.ts'
    $modlibSource = Join-Path $TempDir 'code/modlib/index.ts'

    $sdkDest = Join-Path $SrcDir 'sdk.d.ts'
    $modlibDest = Join-Path $SrcDir 'modlib.ts'

    if (-not (Test-Path -LiteralPath $sdkSource)) {
        throw "Expected SDK typings not found: $sdkSource"
    }
    if (-not (Test-Path -LiteralPath $modlibSource)) {
        throw "Expected modlib source not found: $modlibSource"
    }

    Copy-Item -LiteralPath $sdkSource -Destination $sdkDest -Force
    Copy-Item -LiteralPath $modlibSource -Destination $modlibDest -Force


    # --- Prepend triple-slash reference directive to modlib.ts (if not already present) ---
    $referenceDirective = '/// <reference path="./sdk.d.ts" />'
    $content = Get-Content -LiteralPath $modlibDest -Raw

    if ($content -notmatch '///\s*<reference\s+path="\.\/sdk\.d\.ts"\s*\/>') {
        $newContent = "$referenceDirective`n`n$content"
        Set-Content -LiteralPath $modlibDest -Value $newContent -Encoding utf8
    }
    else {
        Write-Verbose 'Reference directive already present in modlib.ts; skipping insert.'
    }

    # --- Clean up temporary directory (opt-in; kept by default for reuse) ------------
    if ($CleanTemp) {
        Remove-Item -LiteralPath $TempDir -Recurse -Force
    }
    else {
        Write-Verbose "Leaving '$TempDir' in place. Use -SkipExtraction next run to reuse it, or -CleanTemp to delete it now."
    }

    # --- Generate documentation using typedoc ----------------------------------------
    Write-Step 'Generating documentation with TypeDoc'

    $typedocArgs = @(
        '--config', 'typedoc.json'
        '--entryPoints', $SrcDir
    )

    if (Get-Command npx -ErrorAction SilentlyContinue) {
        & npx typedoc @typedocArgs
    }
    elseif (Get-Command typedoc -ErrorAction SilentlyContinue) {
        & typedoc @typedocArgs
    }
    else {
        throw 'typedoc or npx not found on PATH.'
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