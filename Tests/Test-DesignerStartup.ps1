[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    Write-Host 'Designer startup smoke test skipped: WPF requires Windows.'
    return
}

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    throw 'Designer startup smoke test must run in an STA PowerShell process.'
}

Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$designerDirectory = Join-Path $repositoryRoot 'XamlDesigner'
Import-Module (Join-Path $designerDirectory 'XamlDesigner.Core.psm1') -Force

$designerXamlPath = Join-Path $designerDirectory 'XamlDesigner.xaml'
[xml]$designerXaml = Get-Content -LiteralPath $designerXamlPath -Raw
$reader = [System.Xml.XmlNodeReader]::new($designerXaml)
try {
    [System.Windows.Window]$window = [System.Windows.Markup.XamlReader]::Load($reader)
}
finally {
    $reader.Close()
}

Initialize-XamlDesigner -Window $window -BaseDirectory $designerDirectory

$requiredControls = @(
    'MenuNew','MenuOpen','MenuSave','MenuSaveAs','MenuExit',
    'MenuUndo','MenuRedo','MenuDelete','MenuDuplicate','MenuValidate','MenuRefreshToolbox','MenuAbout',
    'StatusText','DocumentText','ToolboxSearch','ToolboxCategory','ToolboxList','OutlineTree',
    'MainTabs','PreviewBorder','PreviewHost','CheckSnapToGrid',
    'ButtonDelete','ButtonDuplicate','ButtonApplyXaml','ButtonFormatXaml','ButtonValidateCode',
    'XamlEditor','CodeEditor','SelectedControlText','PropertyGrid',
    'PropertyNameText','PropertyValueText','ButtonApplyProperty','EventGrid'
)

foreach ($name in $requiredControls) {
    if ($null -eq $window.FindName($name)) {
        throw "Designer UI smoke test failed: '$name' was not found."
    }
}

if ($window.Title -notlike 'PowerShell XAML Designer*') {
    throw "Designer initialization did not set the expected window title: $($window.Title)"
}

$window.Close()
Write-Host 'PowerShell XAML Designer startup smoke test passed.'
