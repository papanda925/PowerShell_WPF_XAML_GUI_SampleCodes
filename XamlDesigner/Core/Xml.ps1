function ConvertTo-FormattedXml {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Document
    )

    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Indent = $true
    $settings.IndentChars = '    '
    $settings.NewLineChars = [Environment]::NewLine
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
    $settings.OmitXmlDeclaration = $true

    $builder = [System.Text.StringBuilder]::new()
    $writer = [System.Xml.XmlWriter]::Create($builder, $settings)
    try {
        $Document.Save($writer)
    }
    finally {
        $writer.Close()
    }

    return $builder.ToString().Trim() + [Environment]::NewLine
}

function New-XmlDocumentFromText {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null

    $stringReader = [System.IO.StringReader]::new($Text)
    $xmlReader = [System.Xml.XmlReader]::Create($stringReader, $settings)
    try {
        $document = [System.Xml.XmlDocument]::new()
        $document.PreserveWhitespace = $false
        $document.XmlResolver = $null
        $document.Load($xmlReader)
        return $document
    }
    finally {
        $xmlReader.Close()
        $stringReader.Close()
    }
}

function Get-BlankXamlText {
    $path = Join-Path $script:State.BaseDirectory 'Templates\BlankWindow.xaml'
    if (Get-Command Read-DesignerTextFile -ErrorAction SilentlyContinue) {
        return Read-DesignerTextFile -Path $path
    }
    return [System.IO.File]::ReadAllText($path)
}

function Get-BlankCodeText {
    $path = Join-Path $script:State.BaseDirectory 'Templates\BlankWindow.ps1'
    if (Get-Command Read-DesignerTextFile -ErrorAction SilentlyContinue) {
        return Read-DesignerTextFile -Path $path
    }
    return [System.IO.File]::ReadAllText($path)
}

function Get-ElementNameFromNode {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Node
    )

    $name = $Node.GetAttribute('Name', $script:XamlNs)
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = $Node.GetAttribute('Name')
    }
    return $name
}

function Set-ElementNameOnNode {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Node,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $Node.RemoveAttribute('Name')
    $attribute = $Node.OwnerDocument.CreateAttribute('x', 'Name', $script:XamlNs)
    $attribute.Value = $Name
    [void]$Node.Attributes.SetNamedItem($attribute)
}

function Get-XamlElementByName {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name) -or $null -eq $script:State.XamlDocument) {
        return $null
    }

    foreach ($node in $script:State.XamlDocument.SelectNodes('//*')) {
        if ($node -isnot [System.Xml.XmlElement]) {
            continue
        }
        if ((Get-ElementNameFromNode -Node $node) -eq $Name) {
            return $node
        }
    }
    return $null
}

function Test-XamlNodeInSeparateNameScope {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlElement]$Node
    )

    $separateScopeNames = @(
        'ControlTemplate',
        'DataTemplate',
        'ItemsPanelTemplate',
        'HierarchicalDataTemplate',
        'Style',
        'Setter',
        'Trigger',
        'MultiTrigger',
        'DataTrigger',
        'MultiDataTrigger',
        'ResourceDictionary'
    )

    $current = $Node.ParentNode
    while ($current -is [System.Xml.XmlElement]) {
        if ($current.LocalName -in $separateScopeNames -or $current.LocalName -like '*.Resources') {
            return $true
        }
        $current = $current.ParentNode
    }

    return $false
}

function Get-AllNamedXamlElements {
    $result = [System.Collections.Generic.List[object]]::new()
    if ($null -eq $script:State.XamlDocument) {
        return $result
    }

    $root = $script:State.XamlDocument.DocumentElement
    foreach ($node in $script:State.XamlDocument.SelectNodes('//*')) {
        if ($node -isnot [System.Xml.XmlElement] -or $node -eq $root) {
            continue
        }

        if (Test-XamlNodeInSeparateNameScope -Node $node) {
            continue
        }

        $name = Get-ElementNameFromNode -Node $node
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $result.Add([pscustomobject]@{
                Name = $name
                ElementName = $node.LocalName
                Node = $node
            })
        }
    }

    return $result
}

function Get-WpfTypeByElementName {
    param(
        [Parameter(Mandatory)]
        [string]$ElementName
    )

    $known = @{
        Window = [System.Windows.Window]
        Border = [System.Windows.Controls.Border]
        Image = [System.Windows.Controls.Image]
        TextBlock = [System.Windows.Controls.TextBlock]
    }

    if ($known.ContainsKey($ElementName)) {
        return $known[$ElementName]
    }

    foreach ($item in $script:State.ToolboxItems) {
        if ($item.DisplayName -eq $ElementName) {
            return $item.Type
        }
    }

    foreach ($namespace in @('System.Windows.Controls', 'System.Windows.Shapes', 'System.Windows.Documents')) {
        $type = [Type]::GetType("$namespace.$ElementName, PresentationFramework", $false)
        if ($null -ne $type) {
            return $type
        }
    }

    return $null
}

