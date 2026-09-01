[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    Write-Host 'Designer core behavior test skipped: WPF requires Windows.'
    return
}

Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$designerDirectory = Join-Path $repositoryRoot 'XamlDesigner'
$coreDirectory = Join-Path $designerDirectory 'Core'

foreach ($part in @(
    'State.ps1',
    'Xml.ps1',
    'CodeBehind.ps1',
    'Documents.ps1',
    'History.ps1',
    'ToolboxCatalog.ps1',
    'ToolboxEditing.ps1',
    'Events.ps1'
)) {
    . (Join-Path $coreDirectory $part)
}

$script:State.BaseDirectory = $designerDirectory
$script:State.ToolboxItems = @(Get-WpfControlCatalog)

$safeDocument = New-XmlDocumentFromText -Text @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:local="clr-namespace:Unused"
        x:Name="MainWindow">
    <Grid/>
</Window>
'@
if (-not (Test-XamlPreviewSafety -Document $safeDocument)) {
    throw 'Safe standard XAML was unexpectedly rejected.'
}

$dangerousDocument = New-XmlDocumentFromText -Text @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <Window.Resources>
        <ObjectDataProvider x:Key="Danger"/>
    </Window.Resources>
    <Grid/>
</Window>
'@
$blocked = $false
try {
    [void](Test-XamlPreviewSafety -Document $dangerousDocument)
}
catch {
    $blocked = $true
}
if (-not $blocked) {
    throw 'ObjectDataProvider was not blocked by safe preview.'
}

$customDocument = New-XmlDocumentFromText -Text @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:local="clr-namespace:Unknown">
    <local:UnknownControl/>
</Window>
'@
$blocked = $false
try {
    [void](Test-XamlPreviewSafety -Document $customDocument)
}
catch {
    $blocked = $true
}
if (-not $blocked) {
    throw 'Custom CLR element was not blocked by safe preview.'
}

$script:State.XamlDocument = New-XmlDocumentFromText -Text @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="MainWindow">
    <Canvas x:Name="DesignCanvas">
        <Canvas.Resources>
            <DataTemplate x:Key="Template1">
                <TextBox x:Name="TemplateTextBox"/>
            </DataTemplate>
        </Canvas.Resources>
        <Button x:Name="Button1"/>
    </Canvas>
</Window>
'@
$named = @(Get-AllNamedXamlElements | ForEach-Object Name)
if ($named -notcontains 'Button1' -or $named -notcontains 'DesignCanvas') {
    throw 'Normal Window namescope controls were not discovered.'
}
if ($named -contains 'TemplateTextBox') {
    throw 'Template NameScope control was incorrectly treated as a Window.FindName control.'
}

$script:State.XamlDocument = New-XmlDocumentFromText -Text @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="MainWindow">
    <Canvas x:Name="DesignCanvas">
        <GroupBox x:Name="Group1">
            <StackPanel x:Name="Stack1">
                <TextBox x:Name="Input1"/>
                <TextBlock x:Name="Output1" Text="{Binding ElementName=Input1, Path=Text}"/>
            </StackPanel>
        </GroupBox>
    </Canvas>
</Window>
'@
$source = Get-XamlElementByName -Name 'Group1'
$newRootName = Copy-XamlElementNode -Source $source
if ([string]::IsNullOrWhiteSpace($newRootName)) {
    throw 'Subtree duplication did not return a new root name.'
}
$normalNames = @(Get-AllNamedXamlElements | ForEach-Object Name)
if (($normalNames | Select-Object -Unique).Count -ne $normalNames.Count) {
    throw 'Subtree duplication created duplicate x:Name values.'
}
$copyNode = Get-XamlElementByName -Name $newRootName
$boundText = @($copyNode.SelectNodes('.//*') | Where-Object {
    $_ -is [System.Xml.XmlElement] -and $_.HasAttribute('Text') -and $_.GetAttribute('Text') -like '*ElementName=*'
} | Select-Object -First 1)
if ($boundText.Count -ne 1 -or $boundText[0].GetAttribute('Text') -like '*ElementName=Input1,*') {
    throw 'ElementName binding inside the duplicated subtree was not updated.'
}

$sampleCode = @'
# <XamlDesigner:Events>
# <XamlDesigner:Event Control="Button1" Name="Click">
${Button1}.Add_Click({
    param($sender, $e)
})
# </XamlDesigner:Event>
# </XamlDesigner:Events>

Write-Host "user code"
'@
$archived = Archive-GeneratedEventsForControl -Code $sampleCode -ControlName 'Button1'
if ($archived -notmatch 'XamlDesigner:ArchivedEvent') {
    throw 'Deleted-control event block was not archived.'
}
if ($archived -match '(?m)^\\s*\\$\\{Button1\\}\\.Add_Click\\(') {
    throw 'Archived event handler is still executable.'
}
if ($archived -notmatch 'param\\(\\$sender, \\$e\\)') {
    throw 'Archived event handler body was not preserved as comments.'
}
if ($archived -notmatch 'Write-Host "user code"') {
    throw 'User code outside generated blocks was removed unexpectedly.'
}

$tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('PowerShellXamlDesignerTest_' + [Guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($tempDirectory)
try {
    $xamlPath = Join-Path $tempDirectory '日本語.xaml'
    $codePath = Join-Path $tempDirectory '日本語.ps1'
    $xamlText = '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="こんにちは"><Grid/></Window>'
    $codeText = 'Write-Output "こんにちは PowerShell"'

    Write-DesignerDocumentPair -XamlPath $xamlPath -XamlText $xamlText -CodePath $codePath -CodeText $codeText

    foreach ($path in @($xamlPath, $codePath)) {
        [byte[]]$bytes = [System.IO.File]::ReadAllBytes($path)
        if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
            throw "UTF-8 BOM was not written: $path"
        }
    }

    if ((Read-DesignerTextFile -Path $xamlPath) -cne $xamlText) {
        throw 'Japanese XAML did not round-trip exactly.'
    }
    if ((Read-DesignerTextFile -Path $codePath) -cne $codeText) {
        throw 'Japanese PowerShell did not round-trip exactly.'
    }
}
finally {
    Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
}

$script:State.Ui = @{
    CodeEditor = [pscustomobject]@{ Text = 'Write-Host old' }
}
$script:State.SelectedElementName = 'Button1'
$snapshot = New-DesignerHistorySnapshot -XamlText '<Window />' -CodeText 'Write-Host old' -SelectionName 'Button1'
if ($snapshot.CodeText -ne 'Write-Host old' -or $snapshot.SelectionName -ne 'Button1') {
    throw 'Designer history snapshot did not retain code/selection state.'
}

Write-Host 'Safe preview, NameScope, duplication, event archiving, encoding, and history behavior checks passed.'
