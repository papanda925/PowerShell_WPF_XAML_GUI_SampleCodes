function New-XamlDesignerDocument {
    if (-not (Confirm-ContinueWithUnsavedChanges)) {
        return
    }

    $script:State.XamlDocument = New-XmlDocumentFromText -Text (Get-BlankXamlText)
    $script:State.CurrentXamlPath = $null
    $script:State.CurrentCodePath = $null
    $script:State.SelectedElementName = $null
    $script:State.SelectedRuntimeElement = $null
    Reset-XamlHistory
    $script:State.Ui.CodeEditor.Text = Get-BlankCodeText
    Refresh-XamlTextFromDocument
    [void](Refresh-Preview)
    Update-DocumentCaption
    Set-DocumentSavedSnapshot
    Set-DesignerStatus -Message 'Created a new XAML + PowerShell document pair.'
}

function Open-XamlDesignerDocument {
    if (-not (Confirm-ContinueWithUnsavedChanges)) {
        return
    }

    $dialog = [Microsoft.Win32.OpenFileDialog]::new()
    $dialog.Filter = 'XAML files (*.xaml)|*.xaml|XML files (*.xml)|*.xml|All files (*.*)|*.*'
    $dialog.Title = 'Open XAML file'
    if ($dialog.ShowDialog() -ne $true) {
        return
    }

    try {
        $text = Get-Content -LiteralPath $dialog.FileName -Raw
        $document = New-XmlDocumentFromText -Text $text
        $oldDocument = $script:State.XamlDocument
        $script:State.XamlDocument = $document

        if (-not (Refresh-Preview)) {
            $script:State.XamlDocument = $oldDocument
            throw 'The selected file is well-formed XML but could not be loaded as a WPF Window.'
        }

        $script:State.CurrentXamlPath = $dialog.FileName
        $script:State.CurrentCodePath = [System.IO.Path]::ChangeExtension($dialog.FileName, '.ps1')
        Reset-XamlHistory
        Refresh-XamlTextFromDocument

        if (Test-Path -LiteralPath $script:State.CurrentCodePath) {
            $script:State.Ui.CodeEditor.Text = Get-Content -LiteralPath $script:State.CurrentCodePath -Raw
        }
        else {
            $script:State.Ui.CodeEditor.Text = Get-BlankCodeText
        }

        Sync-CodeEditor
        Update-DocumentCaption
        Set-DocumentSavedSnapshot
        Set-DesignerStatus -Message "Opened $($dialog.FileName)"
    }
    catch {
        [System.Windows.MessageBox]::Show(
            $_.Exception.Message,
            'Open failed',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
}

function Apply-XamlEditorText {
    try {
        $candidate = New-XmlDocumentFromText -Text $script:State.Ui.XamlEditor.Text
    }
    catch [System.Xml.XmlException] {
        $ex = $_.Exception
        Set-DesignerStatus -Message "XML error at line $($ex.LineNumber), position $($ex.LinePosition): $($ex.Message)"
        return $false
    }
    catch {
        Set-DesignerStatus -Message ("XML error: " + $_.Exception.Message)
        return $false
    }

    $old = $script:State.XamlDocument
    $oldText = if ($null -ne $old) { ConvertTo-FormattedXml -Document $old } else { $null }
    $candidateText = ConvertTo-FormattedXml -Document $candidate
    $recordHistory = (
        -not $script:State.IsRestoringHistory -and
        $null -ne $oldText -and
        $oldText -cne $candidateText
    )

    $script:State.XamlDocument = $candidate
    if (-not (Refresh-Preview -KeepSelection)) {
        $script:State.XamlDocument = $old
        return $false
    }

    if ($recordHistory) {
        Push-XamlUndoSnapshot -Text $oldText
    }

    Refresh-XamlTextFromDocument
    Sync-CodeEditor
    return $true
}

function Confirm-CodeBehindOverwrite {
    param(
        [Parameter(Mandatory)]
        [string]$CodePath
    )

    if (-not (Test-Path -LiteralPath $CodePath)) {
        return $true
    }

    if (
        -not [string]::IsNullOrWhiteSpace($script:State.CurrentCodePath) -and
        [string]::Equals(
            [System.IO.Path]::GetFullPath($CodePath),
            [System.IO.Path]::GetFullPath($script:State.CurrentCodePath),
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        return $true
    }

    $result = [System.Windows.MessageBox]::Show(
        "The paired PowerShell file already exists and will also be replaced:`r`n`r`n$CodePath`r`n`r`nContinue?",
        'Replace paired PowerShell file?',
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )

    return $result -eq [System.Windows.MessageBoxResult]::Yes
}

function Save-XamlDesignerDocument {
    param(
        [switch]$SaveAs
    )

    if (-not (Apply-XamlEditorText)) {
        [System.Windows.MessageBox]::Show(
            'The XAML contains an error. Fix the error before saving.',
            'Save blocked',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        ) | Out-Null
        return
    }

    if (-not (Test-CodeEditorPowerShell)) {
        [System.Windows.MessageBox]::Show(
            'The PowerShell code-behind contains a syntax error. Fix the error before saving.',
            'Save blocked',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        ) | Out-Null
        return
    }

    if ($SaveAs -or [string]::IsNullOrWhiteSpace($script:State.CurrentXamlPath)) {
        $dialog = [Microsoft.Win32.SaveFileDialog]::new()
        $dialog.Filter = 'XAML files (*.xaml)|*.xaml'
        $dialog.DefaultExt = '.xaml'
        $dialog.AddExtension = $true
        $dialog.OverwritePrompt = $true
        $dialog.Title = 'Save XAML and PowerShell code-behind'

        if ($dialog.ShowDialog() -ne $true) {
            return
        }

        $candidateXamlPath = $dialog.FileName
        $candidateCodePath = [System.IO.Path]::ChangeExtension($candidateXamlPath, '.ps1')
        if (-not (Confirm-CodeBehindOverwrite -CodePath $candidateCodePath)) {
            Set-DesignerStatus -Message 'Save As cancelled; paired PowerShell file was not overwritten.'
            return
        }

        $script:State.CurrentXamlPath = $candidateXamlPath
        $script:State.CurrentCodePath = $candidateCodePath
    }

    Sync-CodeEditor
    $xamlText = ConvertTo-FormattedXml -Document $script:State.XamlDocument
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    [System.IO.File]::WriteAllText($script:State.CurrentXamlPath, $xamlText, $utf8NoBom)
    [System.IO.File]::WriteAllText($script:State.CurrentCodePath, $script:State.Ui.CodeEditor.Text, $utf8NoBom)

    Update-DocumentCaption
    Set-DocumentSavedSnapshot
    Set-DesignerStatus -Message "Saved XAML and code-behind: $($script:State.CurrentXamlPath)"
}
