function Get-SimpleEditableProperties {
    param(
        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement]$Element
    )

    $preferredOrder = @(
        'Name', 'Width', 'Height', 'MinWidth', 'MinHeight', 'MaxWidth', 'MaxHeight',
        'Margin', 'HorizontalAlignment', 'VerticalAlignment', 'Visibility', 'IsEnabled',
        'Background', 'Foreground', 'BorderBrush', 'BorderThickness',
        'FontFamily', 'FontSize', 'FontWeight', 'FontStyle',
        'Content', 'Text', 'ToolTip', 'Opacity'
    )

    $items = [System.Collections.Generic.List[object]]::new()
    if ($Element.Parent -is [System.Windows.Controls.Canvas]) {
        $left = [System.Windows.Controls.Canvas]::GetLeft($Element)
        $top = [System.Windows.Controls.Canvas]::GetTop($Element)
        if ([double]::IsNaN($left)) { $left = 0 }
        if ([double]::IsNaN($top)) { $top = 0 }
        $items.Add([pscustomobject]@{ Name = 'Canvas.Left'; Value = [string]$left; TypeName = 'System.Double'; IsAttached = $true })
        $items.Add([pscustomobject]@{ Name = 'Canvas.Top'; Value = [string]$top; TypeName = 'System.Double'; IsAttached = $true })
        $items.Add([pscustomobject]@{ Name = 'Panel.ZIndex'; Value = [string][System.Windows.Controls.Panel]::GetZIndex($Element); TypeName = 'System.Int32'; IsAttached = $true })
    }

    $properties = @($Element.GetType().GetProperties([System.Reflection.BindingFlags]'Public,Instance') | Where-Object {
        $_.CanRead -and $_.CanWrite -and $_.GetIndexParameters().Count -eq 0
    })

    $propertyItems = foreach ($property in $properties) {
        $type = $property.PropertyType
        $converter = [System.ComponentModel.TypeDescriptor]::GetConverter($type)
        $editable = $type.IsEnum -or $type -eq [string] -or $type.IsPrimitive -or $type -eq [decimal] -or $converter.CanConvertFrom([string])
        if (-not $editable) {
            continue
        }

        try {
            $value = $property.GetValue($Element, $null)
            if ($null -eq $value) {
                $text = ''
            }
            elseif ($converter.CanConvertTo([string])) {
                try { $text = $converter.ConvertToInvariantString($value) } catch { $text = [string]$value }
            }
            else {
                $text = [string]$value
            }

            [pscustomobject]@{
                Name = $property.Name
                Value = $text
                TypeName = $type.FullName
                IsAttached = $false
            }
        }
        catch {
            # Some WPF properties throw when queried outside a complete visual tree.
        }
    }

    $ordered = @($propertyItems | Sort-Object @{ Expression = {
        $index = [array]::IndexOf($preferredOrder, $_.Name)
        if ($index -lt 0) { 1000 } else { $index }
    } }, Name)
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

    $events = @($element.GetType().GetEvents([System.Reflection.BindingFlags]'Public,Instance') | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            DeclaringType = $_.DeclaringType.Name
        }
    })
    $grid.ItemsSource = $events
}

function Refresh-SelectionPanels {
    if ([string]::IsNullOrWhiteSpace($script:State.SelectedElementName) -or $null -eq $script:State.SelectedRuntimeElement) {
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
    Set-DesignerStatus -Message "Selected $($Element.Name)."
}

function Apply-SelectedProperty {
    $selected = $script:State.Ui.PropertyGrid.SelectedItem
    if ($null -eq $selected -or [string]::IsNullOrWhiteSpace($script:State.SelectedElementName)) {
        return
    }

    $node = Get-XamlElementByName -Name $script:State.SelectedElementName
    if ($null -eq $node) {
        return
    }

    $propertyName = [string]$selected.Name
    $value = $script:State.Ui.PropertyValueText.Text
    $oldXml = ConvertTo-FormattedXml -Document $script:State.XamlDocument
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
            $script:State.SelectedElementName = $value
        }
        elseif ([string]::IsNullOrWhiteSpace($value)) {
            $node.RemoveAttribute($propertyName)
        }
        else {
            $node.SetAttribute($propertyName, $value)
        }

        if (-not (Refresh-Preview -KeepSelection)) {
            throw 'The property value is not valid for this XAML element.'
        }
        Refresh-XamlTextFromDocument
        Sync-CodeEditor
        Set-DesignerStatus -Message "Applied $propertyName to $($script:State.SelectedElementName)."
    }
    catch {
        $script:State.XamlDocument = New-XmlDocumentFromText -Text $oldXml
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
