Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:XamlNs = 'http://schemas.microsoft.com/winfx/2006/xaml'
$script:PresentationNs = 'http://schemas.microsoft.com/winfx/2006/xaml/presentation'
$script:McNs = 'http://schemas.openxmlformats.org/markup-compatibility/2006'
$script:DesignNs = 'http://schemas.microsoft.com/expression/blend/2008'

$script:State = [ordered]@{
    Window = $null
    BaseDirectory = $null
    Ui = @{}
    XamlDocument = $null
    CurrentXamlPath = $null
    CurrentCodePath = $null
    SelectedElementName = $null
    SelectedRuntimeElement = $null
    ToolboxItems = @()
    ToolboxDragOrigin = $null
    DesignerDragActive = $false
    DesignerDragOrigin = $null
    DesignerDragStartLeft = 0.0
    DesignerDragStartTop = 0.0
    DesignerDragCanvas = $null
}

function Set-DesignerStatus {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($null -ne $script:State.Ui.StatusText) {
        $script:State.Ui.StatusText.Text = $Message
    }
}

function Get-UiControl {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window]$Window,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $control = $Window.FindName($Name)
    if ($null -eq $control) {
        throw "Required UI control '$Name' was not found in XamlDesigner.xaml."
    }
    return $control
}
