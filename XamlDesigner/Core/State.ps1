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
    SavedXamlText = $null
    SavedCodeText = $null
    SelectedElementName = $null
    SelectedRuntimeElement = $null
    ToolboxItems = @()
    ToolboxDragOrigin = $null
    DesignerDragActive = $false
    DesignerDragOrigin = $null
    DesignerDragStartLeft = 0.0
    DesignerDragStartTop = 0.0
    DesignerDragCanvas = $null
    UndoStack = [System.Collections.Generic.Stack[string]]::new()
    RedoStack = [System.Collections.Generic.Stack[string]]::new()
    IsRestoringHistory = $false
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

function Set-DocumentSavedSnapshot {
    $script:State.SavedXamlText = $script:State.Ui.XamlEditor.Text
    $script:State.SavedCodeText = $script:State.Ui.CodeEditor.Text
    Update-DocumentCaption
}

function Test-DesignerDocumentDirty {
    if ($null -eq $script:State.XamlDocument) {
        return $false
    }

    return (
        $script:State.Ui.XamlEditor.Text -cne [string]$script:State.SavedXamlText -or
        $script:State.Ui.CodeEditor.Text -cne [string]$script:State.SavedCodeText
    )
}

function Confirm-ContinueWithUnsavedChanges {
    if (-not (Test-DesignerDocumentDirty)) {
        return $true
    }

    $result = [System.Windows.MessageBox]::Show(
        'The current XAML/PowerShell pair has unsaved changes. Save before continuing?',
        'Unsaved changes',
        [System.Windows.MessageBoxButton]::YesNoCancel,
        [System.Windows.MessageBoxImage]::Question
    )

    switch ($result) {
        ([System.Windows.MessageBoxResult]::Yes) {
            Save-XamlDesignerDocument
            return -not (Test-DesignerDocumentDirty)
        }
        ([System.Windows.MessageBoxResult]::No) {
            return $true
        }
        default {
            return $false
        }
    }
}
