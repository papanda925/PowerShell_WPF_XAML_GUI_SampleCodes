[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$errorsFound = [System.Collections.Generic.List[string]]::new()

Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File -Include *.ps1,*.psm1 | ForEach-Object {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in $parseErrors) {
        $errorsFound.Add("PowerShell parse error: $($_.FullName):$($parseError.Extent.StartLineNumber):$($parseError.Extent.StartColumnNumber) $($parseError.Message)")
    }
}

Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File -Include *.xaml | ForEach-Object {
    try {
        [xml]$null = Get-Content -LiteralPath $_.FullName -Raw
    }
    catch {
        $errorsFound.Add("XML parse error: $($_.FullName): $($_.Exception.Message)")
    }
}

if ($errorsFound.Count -gt 0) {
    $errorsFound | ForEach-Object { Write-Error $_ }
    throw "$($errorsFound.Count) repository validation error(s) found."
}

Write-Host 'PowerShell syntax and XAML/XML well-formedness checks passed.'
