function Initialize-UiReferences {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window]$Window
    )

    $names = @(
        'MenuNew','MenuOpen','MenuSave','MenuSaveAs','MenuExit','MenuDelete','MenuDuplicate','MenuValidate','MenuRefreshToolbox','MenuAbout',
        'StatusText','DocumentText','ToolboxSearch','ToolboxCategory','ToolboxList','MainTabs','PreviewBorder','PreviewHost','CheckSnapToGrid',
        'ButtonDelete','ButtonDuplicate','ButtonApplyXaml','ButtonFormatXaml','XamlEditor','CodeEditor','SelectedControlText','PropertyGrid',
        'PropertyNameText','PropertyValueText','ButtonApplyProperty','EventGrid'
    )

    foreach ($name in $names) {
        $script:State.Ui[$name] = Get-UiControl -Window $Window -Name $name
    }
}

function Register-UiEvents {
    $ui = $script:State.Ui

    $ui.MenuNew.Add_Click({ New-XamlDesignerDocument })
    $ui.MenuOpen.Add_Click({ Open-XamlDesignerDocument })
    $ui.MenuSave.Add_Click({ Save-XamlDesignerDocument })
    $ui.MenuSaveAs.Add_Click({ Save-XamlDesignerDocument -SaveAs })
    $ui.MenuExit.Add_Click({ $script:State.Window.Close() })
    $ui.MenuDelete.Add_Click({ Delete-SelectedElement })
    $ui.MenuDuplicate.Add_Click({ Duplicate-SelectedElement })
    $ui.MenuValidate.Add_Click({ [void](Apply-XamlEditorText) })
    $ui.MenuRefreshToolbox.Add_Click({ Refresh-ToolboxCatalog })
    $ui.MenuAbout.Add_Click({
        [System.Windows.MessageBox]::Show(
            "PowerShell XAML Designer`r`n`r`nA dependency-free WPF/XAML visual editor implemented in PowerShell. XAML defines the UI; a paired .ps1 file contains control references and event logic.",
            'About PowerShell XAML Designer',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
    })

    $ui.ButtonDelete.Add_Click({ Delete-SelectedElement })
    $ui.ButtonDuplicate.Add_Click({ Duplicate-SelectedElement })
    $ui.ButtonApplyXaml.Add_Click({ [void](Apply-XamlEditorText) })
    $ui.ButtonFormatXaml.Add_Click({
        try {
            $document = New-XmlDocumentFromText -Text $ui.XamlEditor.Text
            $ui.XamlEditor.Text = ConvertTo-FormattedXml -Document $document
            Set-DesignerStatus -Message 'XML formatted.'
        }
        catch [System.Xml.XmlException] {
            Set-DesignerStatus -Message "XML format error at line $($_.Exception.LineNumber), position $($_.Exception.LinePosition): $($_.Exception.Message)"
        }
    })

    $ui.ToolboxSearch.Add_TextChanged({ Apply-ToolboxFilter })
    $ui.ToolboxCategory.Add_SelectionChanged({ Apply-ToolboxFilter })

    $ui.ToolboxList.Add_PreviewMouseLeftButtonDown({
        param($sender, $e)
        $script:State.ToolboxDragOrigin = $e.GetPosition($sender)
    })

    $ui.ToolboxList.Add_PreviewMouseMove({
        param($sender, $e)
        if ($e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) {
            return
        }
        if ($null -eq $sender.SelectedItem -or $null -eq $script:State.ToolboxDragOrigin) {
            return
        }
        $position = $e.GetPosition($sender)
        $deltaX = [math]::Abs($position.X - $script:State.ToolboxDragOrigin.X)
        $deltaY = [math]::Abs($position.Y - $script:State.ToolboxDragOrigin.Y)
        if ($deltaX -lt [System.Windows.SystemParameters]::MinimumHorizontalDragDistance -and
            $deltaY -lt [System.Windows.SystemParameters]::MinimumVerticalDragDistance) {
            return
        }

        $data = [System.Windows.DataObject]::new()
        $data.SetData('WpfTypeFullName', $sender.SelectedItem.FullName)
        [void][System.Windows.DragDrop]::DoDragDrop($sender, $data, [System.Windows.DragDropEffects]::Copy)
    })

    $ui.PreviewBorder.Add_DragOver({
        param($sender, $e)
        if ($e.Data.GetDataPresent('WpfTypeFullName')) {
            $e.Effects = [System.Windows.DragDropEffects]::Copy
            $e.Handled = $true
        }
    })

    $ui.PreviewBorder.Add_Drop({
        param($sender, $e)
        if (-not $e.Data.GetDataPresent('WpfTypeFullName')) {
            return
        }
        $fullName = [string]$e.Data.GetData('WpfTypeFullName')
        $item = $script:State.ToolboxItems | Where-Object FullName -eq $fullName | Select-Object -First 1
        if ($null -eq $item) {
            return
        }

        $canvas = Find-VisualElementByName -Root $ui.PreviewHost -Name 'DesignCanvas'
        if ($canvas -is [System.Windows.Controls.Canvas]) {
            $point = $e.GetPosition($canvas)
            $left = $point.X
            $top = $point.Y
        }
        else {
            $left = 20
            $top = 20
        }
        if ($ui.CheckSnapToGrid.IsChecked -eq $true) {
            $left = [math]::Round($left / 10) * 10
            $top = [math]::Round($top / 10) * 10
        }
        Add-ToolboxElementToDocument -Type $item.Type -Left $left -Top $top
        $e.Handled = $true
    })

    $ui.PreviewHost.Add_PreviewMouseLeftButtonDown({
        param($sender, $e)
        $element = Get-NamedFrameworkElementFromOriginalSource -OriginalSource $e.OriginalSource
        if ($null -eq $element) {
            return
        }
        Select-DesignerElement -Element $element

        if ($e.ClickCount -ge 2) {
            $defaultEvent = Get-DefaultDesignerEventName -Element $element
            if (-not [string]::IsNullOrWhiteSpace($defaultEvent)) {
                Generate-EventHandlerForName -EventName $defaultEvent
            }
            $e.Handled = $true
            return
        }

        if ($element.Parent -is [System.Windows.Controls.Canvas]) {
            $script:State.DesignerDragActive = $true
            $script:State.DesignerDragCanvas = $element.Parent
            $script:State.DesignerDragOrigin = $e.GetPosition($element.Parent)
            $left = [System.Windows.Controls.Canvas]::GetLeft($element)
            $top = [System.Windows.Controls.Canvas]::GetTop($element)
            if ([double]::IsNaN($left)) { $left = 0 }
            if ([double]::IsNaN($top)) { $top = 0 }
            $script:State.DesignerDragStartLeft = $left
            $script:State.DesignerDragStartTop = $top
            [void]$element.CaptureMouse()
        }
        $e.Handled = $true
    })

    $ui.PreviewHost.Add_PreviewMouseMove({
        param($sender, $e)
        if (-not $script:State.DesignerDragActive -or $e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) {
            return
        }
        $element = $script:State.SelectedRuntimeElement
        $canvas = $script:State.DesignerDragCanvas
        if ($element -isnot [System.Windows.FrameworkElement] -or $canvas -isnot [System.Windows.Controls.Canvas]) {
            return
        }

        $point = $e.GetPosition($canvas)
        $left = $script:State.DesignerDragStartLeft + ($point.X - $script:State.DesignerDragOrigin.X)
        $top = $script:State.DesignerDragStartTop + ($point.Y - $script:State.DesignerDragOrigin.Y)
        $left = [math]::Max(0, $left)
        $top = [math]::Max(0, $top)
        if ($ui.CheckSnapToGrid.IsChecked -eq $true) {
            $left = [math]::Round($left / 10) * 10
            $top = [math]::Round($top / 10) * 10
        }
        [System.Windows.Controls.Canvas]::SetLeft($element, $left)
        [System.Windows.Controls.Canvas]::SetTop($element, $top)
        $e.Handled = $true
    })

    $ui.PreviewHost.Add_PreviewMouseLeftButtonUp({
        param($sender, $e)
        if (-not $script:State.DesignerDragActive) {
            return
        }
        $element = $script:State.SelectedRuntimeElement
        if ($element -is [System.Windows.FrameworkElement]) {
            $left = [System.Windows.Controls.Canvas]::GetLeft($element)
            $top = [System.Windows.Controls.Canvas]::GetTop($element)
            if (-not [double]::IsNaN($left) -and -not [double]::IsNaN($top)) {
                Update-SelectedCanvasPosition -Left $left -Top $top
                Refresh-PropertyGrid
                Set-DesignerStatus -Message "Moved $($script:State.SelectedElementName) to $left, $top."
            }
            $element.ReleaseMouseCapture()
        }
        $script:State.DesignerDragActive = $false
        $script:State.DesignerDragCanvas = $null
        $e.Handled = $true
    })

    $ui.PropertyGrid.Add_SelectionChanged({
        $item = $ui.PropertyGrid.SelectedItem
        if ($null -eq $item) {
            return
        }
        $ui.PropertyNameText.Text = "$($item.Name)  [$($item.TypeName)]"
        $ui.PropertyValueText.Text = [string]$item.Value
    })
    $ui.ButtonApplyProperty.Add_Click({ Apply-SelectedProperty })
    $ui.PropertyValueText.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            Apply-SelectedProperty
            $e.Handled = $true
        }
    })

    $ui.EventGrid.Add_MouseDoubleClick({ Generate-SelectedEventHandler })

    $script:State.Window.Add_KeyDown({
        param($sender, $e)
        $ctrl = ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -ne 0
        if ($ctrl -and $e.Key -eq [System.Windows.Input.Key]::N) { New-XamlDesignerDocument; $e.Handled = $true; return }
        if ($ctrl -and $e.Key -eq [System.Windows.Input.Key]::O) { Open-XamlDesignerDocument; $e.Handled = $true; return }
        if ($ctrl -and $e.Key -eq [System.Windows.Input.Key]::S) { Save-XamlDesignerDocument; $e.Handled = $true; return }
        if ($ctrl -and $e.Key -eq [System.Windows.Input.Key]::D) { Duplicate-SelectedElement; $e.Handled = $true; return }
        if ($e.Key -eq [System.Windows.Input.Key]::Delete) { Delete-SelectedElement; $e.Handled = $true; return }
        if ($e.Key -eq [System.Windows.Input.Key]::F5) { [void](Apply-XamlEditorText); $e.Handled = $true; return }
    })
}