function Test-XamlPreviewSafety {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Document
    )

    $blockedElements = @(
        'ObjectDataProvider',
        'XmlDataProvider'
    )

    foreach ($node in $Document.SelectNodes('//*')) {
        if ($node -isnot [System.Xml.XmlElement]) {
            continue
        }

        if ($node.NamespaceURI -eq $script:XamlNs -and $node.LocalName -in @('Code','FactoryMethod','Arguments')) {
            throw "Safe preview blocked x:$($node.LocalName). Loose XAML preview must not execute embedded code or factory-method construction."
        }

        if (
            -not [string]::IsNullOrWhiteSpace($node.NamespaceURI) -and
            $node.NamespaceURI -ne $script:PresentationNs -and
            $node.NamespaceURI -ne $script:XamlNs
        ) {
            throw "Safe preview blocked element '$($node.Name)' from non-standard namespace '$($node.NamespaceURI)'. Custom CLR controls are not loaded automatically."
        }

        if ($node.LocalName -in $blockedElements) {
            throw "Safe preview blocked '$($node.LocalName)' because it can load data or invoke methods during XAML object construction."
        }

        if ($node.LocalName -eq 'ResourceDictionary' -and $node.HasAttribute('Source')) {
            throw 'Safe preview blocked ResourceDictionary Source because external XAML dictionaries can load files or network resources. Inline the resources for preview.'
        }

        foreach ($attribute in @($node.Attributes)) {
            if ($attribute.Prefix -eq 'xmlns' -or $attribute.Name -eq 'xmlns') {
                continue
            }

            if (
                -not [string]::IsNullOrWhiteSpace($attribute.NamespaceURI) -and
                $attribute.NamespaceURI -notin @(
                    $script:XamlNs,
                    $script:McNs,
                    $script:DesignNs,
                    $script:PresentationNs,
                    'http://www.w3.org/XML/1998/namespace'
                )
            ) {
                throw "Safe preview blocked attribute '$($attribute.Name)' from namespace '$($attribute.NamespaceURI)'."
            }

            if ($attribute.NamespaceURI -eq $script:XamlNs -and $attribute.LocalName -in @('FactoryMethod','Arguments')) {
                throw "Safe preview blocked x:$($attribute.LocalName)."
            }

            $staticMatch = [regex]::Match(
                $attribute.Value,
                '\{x:(?:Static|Type)\s+(?<Prefix>[A-Za-z_][A-Za-z0-9_.-]*):'
            )
            if ($staticMatch.Success) {
                $prefix = $staticMatch.Groups['Prefix'].Value
                $resolvedNamespace = $node.GetNamespaceOfPrefix($prefix)
                if ($resolvedNamespace -like 'clr-namespace:*') {
                    throw "Safe preview blocked x:Static/x:Type reference to custom CLR namespace prefix '$prefix'."
                }
            }
        }
    }

    return $true
}

function Remove-PowerShellUnsupportedXamlAttributes {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Document
    )

    $root = $Document.DocumentElement
    if ($null -eq $root) {
        return
    }

    $root.RemoveAttribute('Class', $script:XamlNs)
    $root.RemoveAttribute('Ignorable', $script:McNs)

    foreach ($node in $Document.SelectNodes('//*')) {
        if ($node -isnot [System.Xml.XmlElement]) {
            continue
        }

        $attributesToRemove = [System.Collections.Generic.List[System.Xml.XmlAttribute]]::new()
        foreach ($attribute in @($node.Attributes)) {
            if ($attribute.NamespaceURI -eq $script:DesignNs) {
                $attributesToRemove.Add($attribute)
                continue
            }

            if (
                $attribute.LocalName -in @('Source','UriSource','NavigateUri') -and
                $attribute.Value -match '^(?i)(https?|ftp|file):|^(\\\\|//)'
            ) {
                # Avoid automatic network/file navigation while merely previewing XAML.
                $attributesToRemove.Add($attribute)
            }
        }
        foreach ($attribute in $attributesToRemove) {
            [void]$node.Attributes.Remove($attribute)
        }

        $type = Get-WpfTypeByElementName -ElementName $node.LocalName
        if ($null -eq $type) {
            continue
        }

        $eventNames = @(
            $type.GetEvents([System.Reflection.BindingFlags]'Public,Instance') |
            ForEach-Object Name
        )
        if ($eventNames.Count -eq 0) {
            continue
        }

        $eventAttributes = [System.Collections.Generic.List[System.Xml.XmlAttribute]]::new()
        foreach ($attribute in @($node.Attributes)) {
            if (
                [string]::IsNullOrWhiteSpace($attribute.NamespaceURI) -and
                $eventNames -contains $attribute.LocalName
            ) {
                $eventAttributes.Add($attribute)
            }
        }
        foreach ($attribute in $eventAttributes) {
            [void]$node.Attributes.Remove($attribute)
        }
    }
}
