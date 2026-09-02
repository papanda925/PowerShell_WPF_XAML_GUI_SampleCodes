[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework

# 呼び出し元のカレントディレクトリに依存せず、スクリプトと同じ場所の XAML を読む。
$xamlPath = Join-Path $PSScriptRoot 'WPF_CustomGraphicalInputBoxSample.xaml'
[xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw

# Visual Studio が追加する、単体の XamlReader では不要な属性を取り除く。
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

[System.Windows.Controls.Button]$okButton = $mainWindow.FindName('OkButton')
[System.Windows.Controls.Button]$cancelButton = $mainWindow.FindName('CancelButton')
[System.Windows.Controls.TextBox]$textBox = $mainWindow.FindName('TextBox')

$okButton.Add_Click({
    $mainWindow.DialogResult = $true
})
$cancelButton.Add_Click({
    $mainWindow.DialogResult = $false
})

$result = $mainWindow.ShowDialog()
if ($result -eq $true) {
    $textBox.Text
}
