function Reset-XamlHistory {
    $script:State.UndoStack.Clear()
    $script:State.RedoStack.Clear()
}

function New-DesignerHistorySnapshot {
    param(
        [string]$XamlText,
        [string]$CodeText,
        [string]$SelectionName
    )

    if ([string]::IsNullOrEmpty($XamlText) -and $null -ne $script:State.XamlDocument) {
        $XamlText = ConvertTo-FormattedXml -Document $script:State.XamlDocument
    }
    if ($null -eq $CodeText -and $null -ne $script:State.Ui.CodeEditor) {
        $CodeText = $script:State.Ui.CodeEditor.Text
    }
    if ($null -eq $SelectionName) {
        $SelectionName = $script:State.SelectedElementName
    }

    return [pscustomobject]@{
        XamlText = [string]$XamlText
        CodeText = [string]$CodeText
        SelectionName = [string]$SelectionName
    }
}

function Test-DesignerHistorySnapshotsEqual {
    param(
        [Parameter(Mandatory)]
        [object]$Left,

        [Parameter(Mandatory)]
        [object]$Right
    )

    return (
        [string]$Left.XamlText -ceq [string]$Right.XamlText -and
        [string]$Left.CodeText -ceq [string]$Right.CodeText -and
        [string]$Left.SelectionName -ceq [string]$Right.SelectionName
    )
}

function Push-XamlUndoSnapshot {
    param(
        [string]$Text,
        [string]$CodeText,
        [string]$SelectionName
    )

    if ($script:State.IsRestoringHistory -or $null -eq $script:State.XamlDocument) {
        return
    }

    $snapshot = New-DesignerHistorySnapshot -XamlText $Text -CodeText $CodeText -SelectionName $SelectionName
    if (
        $script:State.UndoStack.Count -gt 0 -and
        (Test-DesignerHistorySnapshotsEqual -Left $script:State.UndoStack.Peek() -Right $snapshot)
    ) {
        return
    }

    $script:State.UndoStack.Push($snapshot)
    $script:State.RedoStack.Clear()
}

function Restore-XamlHistorySnapshot {
    param(
        [Parameter(Mandatory)]
        [object]$Snapshot
    )

    $script:State.IsRestoringHistory = $true
    try {
        $script:State.XamlDocument = New-XmlDocumentFromText -Text ([string]$Snapshot.XamlText)
        $script:State.Ui.CodeEditor.Text = [string]$Snapshot.CodeText
        $script:State.SelectedElementName = [string]$Snapshot.SelectionName
        $script:State.SelectedRuntimeElement = $null
        Refresh-XamlTextFromDocument
        [void](Refresh-Preview -KeepSelection)
        Update-DocumentCaption
    }
    finally {
        $script:State.IsRestoringHistory = $false
    }
}

function Undo-XamlDesignerChange {
    if ($script:State.UndoStack.Count -eq 0) {
        Set-DesignerStatus -Message 'Nothing to undo.'
        return
    }

    $current = New-DesignerHistorySnapshot
    $script:State.RedoStack.Push($current)
    $previous = $script:State.UndoStack.Pop()
    Restore-XamlHistorySnapshot -Snapshot $previous
    Set-DesignerStatus -Message 'Undo completed for XAML and generated PowerShell changes.'
}

function Redo-XamlDesignerChange {
    if ($script:State.RedoStack.Count -eq 0) {
        Set-DesignerStatus -Message 'Nothing to redo.'
        return
    }

    $current = New-DesignerHistorySnapshot
    $script:State.UndoStack.Push($current)
    $next = $script:State.RedoStack.Pop()
    Restore-XamlHistorySnapshot -Snapshot $next
    Set-DesignerStatus -Message 'Redo completed for XAML and generated PowerShell changes.'
}
