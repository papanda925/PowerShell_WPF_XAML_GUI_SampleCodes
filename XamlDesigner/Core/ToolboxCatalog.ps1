function Get-WpfControlCatalog {
    $frameworkElementType = [System.Windows.FrameworkElement]
    $excluded = @(
        'System.Windows.Window',
        'System.Windows.Navigation.NavigationWindow',
        'System.Windows.Controls.Page'
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
            Type = $type
        }
    }

    return @($catalog | Sort-Object DisplayName, FullName)
}

function Refresh-ToolboxCatalog {
    $script:State.ToolboxItems = @(Get-WpfControlCatalog)
    Apply-ToolboxFilter
    Set-DesignerStatus -Message "Toolbox loaded $($script:State.ToolboxItems.Count) WPF element types discovered at runtime."
}

function Apply-ToolboxFilter {
    $search = $script:State.Ui.ToolboxSearch.Text
    $categoryItem = $script:State.Ui.ToolboxCategory.SelectedItem
    $category = 'All'
    if ($null -ne $categoryItem -and $null -ne $categoryItem.Content) {
        $category = [string]$categoryItem.Content
    }

    $filtered = $script:State.ToolboxItems
    if (-not [string]::IsNullOrWhiteSpace($search)) {
        $filtered = @($filtered | Where-Object {
            $_.DisplayName -like "*$search*" -or $_.FullName -like "*$search*"
        })
    }
    if ($category -ne 'All') {
        $filtered = @($filtered | Where-Object Category -eq $category)
    }
    $script:State.Ui.ToolboxList.ItemsSource = $filtered
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
