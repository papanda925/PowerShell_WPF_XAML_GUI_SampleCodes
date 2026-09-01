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
        return [regex]::Replace($Code, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    }

    return $replacement + "`r`n`r`n" + $Code
}

function Get-ControlReferenceLines {
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($item in (Get-AllNamedXamlElements | Sort-Object Name)) {
        $type = Get-WpfTypeByElementName -ElementName $item.ElementName
        $typeName = 'System.Windows.FrameworkElement'
        if ($null -ne $type) {
            $typeName = $type.FullName
        }
        $lines.Add("[$typeName]`$$($item.Name) = `$Window.FindName('$($item.Name.Replace("'", "''"))')")
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
    $body = if ($lines.Count -gt 0) { $lines -join "`r`n" } else { '# No named child controls.' }
    $replacement = "$start`r`n$body`r`n$end"
    $pattern = [regex]::Escape($start) + '.*?' + [regex]::Escape($end)

    if ([regex]::IsMatch($Code, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        return [regex]::Replace($Code, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    }

    return $Code + "`r`n`r`n$replacement`r`n"
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
