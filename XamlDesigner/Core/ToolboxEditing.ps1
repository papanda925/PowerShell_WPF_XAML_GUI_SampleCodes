function Set-DefaultNewElementAttributes {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Node,

        [Parameter(Mandatory)]
        [Type]$Type,

        [double]$Left = 20,

        [double]$Top = 20,

        [switch]$CanvasParent
    )

    $name = New-UniqueControlName -BaseName $Type.Name
    Set-ElementNameOnNode -Node $Node -Name $name

    if ($CanvasParent) {
        $Node.SetAttribute('Canvas.Left', ([math]::Round($Left)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
        $Node.SetAttribute('Canvas.Top', ([math]::Round($Top)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
    }

    $defaults = switch ($Type.Name) {
        'Button' { @{ Content = 'Button'; Width = '110'; Height = '32' }; break }
        'Label' { @{ Content = 'Label'; Width = '120'; Height = '30' }; break }
        'TextBlock' { @{ Text = 'TextBlock'; Width = '140'; Height = '28' }; break }
        'TextBox' { @{ Text = ''; Width = '180'; Height = '30' }; break }
        'PasswordBox' { @{ Width = '180'; Height = '30' }; break }
        'CheckBox' { @{ Content = 'CheckBox'; Width = '130'; Height = '28' }; break }
        'RadioButton' { @{ Content = 'RadioButton'; Width = '140'; Height = '28' }; break }
        'ComboBox' { @{ Width = '160'; Height = '30' }; break }
        'ListBox' { @{ Width = '180'; Height = '120' }; break }
        'ListView' { @{ Width = '220'; Height = '140' }; break }
        'TreeView' { @{ Width = '220'; Height = '180' }; break }
        'DataGrid' { @{ Width = '320'; Height = '180'; AutoGenerateColumns = 'True' }; break }
        'Slider' { @{ Width = '180'; Height = '30'; Minimum = '0'; Maximum = '100'; Value = '50' }; break }
        'ProgressBar' { @{ Width = '180'; Height = '24'; Minimum = '0'; Maximum = '100'; Value = '50' }; break }
        'DatePicker' { @{ Width = '160'; Height = '30' }; break }
        'Calendar' { @{ Width = '240'; Height = '180' }; break }
        'Image' { @{ Width = '160'; Height = '120'; Stretch = 'Uniform' }; break }
        'Border' { @{ Width = '200'; Height = '130'; BorderBrush = 'Gray'; BorderThickness = '1'; Padding = '6' }; break }
        'GroupBox' { @{ Header = 'Group'; Width = '220'; Height = '150' }; break }
        'ScrollViewer' { @{ Width = '220'; Height = '150'; VerticalScrollBarVisibility = 'Auto' }; break }
        'Viewbox' { @{ Width = '220'; Height = '150' }; break }
        'Canvas' { @{ Width = '260'; Height = '180'; Background = 'Transparent' }; break }
        'Grid' { @{ Width = '260'; Height = '180'; Background = 'Transparent' }; break }
        'StackPanel' { @{ Width = '220'; Height = '160' }; break }
        'WrapPanel' { @{ Width = '220'; Height = '160' }; break }
        'DockPanel' { @{ Width = '220'; Height = '160' }; break }
        'UniformGrid' { @{ Width = '220'; Height = '160'; Rows = '2'; Columns = '2' }; break }
        'TabControl' { @{ Width = '300'; Height = '200' }; break }
        'Rectangle' { @{ Width = '120'; Height = '80'; Stroke = 'Gray'; Fill = 'Transparent' }; break }
        'Ellipse' { @{ Width = '120'; Height = '80'; Stroke = 'Gray'; Fill = 'Transparent' }; break }
        'Line' { @{ X1 = '0'; Y1 = '0'; X2 = '120'; Y2 = '60'; Stroke = 'Black'; StrokeThickness = '1' }; break }
        default {
            if ([System.Windows.Controls.Control].IsAssignableFrom($Type)) {
                @{ Width = '120'; Height = '32' }
            }
            elseif ([System.Windows.Shapes.Shape].IsAssignableFrom($Type)) {
                @{ Width = '120'; Height = '80'; Stroke = 'Gray' }
            }
            else {
                @{}
            }
        }
    }

    foreach ($key in $defaults.Keys) {
        $Node.SetAttribute($key, [string]$defaults[$key])
    }
    return $name
}

function Test-XamlLayoutContainerNode {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Node
    )

    return $Node.LocalName -in @('Canvas', 'Grid', 'StackPanel', 'WrapPanel', 'DockPanel', 'UniformGrid')
}

function Test-XamlSingleChildContainerNode {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Node
    )

    return $Node.LocalName -in @('Border', 'GroupBox', 'ScrollViewer', 'Viewbox')
}

function Test-XamlNodeHasDirectContentChild {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Node
    )

    foreach ($child in $Node.ChildNodes) {
        if ($child -isnot [System.Xml.XmlElement]) {
            continue
        }

        # Property elements such as Border.Background or Grid.RowDefinitions
        # configure the parent and are not the parent's content child.
        if ($child.LocalName.Contains('.')) {
            continue
        }

        return $true
    }

    return $false
}

