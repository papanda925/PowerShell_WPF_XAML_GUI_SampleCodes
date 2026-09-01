[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$errorsFound = [System.Collections.Generic.List[string]]::new()

Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File |
Where-Object { $_.Extension -in @('.ps1', '.psm1') } |
ForEach-Object {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in $parseErrors) {
        $errorsFound.Add("PowerShell parse error: $($_.FullName):$($parseError.Extent.StartLineNumber):$($parseError.Extent.StartColumnNumber) $($parseError.Message)")
    }
}

Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File |
Where-Object { $_.Extension -eq '.xaml' } |
ForEach-Object {
    $xamlFile = $_
    try {
        $settings = [System.Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [System.Xml.XmlReader]::Create($xamlFile.FullName, $settings)
        try {
            $document = [System.Xml.XmlDocument]::new()
            $document.XmlResolver = $null
            $document.Load($reader)
        }
        finally {
            $reader.Close()
        }
    }
    catch {
        $errorsFound.Add("XML parse error: $($xamlFile.FullName): $($_.Exception.Message)")
    }
}

$requiredFiles = @(
    'XamlDesigner\Start-XamlDesigner.ps1',
    'XamlDesigner\XamlDesigner.xaml',
    'XamlDesigner\XamlDesigner.Core.psm1',
    'XamlDesigner\Templates\BlankWindow.xaml',
    'XamlDesigner\Templates\BlankWindow.ps1',
    'XamlDesigner\GETTING_STARTED.ja.md',
    'XamlDesigner\REVIEW_50_PERSONAS.md',
    'Tests\Test-DesignerCore.ps1'
)
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath))) {
        $errorsFound.Add("Required designer file is missing: $relativePath")
    }
}

$standaloneSamples = @(
    'WPF_CustomGraphicalInputBoxSample.ps1',
    'WPF_GraphicalDatePickerSample.ps1',
    'WPF_SimpleWeatherFormSample\WPF_SimpleWeatherFormSample.ps1'
)
foreach ($relativePath in $standaloneSamples) {
    $samplePath = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $samplePath)) {
        $errorsFound.Add("Required standalone sample is missing: $relativePath")
        continue
    }

    $sampleCode = [System.IO.File]::ReadAllText($samplePath)
    if (-not $sampleCode.Contains('$PSScriptRoot')) {
        $errorsFound.Add("Standalone sample must resolve assets from PSScriptRoot: $relativePath")
    }
    if ($sampleCode -match 'Get-Content\s+\.\\') {
        $errorsFound.Add("Standalone sample still reads XAML from the current directory: $relativePath")
    }
    if ($sampleCode -match '(?i)\.add_[a-z]+\.Invoke\(') {
        $errorsFound.Add("Standalone sample uses indirect event registration: $relativePath")
    }
}

$templateCodePath = Join-Path $repositoryRoot 'XamlDesigner\Templates\BlankWindow.ps1'
if (Test-Path -LiteralPath $templateCodePath) {
    $templateCode = [System.IO.File]::ReadAllText($templateCodePath)
    foreach ($marker in @(
        '# <XamlDesigner:XamlFile>',
        '# </XamlDesigner:XamlFile>',
        '# <XamlDesigner:ControlReferences>',
        '# </XamlDesigner:ControlReferences>',
        '# <XamlDesigner:Events>',
        '# </XamlDesigner:Events>'
    )) {
        if (-not $templateCode.Contains($marker)) {
            $errorsFound.Add("Generated-code marker is missing from BlankWindow.ps1: $marker")
        }
    }
}


$workflowPath = Join-Path $repositoryRoot '.github\workflows\powershell-xaml-designer.yml'
if (Test-Path -LiteralPath $workflowPath) {
    $workflowText = [System.IO.File]::ReadAllText($workflowPath)
    if ($workflowText -match '(?i)ExecutionPolicy\s+Bypass') {
        $errorsFound.Add('CI must not normalize ExecutionPolicy Bypass for this enterprise-oriented tool.')
    }
    foreach ($requiredCommand in @(
        'Test-DesignerCore.ps1',
        'Test-CodeGeneration.ps1',
        'Test-DesignerStartup.ps1',
        'powershell.exe',
        'pwsh.exe'
    )) {
        if (-not $workflowText.Contains($requiredCommand)) {
            $errorsFound.Add("CI workflow is missing expected coverage: $requiredCommand")
        }
    }
}

$designerUiPath = Join-Path $repositoryRoot 'XamlDesigner\XamlDesigner.xaml'
if (Test-Path -LiteralPath $designerUiPath) {
    $designerUiText = [System.IO.File]::ReadAllText($designerUiPath)
    foreach ($requiredName in @(
        'MenuGettingStarted',
        'ButtonAddToolbox',
        'ToolboxHelpText',
        'PropertyHelpText'
    )) {
        if (-not $designerUiText.Contains('x:Name="' + $requiredName + '"')) {
            $errorsFound.Add("Beginner/accessibility UI control is missing: $requiredName")
        }
    }
}

if ($errorsFound.Count -gt 0) {
    $errorsFound | ForEach-Object { Write-Error $_ }
    throw "$($errorsFound.Count) repository validation error(s) found."
}

Write-Host 'PowerShell/XAML syntax, standalone samples, required files, generated markers, beginner UI, and CI policy checks passed.'
