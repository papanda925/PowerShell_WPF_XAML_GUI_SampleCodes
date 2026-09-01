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
        'Slider' { @{ Width = '180'; Height = '30'; Minimum = '0'; Maximum = '100'; Value = '50' }; break }
        'ProgressBar' { @{ Width = '180'; Height = '24'; Minimum = '0'; Maximum = '100'; Value = '50' }; break }
        'Image' { @{ Width = '160'; Height = '120'; Stretch = 'Uniform' }; break }
        'Border' { @{ Width = '180'; Height = '120'; BorderBrush = 'Gray'; BorderThickness = '1' }; break }
        'Canvas' { @{ Width = '240'; Height = '160'; Background = 'Transparent' }; break }
        'Grid' { @{ Width = '240'; Height = '160'; Background = 'Transparent' }; break }
        'StackPanel' { @{ Width = '220'; Height = '160' }; break }
        'WrapPanel' { @{ Width = '220'; Height = '160' }; break }
        'DockPanel' { @{ Width = '220'; Height = '160' }; break }
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

function Get-PrimaryDesignContainerNode {
    if (-not [string]::IsNullOrWhiteSpace($script:State.SelectedElementName)) {
        $selectedNode = Get-XamlElementByName -Name $script:State.SelectedElementName
        if ($null -ne $selectedNode -and (Test-XamlLayoutContainerNode -Node $selectedNode)) {
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

    Push-XamlUndoSnapshot

    $container = Get-PrimaryDesignContainerNode
    if ($null -eq $container) {
        Set-DesignerStatus -Message 'No supported root layout container was found. Add a Canvas/Grid/StackPanel first in XAML source.'
        return
    }

    $node = $script:State.XamlDocument.CreateElement($Type.Name, $script:PresentationNs)
    $isCanvas = $container.LocalName -eq 'Canvas'
    $name = Set-DefaultNewElementAttributes -Node $node -Type $Type -Left $Left -Top $Top -CanvasParent:$isCanvas
    [void]$container.AppendChild($node)

    $script:State.SelectedElementName = $name
    Refresh-XamlTextFromDocument
    Sync-CodeEditor
    [void](Refresh-Preview -KeepSelection)
    $targetName = Get-ElementNameFromNode -Node $container
    if ([string]::IsNullOrWhiteSpace($targetName)) { $targetName = $container.LocalName }
    Set-DesignerStatus -Message "Added $($Type.Name) as $name to $targetName."
}

function Copy-XamlElementNode {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Source
    )

    $copy = [System.Xml.XmlElement]$Source.CloneNode($true)
    $newName = New-UniqueControlName -BaseName $Source.LocalName
    Set-ElementNameOnNode -Node $copy -Name $newName

    foreach ($attributeName in @('Canvas.Left', 'Canvas.Top')) {
        if ($copy.HasAttribute($attributeName)) {
            $value = 0.0
            if ([double]::TryParse($copy.GetAttribute($attributeName), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
                $copy.SetAttribute($attributeName, ($value + 20).ToString([System.Globalization.CultureInfo]::InvariantCulture))
            }
        }
    }

    [void]$Source.ParentNode.AppendChild($copy)
    return $newName
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
    [void]$node.ParentNode.RemoveChild($node)
    $script:State.SelectedElementName = $null
    $script:State.SelectedRuntimeElement = $null
    Refresh-XamlTextFromDocument
    Sync-CodeEditor
    [void](Refresh-Preview)
    Set-DesignerStatus -Message "Deleted $deletedName. Existing user-written event code is preserved for manual cleanup."
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
    $script:State.SelectedElementName = $newName
    Refresh-XamlTextFromDocument
    Sync-CodeEditor
    [void](Refresh-Preview -KeepSelection)
    Set-DesignerStatus -Message "Duplicated control as $newName."
}
