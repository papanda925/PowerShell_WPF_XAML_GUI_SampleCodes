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

$requiredFiles = @(
    'XamlDesigner\Start-XamlDesigner.ps1',
    'XamlDesigner\XamlDesigner.xaml',
    'XamlDesigner\XamlDesigner.Core.psm1',
    'XamlDesigner\Templates\BlankWindow.xaml',
    'XamlDesigner\Templates\BlankWindow.ps1'
)
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath))) {
        $errorsFound.Add("Required designer file is missing: $relativePath")
    }
}

$templateCodePath = Join-Path $repositoryRoot 'XamlDesigner\Templates\BlankWindow.ps1'
if (Test-Path -LiteralPath $templateCodePath) {
    $templateCode = Get-Content -LiteralPath $templateCodePath -Raw
    foreach ($marker in @(
        '# <XamlDesigner:XamlFile>',
        '# </XamlDesigner:XamlFile>',
        '# <XamlDesigner:ControlReferences>',
        '# </XamlDesigner:ControlReferences>'
    )) {
        if (-not $templateCode.Contains($marker)) {
            $errorsFound.Add("Generated-code marker is missing from BlankWindow.ps1: $marker")
        }
    }
}

if ($errorsFound.Count -gt 0) {
    $errorsFound | ForEach-Object { Write-Error $_ }
    throw "$($errorsFound.Count) repository validation error(s) found."
}

Write-Host 'PowerShell syntax, XAML/XML well-formedness, required files, and generated-code marker checks passed.'
