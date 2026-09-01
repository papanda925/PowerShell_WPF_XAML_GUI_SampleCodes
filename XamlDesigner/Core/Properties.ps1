function New-EditablePropertyItem {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$TypeName,

        [bool]$IsAttached = $false,

        [string]$Help = ''
    )

    return [pscustomobject]@{
        Name = $Name
        Value = $Value
        TypeName = $TypeName
        IsAttached = $IsAttached
        Help = $Help
    }
}

function Get-SimpleEditableProperties {
    param(
        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement]$Element
    )

    $preferredOrder = @(
        'Name',
        'Canvas.Left', 'Canvas.Top',
        'Grid.Row', 'Grid.Column', 'Grid.RowSpan', 'Grid.ColumnSpan',
        'DockPanel.Dock', 'Panel.ZIndex',
        'Width', 'Height', 'MinWidth', 'MinHeight', 'MaxWidth', 'MaxHeight',
        'Margin', 'HorizontalAlignment', 'VerticalAlignment', 'Visibility', 'IsEnabled',
        'Background', 'Foreground', 'BorderBrush', 'BorderThickness',
        'FontFamily', 'FontSize', 'FontWeight', 'FontStyle',
        'Content', 'Text', 'ToolTip', 'Opacity'
    )

    $items = [System.Collections.Generic.List[object]]::new()
    $parent = $Element.Parent

    if ($parent -is [System.Windows.Controls.Canvas]) {
        $left = [System.Windows.Controls.Canvas]::GetLeft($Element)
        $top = [System.Windows.Controls.Canvas]::GetTop($Element)
        if ([double]::IsNaN($left)) { $left = 0 }
        if ([double]::IsNaN($top)) { $top = 0 }

        $items.Add((New-EditablePropertyItem -Name 'Canvas.Left' -Value ([string]$left) -TypeName 'System.Double' -IsAttached $true -Help 'Horizontal position in pixels. Enter a number.'))
        $items.Add((New-EditablePropertyItem -Name 'Canvas.Top' -Value ([string]$top) -TypeName 'System.Double' -IsAttached $true -Help 'Vertical position in pixels. Enter a number.'))
    }

    if ($parent -is [System.Windows.Controls.Grid]) {
        $items.Add((New-EditablePropertyItem -Name 'Grid.Row' -Value ([string][System.Windows.Controls.Grid]::GetRow($Element)) -TypeName 'System.Int32' -IsAttached $true -Help 'Zero-based row number, for example 0 or 1.'))
        $items.Add((New-EditablePropertyItem -Name 'Grid.Column' -Value ([string][System.Windows.Controls.Grid]::GetColumn($Element)) -TypeName 'System.Int32' -IsAttached $true -Help 'Zero-based column number, for example 0 or 1.'))
        $items.Add((New-EditablePropertyItem -Name 'Grid.RowSpan' -Value ([string][System.Windows.Controls.Grid]::GetRowSpan($Element)) -TypeName 'System.Int32' -IsAttached $true -Help 'Number of Grid rows to span. Minimum is 1.'))
        $items.Add((New-EditablePropertyItem -Name 'Grid.ColumnSpan' -Value ([string][System.Windows.Controls.Grid]::GetColumnSpan($Element)) -TypeName 'System.Int32' -IsAttached $true -Help 'Number of Grid columns to span. Minimum is 1.'))
    }

    if ($parent -is [System.Windows.Controls.DockPanel]) {
        $items.Add((New-EditablePropertyItem -Name 'DockPanel.Dock' -Value ([string][System.Windows.Controls.DockPanel]::GetDock($Element)) -TypeName 'System.Windows.Controls.Dock' -IsAttached $true -Help 'Suggested values: Left, Top, Right, Bottom.'))
    }

    if ($parent -is [System.Windows.Controls.Panel]) {
        $items.Add((New-EditablePropertyItem -Name 'Panel.ZIndex' -Value ([string][System.Windows.Controls.Panel]::GetZIndex($Element)) -TypeName 'System.Int32' -IsAttached $true -Help 'Drawing order. Larger numbers appear above smaller numbers.'))
    }

    $properties = @(
        $Element.GetType().GetProperties([System.Reflection.BindingFlags]'Public,Instance') |
        Where-Object {
            $_.CanRead -and $_.CanWrite -and $_.GetIndexParameters().Count -eq 0
        }
    )

    $propertyItems = foreach ($property in $properties) {
        $type = $property.PropertyType
        $converter = [System.ComponentModel.TypeDescriptor]::GetConverter($type)
        $editable = (
            $type.IsEnum -or
            $type -eq [string] -or
            $type.IsPrimitive -or
            $type -eq [decimal] -or
            $converter.CanConvertFrom([string])
        )
        if (-not $editable) {
            continue
        }

        try {
            $value = $property.GetValue($Element, $null)
            if ($null -eq $value) {
                $text = ''
            }
            elseif ($converter.CanConvertTo([string])) {
                try {
                    $text = $converter.ConvertToInvariantString($value)
                }
                catch {
                    $text = [string]$value
                }
            }
            else {
                $text = [string]$value
            }

            $help = "Type: $($type.Name)."
            if ($type.IsEnum) {
                $help += ' Suggested values: ' + ([Enum]::GetNames($type) -join ', ') + '.'
            }
            elseif ($type -eq [bool]) {
                $help += ' Enter True or False.'
            }
            elseif ($type -eq [double] -or $type -eq [single] -or $type -eq [decimal]) {
                $help += ' Enter a number using a dot as the decimal separator.'
            }
            elseif ($property.Name -eq 'Name') {
                $help = 'x:Name must start with a letter or underscore and contain only letters, digits, and underscores.'
            }

            New-EditablePropertyItem -Name $property.Name -Value $text -TypeName $type.FullName -Help $help
        }
        catch {
            # Some WPF properties throw when queried outside a complete visual tree.
        }
    }

    $ordered = @(
        $propertyItems |
        Sort-Object @{
            Expression = {
                $index = [array]::IndexOf($preferredOrder, $_.Name)
                if ($index -lt 0) { 1000 } else { $index }
            }
        }, Name
    )

    foreach ($item in $ordered) {
        $items.Add($item)
    }

    return $items
}

