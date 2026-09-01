[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'PowerShell XAML Designer requires Windows because it is implemented with WPF.'
}

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    throw 'WPF requires an STA thread. Start with powershell.exe -STA or pwsh.exe -STA and run Start-XamlDesigner.ps1 again.'
}

Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

$modulePath = Join-Path $PSScriptRoot 'XamlDesigner.Core.psm1'
Import-Module -Name $modulePath -Force

$designerXamlPath = Join-Path $PSScriptRoot 'XamlDesigner.xaml'
[xml]$designerXaml = Get-Content -LiteralPath $designerXamlPath -Raw
$reader = [System.Xml.XmlNodeReader]::new($designerXaml)
try {
    [System.Windows.Window]$designerWindow = [System.Windows.Markup.XamlReader]::Load($reader)
}
finally {
    $reader.Close()
}

Initialize-XamlDesigner -Window $designerWindow -BaseDirectory $PSScriptRoot
$null = $designerWindow.ShowDialog()
