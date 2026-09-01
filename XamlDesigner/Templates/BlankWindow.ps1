Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

function ConvertTo-PowerShellRuntimeXaml {
    <#
    .SYNOPSIS
        Creates a runtime-safe clone of a WPF XAML document.

    .DESCRIPTION
        Visual Studio / Blend XAML can contain build-time attributes such as
        x:Class, d:* design data, and event attributes such as Click="...".
        A standalone PowerShell XamlReader has no compiled code-behind class,
        so those attributes are removed only from the in-memory runtime clone.
        The saved .xaml file itself remains the UI definition.
    #>
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Document
    )

    $xamlNamespace = 'http://schemas.microsoft.com/winfx/2006/xaml'
    $mcNamespace = 'http://schemas.openxmlformats.org/markup-compatibility/2006'
    $designNamespace = 'http://schemas.microsoft.com/expression/blend/2008'

    [System.Xml.XmlDocument]$runtimeDocument = $Document.CloneNode($true)
    [System.Xml.XmlElement]$root = $runtimeDocument.DocumentElement
    if ($null -eq $root) {
        return $runtimeDocument
    }

    $root.RemoveAttribute('Class', $xamlNamespace)
    $root.RemoveAttribute('Ignorable', $mcNamespace)

    $typeNamespaces = @(
        'System.Windows.Controls',
        'System.Windows.Shapes',
        'System.Windows.Documents'
    )

    foreach ($node in $runtimeDocument.SelectNodes('//*')) {
        if ($node -isnot [System.Xml.XmlElement]) {
            continue
        }

        foreach ($attribute in @($node.Attributes | ForEach-Object { $_ })) {
            if ($attribute.NamespaceURI -eq $designNamespace) {
                [void]$node.Attributes.Remove($attribute)
            }
        }

        [Type]$wpfType = $null
        if ($node.LocalName -eq 'Window') {
            $wpfType = [System.Windows.Window]
        }
        else {
            foreach ($namespace in $typeNamespaces) {
                $candidate = [Type]::GetType("$namespace.$($node.LocalName), PresentationFramework", $false)
                if ($null -ne $candidate) {
                    $wpfType = $candidate
                    break
                }
            }
        }

        if ($null -eq $wpfType) {
            continue
        }

        $eventNames = @($wpfType.GetEvents([System.Reflection.BindingFlags]'Public,Instance') | ForEach-Object Name)
        foreach ($attribute in @($node.Attributes | ForEach-Object { $_ })) {
            if ([string]::IsNullOrWhiteSpace($attribute.NamespaceURI) -and $eventNames -contains $attribute.LocalName) {
                [void]$node.Attributes.Remove($attribute)
            }
        }
    }

    return $runtimeDocument
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

# <XamlDesigner:XamlFile>
$xamlFileName = 'Untitled.xaml'
# </XamlDesigner:XamlFile>

$xamlPath = Join-Path $scriptDirectory $xamlFileName
$xmlSettings = [System.Xml.XmlReaderSettings]::new()
$xmlSettings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
$xmlSettings.XmlResolver = $null
$sourceReader = [System.Xml.XmlReader]::Create($xamlPath, $xmlSettings)
try {
    [System.Xml.XmlDocument]$sourceXamlDocument = [System.Xml.XmlDocument]::new()
    $sourceXamlDocument.XmlResolver = $null
    $sourceXamlDocument.Load($sourceReader)
}
finally {
    $sourceReader.Close()
}
[System.Xml.XmlDocument]$runtimeXamlDocument = ConvertTo-PowerShellRuntimeXaml -Document $sourceXamlDocument

$reader = [System.Xml.XmlNodeReader]::new($runtimeXamlDocument)
try {
    [System.Windows.Window]$Window = [System.Windows.Markup.XamlReader]::Load($reader)
}
finally {
    $reader.Close()
}

# <XamlDesigner:ControlReferences>
# Named controls are inserted here by PowerShell XAML Designer.
# </XamlDesigner:ControlReferences>

# Add your event handlers below this line.

$null = $Window.ShowDialog()
