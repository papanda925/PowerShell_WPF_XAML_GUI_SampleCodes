function Sync-CodeBehindXamlFileName {
    param(
        [Parameter(Mandatory)]
        [string]$Code,

        [Parameter(Mandatory)]
        [string]$XamlFileName
    )

    $start = '# <XamlDesigner:XamlFile>'
    $end = '# </XamlDesigner:XamlFile>'
    $replacement = @"
$start
`$xamlFileName = '$($XamlFileName.Replace("'", "''"))'
$end
"@

    $pattern = [regex]::Escape($start) + '.*?' + [regex]::Escape($end)
    if ([regex]::IsMatch($Code, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        return [regex]::Replace(
            $Code,
            $pattern,
            [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement },
            [System.Text.RegularExpressions.RegexOptions]::Singleline
        )
    }

    return $replacement + "`r`n`r`n" + $Code
}

function Get-ControlReferenceLines {
    $lines = [System.Collections.Generic.List[string]]::new()

    foreach ($item in (Get-AllNamedXamlElements | Sort-Object Name)) {
        $type = Get-WpfTypeByElementName -ElementName $item.ElementName
        $typeName = 'System.Windows.FrameworkElement'
        if ($null -ne $type -and -not [string]::IsNullOrWhiteSpace($type.FullName)) {
            $typeName = $type.FullName
        }

        $escapedName = $item.Name.Replace("'", "''")
        $referenceLine = '[{0}]${{{1}}} = $Window.FindName(''{2}'')' -f $typeName, $item.Name, $escapedName
        $lines.Add($referenceLine)
    }

    return $lines
}

function Sync-CodeBehindControlReferences {
    param(
        [Parameter(Mandatory)]
        [string]$Code
    )

    $start = '# <XamlDesigner:ControlReferences>'
    $end = '# </XamlDesigner:ControlReferences>'
    $lines = Get-ControlReferenceLines
    $body = if ($lines.Count -gt 0) {
        $lines -join "`r`n"
    }
    else {
        '# No named child controls.'
    }

    $replacement = "$start`r`n$body`r`n$end"
    $pattern = [regex]::Escape($start) + '.*?' + [regex]::Escape($end)

    if ([regex]::IsMatch($Code, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        return [regex]::Replace(
            $Code,
            $pattern,
            [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement },
            [System.Text.RegularExpressions.RegexOptions]::Singleline
        )
    }

    return $Code.TrimEnd() + "`r`n`r`n$replacement`r`n"
}

function Sync-CodeEditor {
    $code = $script:State.Ui.CodeEditor.Text
    $xamlName = 'Untitled.xaml'

    if (-not [string]::IsNullOrWhiteSpace($script:State.CurrentXamlPath)) {
        $xamlName = Split-Path -Leaf $script:State.CurrentXamlPath
    }

    $code = Sync-CodeBehindXamlFileName -Code $code -XamlFileName $xamlName
    $code = Sync-CodeBehindControlReferences -Code $code
    $script:State.Ui.CodeEditor.Text = $code
}

function Test-CodeEditorPowerShell {
    $tokens = $null
    $parseErrors = $null

    [void][System.Management.Automation.Language.Parser]::ParseInput(
        $script:State.Ui.CodeEditor.Text,
        [ref]$tokens,
        [ref]$parseErrors
    )

    if ($null -ne $parseErrors -and $parseErrors.Count -gt 0) {
        $first = $parseErrors[0]
        $message = "PowerShell error at line $($first.Extent.StartLineNumber), column $($first.Extent.StartColumnNumber): $($first.Message)"
        Set-DesignerStatus -Message $message
        return $false
    }

    Set-DesignerStatus -Message 'PowerShell code-behind syntax is valid.'
    return $true
}

function Rename-GeneratedEventControlReference {
    param(
        [Parameter(Mandatory)]
        [string]$Code,

        [Parameter(Mandatory)]
        [string]$OldName,

        [Parameter(Mandatory)]
        [string]$NewName
    )

    if ($OldName -eq $NewName) {
        return $Code
    }

    $pattern = '(?ms)^# <XamlDesigner:Event Control="' + [regex]::Escape($OldName) + '" Name="(?<Event>[^"]+)">.*?^# </XamlDesigner:Event>$'

    return [regex]::Replace(
        $Code,
        $pattern,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($match)

            $block = $match.Value
            $block = $block.Replace('Control="' + $OldName + '"', 'Control="' + $NewName + '"')
            $block = $block.Replace('$' + '{' + $OldName + '}', '$' + '{' + $NewName + '}')
            return $block
        }
    )
}
