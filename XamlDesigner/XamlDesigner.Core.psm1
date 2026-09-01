Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$coreDirectory = Join-Path $PSScriptRoot 'Core'
foreach ($part in @(
    'State.ps1',
    'Xml.ps1',
    'Preview.ps1',
    'CodeBehind.ps1',
    'Documents.ps1',
    'ToolboxCatalog.ps1',
    'ToolboxEditing.ps1',
    'Properties.ps1',
    'Events.ps1',
    'Ui.ps1'
)) {
    . (Join-Path $coreDirectory $part)
}

function Initialize-XamlDesigner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window]$Window,

        [Parameter(Mandatory)]
        [string]$BaseDirectory
    )

    $script:State.Window = $Window
    $script:State.BaseDirectory = $BaseDirectory
    Initialize-UiReferences -Window $Window
    Register-UiEvents
    Refresh-ToolboxCatalog
    New-XamlDesignerDocument
}

Export-ModuleMember -Function Initialize-XamlDesigner
