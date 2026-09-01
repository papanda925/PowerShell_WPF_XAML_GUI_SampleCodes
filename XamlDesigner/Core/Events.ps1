function Remove-GeneratedEventsForControl {
    param(
        [Parameter(Mandatory)]
        [string]$Code,

        [Parameter(Mandatory)]
        [string]$ControlName
    )

    $pattern = '(?ms)^# <XamlDesigner:Event Control="' +
        [regex]::Escape($ControlName) +
        '" Name="[^"]+">\r?\n.*?^# </XamlDesigner:Event>\r?\n?'

    return [regex]::Replace($Code, $pattern, '')
}

function Generate-EventHandlerForName {
    param(
        [Parameter(Mandatory)]
        [string]$EventName
    )

    if (
        [string]::IsNullOrWhiteSpace($script:State.SelectedElementName) -or
        $script:State.SelectedRuntimeElement -isnot [System.Windows.FrameworkElement]
    ) {
        Set-DesignerStatus -Message 'Select a named control before generating an event handler.'
        return
    }

    $name = $script:State.SelectedElementName
    $availableEvents = @(
        $script:State.SelectedRuntimeElement.GetType().GetEvents(
            [System.Reflection.BindingFlags]'Public,Instance'
        ) | ForEach-Object Name
    )
    if ($availableEvents -notcontains $EventName) {
        Set-DesignerStatus -Message "Event '$EventName' is not available on $name."
        return
    }

    Sync-CodeEditor
    $code = $script:State.Ui.CodeEditor.Text

    $marker = '# <XamlDesigner:Event Control="' + $name + '" Name="' + $EventName + '">'
    $legacyPattern = [regex]::Escape('$' + $name + '.Add_' + $EventName + '(')
    $variableReference = '$' + '{' + $name + '}'
    $bracedPattern = [regex]::Escape($variableReference + '.Add_' + $EventName + '(')

    if (
        $code.Contains($marker) -or
        [regex]::IsMatch($code, $legacyPattern) -or
        [regex]::IsMatch($code, $bracedPattern)
    ) {
        Set-DesignerStatus -Message "An $EventName handler for $name already exists."
        $script:State.Ui.MainTabs.SelectedIndex = 2
        return
    }

    $eventsEnd = '# </XamlDesigner:Events>'
    if (-not $code.Contains($eventsEnd)) {
        Set-DesignerStatus -Message 'The generated event region is missing from the PowerShell code-behind.'
        return
    }

    Push-XamlUndoSnapshot

    $nl = [Environment]::NewLine
    $block = $marker + $nl +
        $variableReference + ".Add_$EventName({" + $nl +
        '    param($sender, $e)' + $nl + $nl +
        "    # TODO: Add $EventName logic for $name here." + $nl +
        '})' + $nl +
        '# </XamlDesigner:Event>' + $nl

    $script:State.Ui.CodeEditor.Text = $code.Replace($eventsEnd, $block + $eventsEnd)
    $script:State.Ui.MainTabs.SelectedIndex = 2
    Set-DesignerStatus -Message "Generated $name.$EventName before ShowDialog. Add your logic inside the new block."
}

function Generate-SelectedEventHandler {
    $selectedEvent = $script:State.Ui.EventGrid.SelectedItem
    if ($null -eq $selectedEvent) {
        Set-DesignerStatus -Message 'Select an event first.'
        return
    }

    Generate-EventHandlerForName -EventName ([string]$selectedEvent.Name)
}

function Get-DefaultDesignerEventName {
    param(
        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement]$Element
    )

    $eventNames = @(
        $Element.GetType().GetEvents([System.Reflection.BindingFlags]'Public,Instance') |
        ForEach-Object Name
    )

    foreach ($candidate in @(
        'Click',
        'Checked',
        'SelectionChanged',
        'TextChanged',
        'ValueChanged',
        'SelectedDateChanged',
        'MouseDoubleClick',
        'Loaded'
    )) {
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

    $node.SetAttribute(
        'Canvas.Left',
        $Left.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    )
    $node.SetAttribute(
        'Canvas.Top',
        $Top.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    )
    Refresh-XamlTextFromDocument
}
