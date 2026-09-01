[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    Write-Host 'Code-generation test skipped: WPF requires Windows.'
    return
}

Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$designerDirectory = Join-Path $repositoryRoot 'XamlDesigner'
$coreDirectory = Join-Path $designerDirectory 'Core'

. (Join-Path $coreDirectory 'State.ps1')
. (Join-Path $coreDirectory 'Xml.ps1')
. (Join-Path $coreDirectory 'CodeBehind.ps1')
. (Join-Path $coreDirectory 'History.ps1')
. (Join-Path $coreDirectory 'Events.ps1')

$script:State.BaseDirectory = $designerDirectory
$script:State.ToolboxItems = @()
$script:State.XamlDocument = New-XmlDocumentFromText -Text @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="MainWindow">
    <Canvas x:Name="DesignCanvas">
        <Button x:Name="Button1" Content="Test"/>
    </Canvas>
</Window>
'@

$referenceLines = @(Get-ControlReferenceLines)
$expectedReference = '[System.Windows.Controls.Button]${Button1} = $Window.FindName(''Button1'')'
if ($referenceLines -notcontains $expectedReference) {
    throw "Expected generated control reference was not found. Actual: $($referenceLines -join '; ')"
}

$code = [System.IO.File]::ReadAllText((Join-Path $designerDirectory 'Templates\BlankWindow.ps1'))
$script:State.Ui = @{
    CodeEditor = [pscustomobject]@{ Text = $code }
    MainTabs = [pscustomobject]@{ SelectedIndex = 0 }
    StatusText = [pscustomobject]@{ Text = '' }
}
$script:State.CurrentXamlPath = 'C:\Temp\GeneratedWindow.xaml'
$script:State.SelectedElementName = 'Button1'
$script:State.SelectedRuntimeElement = [System.Windows.Controls.Button]::new()
$script:State.SelectedRuntimeElement.Name = 'Button1'

Sync-CodeEditor
Generate-EventHandlerForName -EventName 'Click'
$generated = $script:State.Ui.CodeEditor.Text

$eventMarker = '# <XamlDesigner:Event Control="Button1" Name="Click">'
if (-not $generated.Contains($eventMarker)) {
    throw 'Generated Click event marker was not found.'
}

$handlerIndex = $generated.IndexOf('${Button1}.Add_Click(', [System.StringComparison]::Ordinal)
$showDialogIndex = $generated.IndexOf('$null = $Window.ShowDialog()', [System.StringComparison]::Ordinal)
if ($handlerIndex -lt 0 -or $showDialogIndex -lt 0 -or $handlerIndex -gt $showDialogIndex) {
    throw 'Generated event handler must be registered before $Window.ShowDialog().'
}

$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseInput(
    $generated,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    $messages = $parseErrors | ForEach-Object {
        "line $($_.Extent.StartLineNumber): $($_.Message)"
    }
    throw "Generated PowerShell does not parse: $($messages -join '; ')"
}

Write-Host 'Generated control references and event registration order are valid.'
