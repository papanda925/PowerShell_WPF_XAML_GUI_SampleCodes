[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 参考: https://learn.microsoft.com/windows/apps/design/layout/grid-tutorial
Add-Type -AssemblyName PresentationFramework

$xamlPath = Join-Path $PSScriptRoot 'WPF_SimpleWeatherFormSample.xaml'
$imagePath = Join-Path $PSScriptRoot 'partially-cloudy.png'
[xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw

$xamlRoot = $xaml.DocumentElement
[void]$xamlRoot.RemoveAttribute('Class', 'http://schemas.microsoft.com/winfx/2006/xaml')
[void]$xamlRoot.RemoveAttribute('Ignorable', 'http://schemas.openxmlformats.org/markup-compatibility/2006')

$xamlReader = [System.Xml.XmlNodeReader]::new($xaml)
try {
    [System.Windows.Window]$mainWindow = [System.Windows.Markup.XamlReader]::Load($xamlReader)
}
finally {
    $xamlReader.Close()
}

[System.Windows.Controls.Image]$image = $mainWindow.FindName('imageData')
$image.Source = $imagePath

[void]$mainWindow.ShowDialog()

