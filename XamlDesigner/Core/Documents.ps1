function Read-DesignerTextFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -eq 0) {
        return ''
    }

    $hasBom = (
        ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) -or
        ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or
        ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) -or
        ($bytes.Length -ge 4 -and $bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF)
    )

    if ($hasBom) {
        $reader = [System.IO.StreamReader]::new($Path, $true)
        try {
            return $reader.ReadToEnd()
        }
        finally {
            $reader.Close()
        }
    }

    try {
        $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
        return $strictUtf8.GetString($bytes)
    }
    catch [System.Text.DecoderFallbackException] {
        # Legacy Windows PowerShell files are sometimes saved in the current
        # ANSI code page. Fall back only when the file is not valid UTF-8.
        return [System.Text.Encoding]::Default.GetString($bytes)
    }
}

function Test-CodeBehindHasDesignerRegions {
    param(
        [Parameter(Mandatory)]
        [string]$Code
    )

    foreach ($marker in @(
        '# <XamlDesigner:XamlFile>',
        '# </XamlDesigner:XamlFile>',
        '# <XamlDesigner:ControlReferences>',
        '# </XamlDesigner:ControlReferences>',
        '# <XamlDesigner:Events>',
        '# </XamlDesigner:Events>'
    )) {
        if (-not $Code.Contains($marker)) {
            return $false
        }
    }

    return $true
}