function Get-PrimaryDesignContainerNode {
    if (-not [string]::IsNullOrWhiteSpace($script:State.SelectedElementName)) {
        $selectedNode = Get-XamlElementByName -Name $script:State.SelectedElementName
        if ($null -ne $selectedNode -and (Test-XamlLayoutContainerNode -Node $selectedNode)) {
            return $selectedNode
        }

        if (
            $null -ne $selectedNode -and
            (Test-XamlSingleChildContainerNode -Node $selectedNode) -and
            -not (Test-XamlNodeHasDirectContentChild -Node $selectedNode)
        ) {
            return $selectedNode
        }
    }

    $designCanvas = Get-XamlElementByName -Name 'DesignCanvas'
    if ($null -ne $designCanvas) {
        return $designCanvas
    }

    $root = $script:State.XamlDocument.DocumentElement
    if ($null -eq $root) {
        return $null
    }

    foreach ($child in $root.ChildNodes) {
        if ($child -isnot [System.Xml.XmlElement]) {
            continue
        }
        if (Test-XamlLayoutContainerNode -Node $child) {
            return $child
        }
        if (
            (Test-XamlSingleChildContainerNode -Node $child) -and
            -not (Test-XamlNodeHasDirectContentChild -Node $child)
        ) {
            return $child
        }
    }
    return $null
}

function Add-ToolboxElementToDocument {
    param(
        [Parameter(Mandatory)]
        [Type]$Type,

        [double]$Left = 20,

        [double]$Top = 20
    )

    $container = Get-PrimaryDesignContainerNode
    if ($null -eq $container) {
        Set-DesignerStatus -Message 'No supported target container was found. Select a panel or an empty Border/GroupBox/ScrollViewer/Viewbox.'
        return
    }

    if (
        (Test-XamlSingleChildContainerNode -Node $container) -and
        (Test-XamlNodeHasDirectContentChild -Node $container)
    ) {
        Set-DesignerStatus -Message "$($container.LocalName) already has a content child. Select another container or edit XAML source."
        return
    }

    Push-XamlUndoSnapshot
    $node = $script:State.XamlDocument.CreateElement($Type.Name, $script:PresentationNs)
    $isCanvas = $container.LocalName -eq 'Canvas'
    $name = Set-DefaultNewElementAttributes -Node $node -Type $Type -Left $Left -Top $Top -CanvasParent:$isCanvas
    [void]$container.AppendChild($node)

    $script:State.SelectedElementName = $name
    Refresh-XamlTextFromDocument
    Sync-CodeEditor
    [void](Refresh-Preview -KeepSelection)

    $targetName = Get-ElementNameFromNode -Node $container
    if ([string]::IsNullOrWhiteSpace($targetName)) {
        $targetName = $container.LocalName
    }
    Set-DesignerStatus -Message "Added $($Type.Name) as $name to $targetName."
}

