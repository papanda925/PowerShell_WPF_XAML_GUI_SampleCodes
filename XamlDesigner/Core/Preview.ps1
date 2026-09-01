function Get-RuntimePreviewDocument {
    $clone = [System.Xml.XmlDocument]$script:State.XamlDocument.CloneNode($true)
    Remove-PowerShellUnsupportedXamlAttributes -Document $clone
    return $clone
}

function Find-VisualElementByName {
    param(
        [Parameter(Mandatory)]
        [System.Windows.DependencyObject]$Root,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($Root -is [System.Windows.FrameworkElement]) {
        if ($Root.Name -eq $Name) {
            return $Root
        }

        # FindName is fast when the element belongs to this namescope.
        try {
            $named = $Root.FindName($Name)
            if ($named -is [System.Windows.FrameworkElement]) {
                return $named
            }
        }
        catch {
            # Continue with tree traversal; not every element owns a namescope.
        }
    }

    # Prefer the visual tree, but not every WPF DependencyObject is a Visual.
    try {
        $count = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Root)
        for ($i = 0; $i -lt $count; $i++) {
            $child = [System.Windows.Media.VisualTreeHelper]::GetChild($Root, $i)
            $match = Find-VisualElementByName -Root $child -Name $Name
            if ($null -ne $match) {
                return $match
            }
        }
    }
    catch {
        # Fall through to LogicalTreeHelper.
    }

    try {
        foreach ($child in [System.Windows.LogicalTreeHelper]::GetChildren($Root)) {
            if ($child -isnot [System.Windows.DependencyObject]) {
                continue
            }
            $match = Find-VisualElementByName -Root $child -Name $Name
            if ($null -ne $match) {
                return $match
            }
        }
    }
    catch {
        # Some templated/content objects expose neither traversable tree.
    }

    return $null
}

function Get-NamedFrameworkElementFromOriginalSource {
    param(
        [Parameter(Mandatory)]
        [object]$OriginalSource
    )

    $current = $OriginalSource
    while ($null -ne $current) {
        if ($current -is [System.Windows.FrameworkElement] -and -not [string]::IsNullOrWhiteSpace($current.Name)) {
            if ($null -ne (Get-XamlElementByName -Name $current.Name)) {
                return $current
            }
        }

        if ($current -isnot [System.Windows.DependencyObject]) {
            break
        }

        $parent = $null
        try {
            $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($current)
        }
        catch {
            # ContentElements are not Visuals.
        }

        if ($null -eq $parent) {
            try {
                $parent = [System.Windows.LogicalTreeHelper]::GetParent($current)
            }
            catch {
                $parent = $null
            }
        }

        if ($null -eq $parent) {
            break
        }
        $current = $parent
    }
    return $null
}

function Refresh-XamlTextFromDocument {
    $script:State.Ui.XamlEditor.Text = ConvertTo-FormattedXml -Document $script:State.XamlDocument
}

function Refresh-Preview {
    param(
        [switch]$KeepSelection
    )

    $selectionName = $script:State.SelectedElementName
    try {
        $runtimeDocument = Get-RuntimePreviewDocument
        $reader = [System.Xml.XmlNodeReader]::new($runtimeDocument)
        try {
            $loadedRoot = [System.Windows.Markup.XamlReader]::Load($reader)
        }
        finally {
            $reader.Close()
        }

        if ($loadedRoot -isnot [System.Windows.Window]) {
            throw 'The root XAML element must be a WPF Window for this designer.'
        }

        $content = $loadedRoot.Content
        $loadedRoot.Content = $null

        $host = $script:State.Ui.PreviewHost
        $host.Children.Clear()
        if ($null -ne $content) {
            [void]$host.Children.Add($content)
        }

        $width = $loadedRoot.Width
        $height = $loadedRoot.Height
        if ([double]::IsNaN($width) -or $width -lt 200) { $width = 800 }
        if ([double]::IsNaN($height) -or $height -lt 150) { $height = 500 }
        $script:State.Ui.PreviewBorder.Width = $width
        $script:State.Ui.PreviewBorder.Height = $height

        $script:State.SelectedRuntimeElement = $null
        if ($KeepSelection -and -not [string]::IsNullOrWhiteSpace($selectionName)) {
            $runtime = Find-VisualElementByName -Root $host -Name $selectionName
            if ($null -ne $runtime) {
                $script:State.SelectedRuntimeElement = $runtime
            }
            else {
                $script:State.SelectedElementName = $null
            }
        }

        Refresh-SelectionPanels
        Set-DesignerStatus -Message 'XAML preview updated successfully.'
        return $true
    }
    catch {
        Set-DesignerStatus -Message ("XAML preview error: " + $_.Exception.Message)
        return $false
    }
}

function Update-DocumentCaption {
    $display = 'Untitled.xaml'
    if (-not [string]::IsNullOrWhiteSpace($script:State.CurrentXamlPath)) {
        $display = Split-Path -Leaf $script:State.CurrentXamlPath
    }
    $script:State.Ui.DocumentText.Text = $display
    $script:State.Window.Title = "PowerShell XAML Designer - $display"
}
