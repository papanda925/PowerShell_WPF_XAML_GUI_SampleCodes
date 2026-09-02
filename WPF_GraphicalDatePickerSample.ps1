[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework

$xamlPath = Join-Path $PSScriptRoot 'WPF_GraphicalDatePickerSample.xaml'
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

[System.Windows.Controls.Button]$okButton = $mainWindow.FindName('OKButton')
[System.Windows.Controls.Button]$cancelButton = $mainWindow.FindName('CancelButton')
[System.Windows.Controls.Label]$label = $mainWindow.FindName('Label')
[System.Windows.Controls.Calendar]$calendar = $mainWindow.FindName('Calendar')

$calendar.SelectedDate = [datetime]::Today
$label.Content = ([datetime]$calendar.SelectedDate).ToString("'Selected:' yyyy/MM/dd")
$calendar.Add_SelectedDatesChanged({
    if ($null -ne $calendar.SelectedDate) {
        $label.Content = ([datetime]$calendar.SelectedDate).ToString("'Selected:' yyyy/MM/dd")
    }
})

$okButton.Add_Click({
    $mainWindow.DialogResult = $true
})
$cancelButton.Add_Click({
    $mainWindow.DialogResult = $false
})

$result = $mainWindow.ShowDialog()
if (($result -eq $true) -and ($null -ne $calendar.SelectedDate)) {
    [datetime]$calendar.SelectedDate
}
