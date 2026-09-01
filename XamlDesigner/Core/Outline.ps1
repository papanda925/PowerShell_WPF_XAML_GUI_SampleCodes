function New-OutlineTreeItem {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Node
    )

    $name = Get-ElementNameFromNode -Node $Node
    $header = $Node.LocalName
    if (-not [string]::IsNullOrWhiteSpace($name)) {
        $header += "  [$name]"
    }

    $item = [System.Windows.Controls.TreeViewItem]::new()
    $item.Header = $header
    $item.Tag = $name
    $item.IsExpanded = $true

    foreach ($child in $Node.ChildNodes) {
        if ($child -is [System.Xml.XmlElement]) {
            [void]$item.Items.Add((New-OutlineTreeItem -Node $child))
        }
    }
    return $item
}

function Refresh-DocumentOutline {
    $tree = $script:State.Ui.OutlineTree
    if ($null -eq $tree) {
        return
    }

    $tree.Items.Clear()
    if ($null -eq $script:State.XamlDocument -or $null -eq $script:State.XamlDocument.DocumentElement) {
        return
    }

    foreach ($child in $script:State.XamlDocument.DocumentElement.ChildNodes) {
        if ($child -is [System.Xml.XmlElement]) {
            [void]$tree.Items.Add((New-OutlineTreeItem -Node $child))
        }
    }
}