function Add-SelectedToolboxItem {
    $item = $script:State.Ui.ToolboxList.SelectedItem
    if ($null -eq $item) {
        Set-DesignerStatus -Message 'Select a toolbox control first.'
        return
    }

    $left = 20.0
    $top = 20.0
    $container = Get-PrimaryDesignContainerNode
    if ($null -ne $container -and $container.LocalName -eq 'Canvas') {
        $contentCount = 0
        foreach ($child in $container.ChildNodes) {
            if ($child -is [System.Xml.XmlElement] -and -not $child.LocalName.Contains('.')) {
                $contentCount++
            }
        }
        $offset = ($contentCount % 8) * 20
        $left += $offset
        $top += $offset
    }

    Add-ToolboxElementToDocument -Type $item.Type -Left $left -Top $top
}

function New-UniqueCloneName {
    param(
        [Parameter(Mandatory)]
        [string]$BaseName,

        [Parameter(Mandatory)]
        [System.Collections.Generic.HashSet[string]]$ReservedNames
    )

    $safeBase = $BaseName -replace '[^A-Za-z0-9_]', ''
    if ([string]::IsNullOrWhiteSpace($safeBase)) {
        $safeBase = 'Control'
    }

    $index = 1
    do {
        $candidate = "$safeBase$index"
        $index++
    } while ($ReservedNames.Contains($candidate))

    [void]$ReservedNames.Add($candidate)
    return $candidate
}

function Update-ClonedNameReferences {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Root,

        [Parameter(Mandatory)]
        [hashtable]$RenameMap
    )

    foreach ($node in @($Root) + @($Root.SelectNodes('.//*'))) {
        if ($node -isnot [System.Xml.XmlElement]) {
            continue
        }

        foreach ($attribute in @($node.Attributes)) {
            $updated = $attribute.Value
            foreach ($oldName in $RenameMap.Keys) {
                $newName = [string]$RenameMap[$oldName]
                if ($updated -eq $oldName -and $attribute.LocalName -in @('TargetName','SourceName','Storyboard.TargetName')) {
                    $updated = $newName
                }
                $updated = [regex]::Replace(
                    $updated,
                    '(?i)(ElementName\s*=\s*)' + [regex]::Escape($oldName) + '(?=\s*[,}])',
                    '$1' + $newName
                )
            }
            if ($updated -cne $attribute.Value) {
                $attribute.Value = $updated
            }
        }
    }
}

function Copy-XamlElementNode {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Source
    )

    $copy = [System.Xml.XmlElement]$Source.CloneNode($true)
    $reservedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($item in Get-AllNamedXamlElements) {
        [void]$reservedNames.Add($item.Name)
    }

    $renameMap = @{}
    $newRootName = $null
    foreach ($node in @($copy) + @($copy.SelectNodes('.//*'))) {
        if ($node -isnot [System.Xml.XmlElement]) {
            continue
        }

        $oldName = Get-ElementNameFromNode -Node $node
        if ([string]::IsNullOrWhiteSpace($oldName)) {
            continue
        }

        if (Test-XamlNodeInSeparateNameScope -Node $node) {
            continue
        }

        $newName = New-UniqueCloneName -BaseName $node.LocalName -ReservedNames $reservedNames
        Set-ElementNameOnNode -Node $node -Name $newName
        $renameMap[$oldName] = $newName

        if ($node -eq $copy) {
            $newRootName = $newName
        }
    }

    Update-ClonedNameReferences -Root $copy -RenameMap $renameMap

    foreach ($attributeName in @('Canvas.Left', 'Canvas.Top')) {
        if ($copy.HasAttribute($attributeName)) {
            $value = 0.0
            if ([double]::TryParse(
                $copy.GetAttribute($attributeName),
                [System.Globalization.NumberStyles]::Float,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [ref]$value
            )) {
                $copy.SetAttribute(
                    $attributeName,
                    ($value + 20).ToString([System.Globalization.CultureInfo]::InvariantCulture)
                )
            }
        }
    }

    [void]$Source.ParentNode.AppendChild($copy)
    return $newRootName
}

