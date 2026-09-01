function Get-WpfControlBeginnerDescription {
    param(
        [Parameter(Mandatory)]
        [Type]$Type
    )

    $descriptions = @{
        Button = 'Clickable command button. A good first control for generating a Click event.'
        Label = 'Short label for describing another input control.'
        TextBlock = 'Lightweight text display for headings, instructions, or results.'
        TextBox = 'Editable text input. Use Text or TextChanged when you need user input.'
        PasswordBox = 'Password-style input that hides typed characters.'
        CheckBox = 'On/off choice that can be checked independently.'
        RadioButton = 'One choice in a mutually exclusive group.'
        ComboBox = 'Drop-down list for choosing one item.'
        ListBox = 'List that allows one or more items to be selected.'
        ListView = 'Flexible list with richer item display than ListBox.'
        TreeView = 'Hierarchical tree for folders, categories, and nested data.'
        DataGrid = 'Table-style control for rows and columns of data.'
        Slider = 'Numeric value selector that the user drags.'
        ProgressBar = 'Read-only visual indicator for progress.'
        DatePicker = 'Date entry control with a calendar drop-down.'
        Calendar = 'Full calendar control for choosing dates.'
        Image = 'Displays an image. Use local files carefully when sharing the XAML.'
        Border = 'Single-child container that adds a border, background, or padding.'
        GroupBox = 'Single-child container with a visible heading.'
        ScrollViewer = 'Single-child container that adds scrolling.'
        Viewbox = 'Single-child container that scales its content.'
        Canvas = 'Free-positioning panel. Best choice for drag-and-drop beginner layouts.'
        Grid = 'Row-and-column layout panel. Best general-purpose WPF layout.'
        StackPanel = 'Places children in a vertical or horizontal line.'
        WrapPanel = 'Places children in a line and wraps when space runs out.'
        DockPanel = 'Docks children to Top, Bottom, Left, or Right.'
        UniformGrid = 'Grid where every cell has the same size.'
        TabControl = 'Shows several pages of content as tabs.'
        Rectangle = 'Rectangle shape. Set Fill, Stroke, Width, and Height.'
        Ellipse = 'Ellipse or circle shape. Set Fill, Stroke, Width, and Height.'
        Line = 'Straight line shape controlled by X1, Y1, X2, and Y2.'
    }

    if ($descriptions.ContainsKey($Type.Name)) {
        return $descriptions[$Type.Name]
    }

    if ([System.Windows.Controls.Panel].IsAssignableFrom($Type)) {
        return 'WPF layout panel. Select it before adding child controls when you want to target this container.'
    }
    if ([System.Windows.Controls.Decorator].IsAssignableFrom($Type)) {
        return 'WPF decorator/container. Some decorators accept only one child.'
    }
    if ([System.Windows.Shapes.Shape].IsAssignableFrom($Type)) {
        return 'WPF vector shape. Adjust its size, Stroke, Fill, and other drawing properties.'
    }
    if ([System.Windows.Controls.Control].IsAssignableFrom($Type)) {
        return 'Standard WPF control. Select it to inspect editable properties and available events.'
    }

    return 'Advanced WPF visual element. It may require XAML knowledge or additional child content.'
}

