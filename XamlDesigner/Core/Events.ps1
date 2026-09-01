function Generate-EventHandlerForName {
    param(
        [Parameter(Mandatory)]
        [string]$EventName
    )

    if ([string]::IsNullOrWhiteSpace($script:State.SelectedElementName)) {
        return
    }

    $name = $script:State.SelectedElementName
    $availableEvents = @($script:State.SelectedRuntimeElement.GetType().GetEvents([System.Reflection.BindingFlags]'Public,Instance') | ForEach-Object Name)
    if ($availableEvents -notcontains $EventName) {
        Set-DesignerStatus -Message "Event '$EventName' is not available on $name."
        return
    }

    Sync-CodeEditor
    $code = $script:State.Ui.CodeEditor.Text

    $pattern = [regex]::Escape("`$$name.Add_$EventName(")
    if ([regex]::IsMatch($code, $pattern)) {
        Set-DesignerStatus -Message "An $EventName handler for $name already exists."
        $script:State.Ui.MainTabs.SelectedIndex = 2
        return
    }

    $block = @"

# $name.$EventName
`$$name.Add_$EventName({
    param(`$sender, `$e)

    # TODO: Add $EventName logic for $name.
})
"@
    $script:State.Ui.CodeEditor.Text = $code.TrimEnd() + $block + "`r`n"
    $script:State.Ui.MainTabs.SelectedIndex = 2
    Set-DesignerStatus -Message "Generated PowerShell event handler: $name.$EventName"
}

function Generate-SelectedEventHandler {
    $selectedEvent = $script:State.Ui.EventGrid.SelectedItem
    if ($null -eq $selectedEvent) {
        return
    }
    Generate-EventHandlerForName -EventName ([string]$selectedEvent.Name)
}

function Get-DefaultDesignerEventName {
    param(
        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement]$Element
    )

    $eventNames = @($Element.GetType().GetEvents([System.Reflection.BindingFlags]'Public,Instance') | ForEach-Object Name)
    foreach ($candidate in @('Click','Checked','SelectionChanged','TextChanged','ValueChanged','SelectedDateChanged','MouseDoubleClick','Loaded')) {
        if ($eventNames -contains $candidate) {
            return $candidate
        }
    }
    return $null
}

function Update-SelectedCanvasPosition {
    param(
        [Parameter(Mandatory)]
        [double]$Left,

        [Parameter(Mandatory)]
        [double]$Top
    )

    if ([string]::IsNullOrWhiteSpace($script:State.SelectedElementName)) {
        return
    }
    $node = Get-XamlElementByName -Name $script:State.SelectedElementName
    if ($null -eq $node) {
        return
    }
    $node.SetAttribute('Canvas.Left', $Left.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    $node.SetAttribute('Canvas.Top', $Top.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    Refresh-XamlTextFromDocument
}