function Delete-SelectedElement {
    if ([string]::IsNullOrWhiteSpace($script:State.SelectedElementName)) {
        return
    }

    $node = Get-XamlElementByName -Name $script:State.SelectedElementName
    if ($null -eq $node -or $node -eq $script:State.XamlDocument.DocumentElement) {
        return
    }

    Push-XamlUndoSnapshot
    $deletedName = $script:State.SelectedElementName
    $deletedControlNames = [System.Collections.Generic.List[string]]::new()
    foreach ($subtreeNode in @($node) + @($node.SelectNodes('.//*'))) {
        if ($subtreeNode -isnot [System.Xml.XmlElement]) {
            continue
        }
        if (Test-XamlNodeInSeparateNameScope -Node $subtreeNode) {
            continue
        }
        $subtreeName = Get-ElementNameFromNode -Node $subtreeNode
        if (-not [string]::IsNullOrWhiteSpace($subtreeName)) {
            $deletedControlNames.Add($subtreeName)
        }
    }

    [void]$node.ParentNode.RemoveChild($node)

    if (Get-Command Remove-GeneratedEventsForControl -ErrorAction SilentlyContinue) {
        foreach ($controlName in $deletedControlNames) {
            $script:State.Ui.CodeEditor.Text = Remove-GeneratedEventsForControl -Code $script:State.Ui.CodeEditor.Text -ControlName $controlName
        }
    }

    $script:State.SelectedElementName = $null
    $script:State.SelectedRuntimeElement = $null
    Refresh-XamlTextFromDocument
    Sync-CodeEditor
    [void](Refresh-Preview)
    Set-DesignerStatus -Message "Deleted $deletedName and cleaned generated event blocks for $($deletedControlNames.Count) named control(s) in that subtree. Code outside generated blocks was preserved."
}

function Duplicate-SelectedElement {
    if ([string]::IsNullOrWhiteSpace($script:State.SelectedElementName)) {
        return
    }

    $node = Get-XamlElementByName -Name $script:State.SelectedElementName
    if ($null -eq $node -or $node -eq $script:State.XamlDocument.DocumentElement) {
        return
    }

    Push-XamlUndoSnapshot
    $newName = Copy-XamlElementNode -Source $node
    if ([string]::IsNullOrWhiteSpace($newName)) {
        Set-DesignerStatus -Message 'The selected XAML element has no x:Name and could not be selected after duplication.'
        return
    }

    $script:State.SelectedElementName = $newName
    Refresh-XamlTextFromDocument
    Sync-CodeEditor
    [void](Refresh-Preview -KeepSelection)
    Set-DesignerStatus -Message "Duplicated the control subtree as $newName. Named child controls were also renamed to keep x:Name values unique."
}

function Move-SelectedCanvasElementBy {
    param(
        [double]$DeltaX,
        [double]$DeltaY
    )

    $element = $script:State.SelectedRuntimeElement
    if ($element -isnot [System.Windows.FrameworkElement] -or $element.Parent -isnot [System.Windows.Controls.Canvas]) {
        return $false
    }

    $left = [System.Windows.Controls.Canvas]::GetLeft($element)
    $top = [System.Windows.Controls.Canvas]::GetTop($element)
    if ([double]::IsNaN($left)) { $left = 0 }
    if ([double]::IsNaN($top)) { $top = 0 }

    $newLeft = [math]::Max(0, $left + $DeltaX)
    $newTop = [math]::Max(0, $top + $DeltaY)
    if ([math]::Abs($newLeft - $left) -lt 0.01 -and [math]::Abs($newTop - $top) -lt 0.01) {
        return $false
    }

    Push-XamlUndoSnapshot
    [System.Windows.Controls.Canvas]::SetLeft($element, $newLeft)
    [System.Windows.Controls.Canvas]::SetTop($element, $newTop)
    Update-SelectedCanvasPosition -Left $newLeft -Top $newTop
    Refresh-PropertyGrid
    Set-DesignerStatus -Message "Moved $($script:State.SelectedElementName) to $newLeft, $newTop."
    return $true
}