function Refresh-PropertyGrid {
    $grid = $script:State.Ui.PropertyGrid
    $grid.ItemsSource = $null
    $script:State.Ui.PropertyNameText.Text = 'Select a property'
    $script:State.Ui.PropertyValueText.Text = ''
    $script:State.Ui.PropertyHelpText.Text = 'Select a property to see its type and suggested values.'

    $element = $script:State.SelectedRuntimeElement
    if ($element -isnot [System.Windows.FrameworkElement]) {
        return
    }

    $grid.ItemsSource = Get-SimpleEditableProperties -Element $element
}

function Refresh-EventGrid {
    $grid = $script:State.Ui.EventGrid
    $grid.ItemsSource = $null
    $element = $script:State.SelectedRuntimeElement
    if ($element -isnot [System.Windows.FrameworkElement]) {
        return
    }

    $commonEvents = @(
        'Click',
        'Checked',
        'Unchecked',
        'SelectionChanged',
        'TextChanged',
        'ValueChanged',
        'SelectedDateChanged',
        'MouseDoubleClick',
        'KeyDown',
        'Loaded'
    )

    $events = @(
        $element.GetType().GetEvents([System.Reflection.BindingFlags]'Public,Instance') |
        ForEach-Object {
            $priority = [array]::IndexOf($commonEvents, $_.Name)
            if ($priority -lt 0) {
                $priority = 1000
            }

            [pscustomobject]@{
                Name = $_.Name
                DeclaringType = $_.DeclaringType.Name
                Priority = $priority
            }
        } |
        Sort-Object Priority, Name
    )

    $grid.ItemsSource = $events
}

function Refresh-SelectionPanels {
    if (
        [string]::IsNullOrWhiteSpace($script:State.SelectedElementName) -or
        $null -eq $script:State.SelectedRuntimeElement
    ) {
        $script:State.Ui.SelectedControlText.Text = 'No control selected'
    }
    else {
        $script:State.Ui.SelectedControlText.Text = "$($script:State.SelectedElementName) : $($script:State.SelectedRuntimeElement.GetType().Name)"
    }

    Refresh-PropertyGrid
    Refresh-EventGrid
}

function Select-DesignerElement {
    param(
        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement]$Element
    )

    $script:State.SelectedRuntimeElement = $Element
    $script:State.SelectedElementName = $Element.Name
    Refresh-SelectionPanels
    Set-DesignerStatus -Message "Selected $($Element.Name). Choose a property on the right, or double-click the control to generate its common event."
}

function Apply-SelectedProperty {
    $selected = $script:State.Ui.PropertyGrid.SelectedItem
    if ($null -eq $selected -or [string]::IsNullOrWhiteSpace($script:State.SelectedElementName)) {
        Set-DesignerStatus -Message 'Select a control and a property first.'
        return
    }

    $node = Get-XamlElementByName -Name $script:State.SelectedElementName
    if ($null -eq $node) {
        return
    }

    $propertyName = [string]$selected.Name
    $value = $script:State.Ui.PropertyValueText.Text
    $oldXml = ConvertTo-FormattedXml -Document $script:State.XamlDocument
    $oldCode = $script:State.Ui.CodeEditor.Text
    $oldName = $script:State.SelectedElementName

    try {
        if ($propertyName -eq 'Name') {
            if ([string]::IsNullOrWhiteSpace($value) -or $value -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
                throw 'x:Name must start with a letter or underscore and contain only letters, digits, and underscores.'
            }

            $existing = Get-XamlElementByName -Name $value
            if ($value -ne $oldName -and $null -ne $existing) {
                throw "A control named '$value' already exists."
            }

            Set-ElementNameOnNode -Node $node -Name $value
            if ($value -ne $oldName) {
                $script:State.Ui.CodeEditor.Text = Rename-GeneratedEventControlReference -Code $script:State.Ui.CodeEditor.Text -OldName $oldName -NewName $value
            }
            $script:State.SelectedElementName = $value
        }
        elseif ([string]::IsNullOrWhiteSpace($value)) {
            $node.RemoveAttribute($propertyName)
        }
        else {
            $node.SetAttribute($propertyName, $value)
        }

        if (-not (Refresh-Preview -KeepSelection)) {
            throw 'WPF rejected the property value. Check the suggested value/type and try again.'
        }

        Push-XamlUndoSnapshot -Text $oldXml -CodeText $oldCode -SelectionName $oldName
        Refresh-XamlTextFromDocument
        Sync-CodeEditor
        Set-DesignerStatus -Message "Applied $propertyName to $($script:State.SelectedElementName)."
    }
    catch {
        $script:State.XamlDocument = New-XmlDocumentFromText -Text $oldXml
        $script:State.Ui.CodeEditor.Text = $oldCode
        $script:State.SelectedElementName = $oldName
        [void](Refresh-Preview -KeepSelection)
        Refresh-XamlTextFromDocument

        [System.Windows.MessageBox]::Show(
            $_.Exception.Message,
            'Property update failed',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        ) | Out-Null
    }
}