function Write-DesignerDocumentPair {
    param(
        [Parameter(Mandatory)]
        [string]$XamlPath,

        [Parameter(Mandatory)]
        [string]$XamlText,

        [Parameter(Mandatory)]
        [string]$CodePath,

        [Parameter(Mandatory)]
        [string]$CodeText
    )

    $id = [Guid]::NewGuid().ToString('N')
    $xamlTemp = "$XamlPath.$id.tmp"
    $codeTemp = "$CodePath.$id.tmp"
    $xamlBackup = "$XamlPath.$id.bak"
    $codeBackup = "$CodePath.$id.bak"
    $xamlExisted = Test-Path -LiteralPath $XamlPath
    $codeExisted = Test-Path -LiteralPath $CodePath
    $utf8WithBom = [System.Text.UTF8Encoding]::new($true)

    try {
        # Write both complete temporary files before touching either target.
        [System.IO.File]::WriteAllText($xamlTemp, $XamlText, $utf8WithBom)
        [System.IO.File]::WriteAllText($codeTemp, $CodeText, $utf8WithBom)

        if ($xamlExisted) {
            [System.IO.File]::Copy($XamlPath, $xamlBackup, $true)
        }
        if ($codeExisted) {
            [System.IO.File]::Copy($CodePath, $codeBackup, $true)
        }

        try {
            [System.IO.File]::Copy($xamlTemp, $XamlPath, $true)
            [System.IO.File]::Copy($codeTemp, $CodePath, $true)
        }
        catch {
            if ($xamlExisted -and (Test-Path -LiteralPath $xamlBackup)) {
                [System.IO.File]::Copy($xamlBackup, $XamlPath, $true)
            }
            elseif (-not $xamlExisted -and (Test-Path -LiteralPath $XamlPath)) {
                [System.IO.File]::Delete($XamlPath)
            }

            if ($codeExisted -and (Test-Path -LiteralPath $codeBackup)) {
                [System.IO.File]::Copy($codeBackup, $CodePath, $true)
            }
            elseif (-not $codeExisted -and (Test-Path -LiteralPath $CodePath)) {
                [System.IO.File]::Delete($CodePath)
            }

            throw
        }
    }
    finally {
        foreach ($path in @($xamlTemp, $codeTemp, $xamlBackup, $codeBackup)) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

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
    Set-DesignerStatus -Message 'New document created. Start with a Common toolbox control; Button is a good first choice.'
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
        $text = Read-DesignerTextFile -Path $dialog.FileName
        $document = New-XmlDocumentFromText -Text $text
        $candidateCodePath = [System.IO.Path]::ChangeExtension($dialog.FileName, '.ps1')

        if (Test-Path -LiteralPath $candidateCodePath) {
            $codeText = Read-DesignerTextFile -Path $candidateCodePath
            if (-not (Test-CodeBehindHasDesignerRegions -Code $codeText)) {
                $nl = [Environment]::NewLine
                $answer = [System.Windows.MessageBox]::Show(
                    'A paired .ps1 file already exists, but it was not created/managed by PowerShell XAML Designer.' +
                    $nl + $nl +
                    'If you continue, generated marker regions will be added in the editor. The file on disk is not changed until you save.' +
                    $nl + $nl +
                    'Continue opening this pair?',
                    'Existing PowerShell file',
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Warning
                )
                if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
                    Set-DesignerStatus -Message 'Open cancelled. The existing PowerShell file was not modified.'
                    return
                }
            }
        }
        else {
            $codeText = Get-BlankCodeText
        }

        $oldDocument = $script:State.XamlDocument
        $script:State.XamlDocument = $document

        if (-not (Refresh-Preview)) {
            $script:State.XamlDocument = $oldDocument
            throw 'The selected file is XML, but it could not be loaded safely as a WPF Window. See the status bar for the preview reason.'
        }

        $script:State.CurrentXamlPath = $dialog.FileName
        $script:State.CurrentCodePath = $candidateCodePath
        Reset-XamlHistory
        Refresh-XamlTextFromDocument
        $script:State.Ui.CodeEditor.Text = $codeText
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
    $oldCode = $script:State.Ui.CodeEditor.Text
    $oldSelection = $script:State.SelectedElementName
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
        Push-XamlUndoSnapshot -Text $oldText -CodeText $oldCode -SelectionName $oldSelection
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

    $nl = [Environment]::NewLine
    $result = [System.Windows.MessageBox]::Show(
        'The paired PowerShell file already exists and will also be replaced:' +
        $nl + $nl + $CodePath + $nl + $nl + 'Continue?',
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
            'The XAML contains an error or was blocked by safe preview checks. Fix the issue before saving.',
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

    $targetXamlPath = $script:State.CurrentXamlPath
    $targetCodePath = $script:State.CurrentCodePath

    if ($SaveAs -or [string]::IsNullOrWhiteSpace($targetXamlPath)) {
        $dialog = [Microsoft.Win32.SaveFileDialog]::new()
        $dialog.Filter = 'XAML files (*.xaml)|*.xaml'
        $dialog.DefaultExt = '.xaml'
        $dialog.AddExtension = $true
        $dialog.OverwritePrompt = $true
        $dialog.Title = 'Save XAML and PowerShell code-behind'

        if ($dialog.ShowDialog() -ne $true) {
            return
        }

        $targetXamlPath = $dialog.FileName
        $targetCodePath = [System.IO.Path]::ChangeExtension($targetXamlPath, '.ps1')
        if (-not (Confirm-CodeBehindOverwrite -CodePath $targetCodePath)) {
            Set-DesignerStatus -Message 'Save As cancelled; the paired PowerShell file was not overwritten.'
            return
        }
    }

    $oldXamlPath = $script:State.CurrentXamlPath
    $oldCodePath = $script:State.CurrentCodePath
    $oldCodeText = $script:State.Ui.CodeEditor.Text

    try {
        $script:State.CurrentXamlPath = $targetXamlPath
        $script:State.CurrentCodePath = $targetCodePath
        Sync-CodeEditor

        if (-not (Test-CodeEditorPowerShell)) {
            throw 'Generated PowerShell synchronization produced invalid syntax. The files were not saved.'
        }

        $xamlText = ConvertTo-FormattedXml -Document $script:State.XamlDocument
        Write-DesignerDocumentPair -XamlPath $targetXamlPath -XamlText $xamlText -CodePath $targetCodePath -CodeText $script:State.Ui.CodeEditor.Text

        Update-DocumentCaption
        Set-DocumentSavedSnapshot
        Set-DesignerStatus -Message "Saved XAML and PowerShell as UTF-8 with BOM for Windows PowerShell 5.1 compatibility: $targetXamlPath"
    }
    catch {
        $script:State.CurrentXamlPath = $oldXamlPath
        $script:State.CurrentCodePath = $oldCodePath
        $script:State.Ui.CodeEditor.Text = $oldCodeText
        Update-DocumentCaption
        Set-DesignerStatus -Message ("Save failed: " + $_.Exception.Message)

        [System.Windows.MessageBox]::Show(
            'Save failed. The designer attempted to restore the previous file pair.' +
            [Environment]::NewLine + [Environment]::NewLine +
            $_.Exception.Message,
            'Save failed',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
}
