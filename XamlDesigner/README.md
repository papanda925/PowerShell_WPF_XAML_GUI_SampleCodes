# PowerShell XAML Designer

A standalone WPF/XAML visual editor implemented with PowerShell and Windows WPF.

## Why this exists

PowerShell can build useful Windows desktop tools with WPF and XAML, but the normal graphical WPF authoring experience is closely associated with Visual Studio / Blend. In managed corporate PCs, labs, lightweight admin environments, or personal setups, those tools may be unavailable or restricted.

This project therefore uses only components normally available to PowerShell on Windows:

- PowerShell
- `WindowsBase`
- `PresentationCore`
- `PresentationFramework`
- `System.Xml`
- WPF reflection APIs

There is no required NuGet package, PowerShell Gallery module, web service, or external executable.

## File model

A project is normally one pair of files:

```text
Example.xaml
Example.ps1
```

### XAML file

Owns UI structure and UI properties.

```xml
<Window ...>
    <Canvas x:Name="DesignCanvas">
        <Button x:Name="Button1"
                Canvas.Left="40"
                Canvas.Top="30"
                Width="110"
                Height="32"
                Content="Run" />
    </Canvas>
</Window>
```

### PowerShell code-behind

Loads XAML, resolves named controls, attaches events, and contains application logic.

```powershell
[System.Windows.Controls.Button]$Button1 = $Window.FindName('Button1')

$Button1.Add_Click({
    param($sender, $e)

    [System.Windows.MessageBox]::Show('Hello')
})
```

The designer maintains only explicit marker regions for generated metadata/control references. Event blocks and the rest of the script stay editable.

## Main UI

### Toolbox

The toolbox is not a small hard-coded list. At startup, PowerShell reflects over WPF assemblies and discovers public, non-abstract `FrameworkElement` types that:

- belong to standard WPF control/shape namespaces,
- can be instantiated with a public parameterless constructor,
- are suitable to appear as visual elements.

Types are grouped as Controls, Panels, Shapes, Decorators, and Other. Search filters by short and fully-qualified type name.

Root-only objects such as another `Window` are intentionally excluded from drag/drop insertion.

### Designer

For a new document, the default root content is:

```xml
<Canvas x:Name="DesignCanvas" Background="White" />
```

Drag a toolbox item onto the preview to create a named XAML element. The new control receives practical default size/content attributes so that it is visible immediately.

Controls inside a `Canvas` can be moved directly by mouse. Their `Canvas.Left` and `Canvas.Top` values are written back to the XML document. Arrow keys nudge a selected Canvas control by 1 pixel; hold Shift for 10 pixels.

Supported panels can also receive toolbox drops. Empty `Border`, `GroupBox`, `ScrollViewer`, and `Viewbox` elements can accept a single child. The Outline tab displays the complete XAML tree, including the root `Window`, so Window properties can be edited without switching to source.

### XAML source

The XAML tab is the authoritative source editor.

`Validate / Apply` performs two stages:

1. XML well-formedness parsing (`System.Xml.XmlDocument`).
2. WPF runtime loading through `XamlReader` after creating an in-memory PowerShell-safe preview clone.

XML errors report line and position when available.

`Format XML` rewrites indentation only after XML parsing succeeds.

### Properties

Selecting a visual element uses .NET reflection and `TypeDescriptor` to enumerate public read/write properties that can reasonably be represented as strings.

High-value WPF properties are sorted near the top. Attached properties such as `Canvas.Left`, `Canvas.Top`, `Grid.Row`, `Grid.Column`, row/column spans, `DockPanel.Dock`, and `Panel.ZIndex` are surfaced when applicable.

A property change is first applied to the XML DOM and then reloaded into WPF. If WPF rejects the value, the XML change is rolled back.

### Events

The event tab enumerates public instance events from the selected WPF type.

Double-click an event row to generate a block such as:

```powershell
$Button1.Add_Click({
    param($sender, $e)

    # TODO: Add Click logic for Button1.
})
```

Double-clicking a control on the designer chooses a typical event when possible, in this order:

1. `Click`
2. `Checked`
3. `SelectionChanged`
4. `TextChanged`
5. `ValueChanged`
6. `SelectedDateChanged`
7. `MouseDoubleClick`
8. `Loaded`

The same control/event combination is not generated twice. Generated handlers are inserted into a dedicated event region before `$Window.ShowDialog()`, which guarantees that handlers are registered before the window is shown.

## Visual Studio / Blend XAML compatibility

XAML exported from Visual Studio can contain information intended for a compiled WPF project, for example:

- `x:Class`
- `mc:Ignorable`
- `d:*` design-time attributes
- event attributes such as `Click="Button_Click"`

A standalone PowerShell `XamlReader` has no compiled code-behind class that can resolve those handlers. The designer therefore creates an in-memory clone for preview and removes unsupported build/design attributes from that clone only.

The paired PowerShell template uses the same principle at runtime. UI structure remains in `.xaml`; executable event registration remains in `.ps1`.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+N` | New pair |
| `Ctrl+O` | Open XAML |
| `Ctrl+S` | Save pair |
| `Ctrl+Z` | Undo designer change, or native text undo while editing text |
| `Ctrl+Y` | Redo designer change, or native text redo while editing text |
| `Ctrl+D` | Duplicate selected control |
| `Delete` | Delete selected control |
| Arrow keys | Move selected Canvas control by 1 px |
| `Shift` + Arrow keys | Move selected Canvas control by 10 px |
| `F5` | Validate / Apply XAML |

## Current boundaries

This is a useful visual designer foundation, not yet a complete clone of Visual Studio's XML/XAML tooling.

The current implementation does **not** yet provide:

- syntax coloring,
- XAML IntelliSense / attribute completion,
- XSD schema completion,
- collapsible document outlining,
- visual Grid row/column editors,
- resize handles / adorners,
- binding editors,
- resource/style/template designers,
- custom control assembly loading,
- a project explorer.

It can still open and preview many existing standard-WPF XAML files. Drag/move behavior is most complete with `Canvas` layout. Nonvisual XAML objects such as brushes, transforms, resources, bindings, styles, and templates are edited in source at this stage rather than exposed as toolbox controls.

## Architecture

```text
XamlDesigner/
├─ Start-XamlDesigner.ps1       Entry point / WPF bootstrap
├─ XamlDesigner.xaml            The designer's own UI
├─ XamlDesigner.Core.psm1       Editor state, reflection, XML DOM, preview, D&D, properties, events
├─ README.md
└─ Templates/
   ├─ BlankWindow.xaml           New-document UI template
   └─ BlankWindow.ps1            New-document PowerShell runtime template
```

The designer itself follows the same architecture it promotes: XAML for the screen and PowerShell for the behavior.

## Recommended next milestones

The next editor features with the highest value are:

1. WPF adorners for resize handles and selection rectangle.
2. Grid row/column visual editor.
3. XAML token coloring and tag/attribute completion driven by reflected WPF metadata.
4. Resource/style/template tree editor.
5. Custom assembly loading so third-party WPF controls can appear in the toolbox.
6. Project folder mode for multiple `.xaml` / `.ps1` pairs.

These can remain PowerShell-only; no C# helper assembly is required for the core design.
