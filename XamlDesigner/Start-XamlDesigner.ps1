[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'PowerShell XAML Designer requires Windows because it is implemented with WPF.'
}

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    if ($env:POWERSHELL_XAML_DESIGNER_STA_RELAUNCH -eq '1') {
        throw 'The designer could not start an STA PowerShell process. Start powershell.exe or pwsh.exe with -STA manually.'
    }

    $enginePath = (Get-Process -Id $PID).Path
    if ([string]::IsNullOrWhiteSpace($enginePath)) {
        throw 'WPF requires an STA thread, and the current PowerShell executable could not be identified.'
    }

    $env:POWERSHELL_XAML_DESIGNER_STA_RELAUNCH = '1'
    $quotedScriptPath = '"' + $PSCommandPath + '"'
    Start-Process -FilePath $enginePath -ArgumentList @(
        '-NoProfile',
        '-STA',
        '-File',
        $quotedScriptPath
    )
    return
}

try {
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName PresentationFramework

    $modulePath = Join-Path $PSScriptRoot 'XamlDesigner.Core.psm1'
    Import-Module -Name $modulePath -Force

    $designerXamlPath = Join-Path $PSScriptRoot 'XamlDesigner.xaml'
    [xml]$designerXaml = [System.IO.File]::ReadAllText($designerXamlPath)
    $reader = [System.Xml.XmlNodeReader]::new($designerXaml)
    try {
        [System.Windows.Window]$designerWindow = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    Initialize-XamlDesigner -Window $designerWindow -BaseDirectory $PSScriptRoot
    $null = $designerWindow.ShowDialog()
}
catch {
    try {
        [System.Windows.MessageBox]::Show(
            'PowerShell XAML Designer could not start.' +
            [Environment]::NewLine + [Environment]::NewLine +
            $_.Exception.Message,
            'PowerShell XAML Designer',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    catch {
        Write-Error $_.Exception.Message
    }
    throw
}