function Get-WpfControlCatalog {
    $frameworkElementType = [System.Windows.FrameworkElement]
    $excluded = @(
        'System.Windows.Window',
        'System.Windows.Navigation.NavigationWindow',
        'System.Windows.Controls.Page'
    )

    $commonTypeNames = @(
        'Button','Label','TextBlock','TextBox','PasswordBox','CheckBox','RadioButton',
        'ComboBox','ListBox','ListView','TreeView','DataGrid','Slider','ProgressBar',
        'DatePicker','Calendar','Image','Border','GroupBox','ScrollViewer','Viewbox',
        'Canvas','Grid','StackPanel','WrapPanel','DockPanel','UniformGrid','TabControl',
        'Rectangle','Ellipse','Line'
    )

    $assemblies = @(
        [System.Windows.Controls.Control].Assembly,
        [System.Windows.Controls.Panel].Assembly,
        [System.Windows.Shapes.Shape].Assembly,
        [System.Windows.FrameworkElement].Assembly
    ) | Select-Object -Unique

    $types = [System.Collections.Generic.List[Type]]::new()
    foreach ($assembly in $assemblies) {
        foreach ($type in $assembly.GetTypes()) {
            if (-not $type.IsPublic -or $type.IsAbstract -or $type.IsGenericTypeDefinition) {
                continue
            }
            if (-not $frameworkElementType.IsAssignableFrom($type)) {
                continue
            }
            if ($excluded -contains $type.FullName) {
                continue
            }
            if ($null -eq $type.GetConstructor([Type]::EmptyTypes)) {
                continue
            }
            if (-not ($type.Namespace -like 'System.Windows.Controls*' -or $type.Namespace -eq 'System.Windows.Shapes')) {
                continue
            }
            if (-not $types.Contains($type)) {
                $types.Add($type)
            }
        }
    }

    $catalog = foreach ($type in $types) {
        $category = 'Other'
        if ([System.Windows.Controls.Panel].IsAssignableFrom($type)) {
            $category = 'Panels'
        }
        elseif ([System.Windows.Shapes.Shape].IsAssignableFrom($type)) {
            $category = 'Shapes'
        }
        elseif ([System.Windows.Controls.Decorator].IsAssignableFrom($type)) {
            $category = 'Decorators'
        }
        elseif ([System.Windows.Controls.Control].IsAssignableFrom($type)) {
            $category = 'Controls'
        }

        [pscustomobject]@{
            DisplayName = $type.Name
            FullName = $type.FullName
            Category = $category
            IsCommon = $commonTypeNames -contains $type.Name
            Description = Get-WpfControlBeginnerDescription -Type $type
            Type = $type
        }
    }

    return @($catalog | Sort-Object @{ Expression = { if ($_.IsCommon) { 0 } else { 1 } } }, DisplayName, FullName)
}

function Refresh-ToolboxCatalog {
    $script:State.ToolboxItems = @(Get-WpfControlCatalog)
    Apply-ToolboxFilter
    Set-DesignerStatus -Message "Toolbox loaded $($script:State.ToolboxItems.Count) WPF element types. Common beginner controls are shown first."
}

function Apply-ToolboxFilter {
    $search = $script:State.Ui.ToolboxSearch.Text
    $categoryItem = $script:State.Ui.ToolboxCategory.SelectedItem
    $category = 'Common'
    if ($null -ne $categoryItem -and $null -ne $categoryItem.Content) {
        $category = [string]$categoryItem.Content
    }

    $filtered = $script:State.ToolboxItems
    if (-not [string]::IsNullOrWhiteSpace($search)) {
        $filtered = @($filtered | Where-Object {
            $_.DisplayName -like "*$search*" -or
            $_.FullName -like "*$search*" -or
            $_.Description -like "*$search*"
        })
    }

    if ($category -eq 'Common') {
        $filtered = @($filtered | Where-Object IsCommon)
    }
    elseif ($category -ne 'All') {
        $filtered = @($filtered | Where-Object Category -eq $category)
    }

    $script:State.Ui.ToolboxList.ItemsSource = $filtered

    if ($filtered.Count -eq 0) {
        $script:State.Ui.ToolboxHelpText.Text = 'No controls match the current search/filter.'
    }
    elseif ($null -eq $script:State.Ui.ToolboxList.SelectedItem) {
        $script:State.Ui.ToolboxHelpText.Text = 'Select a control to see what it is used for. Double-click or press Add selected control to insert it.'
    }
}

function New-UniqueControlName {
    param(
        [Parameter(Mandatory)]
        [string]$BaseName
    )

    $safeBase = $BaseName -replace '[^A-Za-z0-9_]', ''
    if ([string]::IsNullOrWhiteSpace($safeBase)) {
        $safeBase = 'Control'
    }
    if ($safeBase[0] -match '[0-9]') {
        $safeBase = '_' + $safeBase
    }

    $index = 1
    do {
        $candidate = "$safeBase$index"
        $index++
    } while ($null -ne (Get-XamlElementByName -Name $candidate))
    return $candidate
}
