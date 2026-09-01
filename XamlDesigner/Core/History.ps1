function Reset-XamlHistory {
    $script:State.UndoStack.Clear()
    $script:State.RedoStack.Clear()
}

function Push-XamlUndoSnapshot {
    param(
        [string]$Text
    )

    if ($script:State.IsRestoringHistory -or $null -eq $script:State.XamlDocument) {
        return
    }

    if ([string]::IsNullOrEmpty($Text)) {
        $Text = ConvertTo-FormattedXml -Document $script:State.XamlDocument
    }

    if ($script:State.UndoStack.Count -gt 0 -and $script:State.UndoStack.Peek() -ceq $Text) {
        return
    }

    $script:State.UndoStack.Push($Text)
    $script:State.RedoStack.Clear()
}

function Restore-XamlHistorySnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $script:State.IsRestoringHistory = $true
    try {
        $script:State.XamlDocument = New-XmlDocumentFromText -Text $Text
        $script:State.SelectedElementName = $null
        $script:State.SelectedRuntimeElement = $null
        Refresh-XamlTextFromDocument
        Sync-CodeEditor
        [void](Refresh-Preview)
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

    $current = ConvertTo-FormattedXml -Document $script:State.XamlDocument
    $script:State.RedoStack.Push($current)
    $previous = $script:State.UndoStack.Pop()
    Restore-XamlHistorySnapshot -Text $previous
    Set-DesignerStatus -Message 'Undo completed.'
}

function Redo-XamlDesignerChange {
    if ($script:State.RedoStack.Count -eq 0) {
        Set-DesignerStatus -Message 'Nothing to redo.'
        return
    }

    $current = ConvertTo-FormattedXml -Document $script:State.XamlDocument
    $script:State.UndoStack.Push($current)
    $next = $script:State.RedoStack.Pop()
    Restore-XamlHistorySnapshot -Text $next
    Set-DesignerStatus -Message 'Redo completed.'
}
