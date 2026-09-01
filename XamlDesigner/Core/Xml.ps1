function ConvertTo-FormattedXml {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Document
    )

    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Indent = $true
    $settings.IndentChars = '    '
    $settings.NewLineChars = "`r`n"
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

    return $builder.ToString().Trim() + "`r`n"
}

function New-XmlDocumentFromText {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    # Treat XAML as data. DTD processing and external resource resolution are
    # disabled explicitly so opening a document never performs XML network/file
    # resolution behind the user's back.
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
    return Get-Content -LiteralPath $path -Raw
}

function Get-BlankCodeText {
    $path = Join-Path $script:State.BaseDirectory 'Templates\BlankWindow.ps1'
    return Get-Content -LiteralPath $path -Raw
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

function Get-AllNamedXamlElements {
    $result = [System.Collections.Generic.List[object]]::new()
    if ($null -eq $script:State.XamlDocument) {
        return $result
    }

    $root = $script:State.XamlDocument.DocumentElement
    foreach ($node in $script:State.XamlDocument.SelectNodes('//*')) {
        if ($node -isnot [System.Xml.XmlElement]) {
            continue
        }
        if ($node -eq $root) {
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

function Remove-PowerShellUnsupportedXamlAttributes {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Document
    )

    $root = $Document.DocumentElement
    if ($null -eq $root) {
        return
    }

    # x:Class and mc:Ignorable are design/build-time concepts. PowerShell's
    # standalone XamlReader does not require them.
    $root.RemoveAttribute('Class', $script:XamlNs)
    $root.RemoveAttribute('Ignorable', $script:McNs)

    foreach ($node in $Document.SelectNodes('//*')) {
        if ($node -isnot [System.Xml.XmlElement]) {
            continue
        }

        # Remove d:* design-time attributes only from the preview clone.
        $attributesToRemove = [System.Collections.Generic.List[System.Xml.XmlAttribute]]::new()
        foreach ($attribute in @($node.Attributes)) {
            if ($attribute.NamespaceURI -eq $script:DesignNs) {
                $attributesToRemove.Add($attribute)
            }
        }
        foreach ($attribute in $attributesToRemove) {
            [void]$node.Attributes.Remove($attribute)
        }

        # Visual Studio can emit Click="Handler" style attributes. Those
        # handlers cannot be resolved by a standalone PowerShell XamlReader,
        # because PowerShell wires events from the .ps1 code-behind instead.
        $type = Get-WpfTypeByElementName -ElementName $node.LocalName
        if ($null -eq $type) {
            continue
        }

        $eventNames = @($type.GetEvents([System.Reflection.BindingFlags]'Public,Instance') | ForEach-Object Name)
        if ($eventNames.Count -eq 0) {
            continue
        }

        $eventAttributes = [System.Collections.Generic.List[System.Xml.XmlAttribute]]::new()
        foreach ($attribute in @($node.Attributes)) {
            if ([string]::IsNullOrWhiteSpace($attribute.NamespaceURI) -and $eventNames -contains $attribute.LocalName) {
                $eventAttributes.Add($attribute)
            }
        }
        foreach ($attribute in $eventAttributes) {
            [void]$node.Attributes.Remove($attribute)
        }
    }
}
