# PowerShell WPF XAML GUI Sample Codes / PowerShell XAML Designer

This repository is being refocused around a **PowerShell-only WPF/XAML GUI designer** for Windows.

The goal is to make it possible to create and maintain PowerShell WPF screens even in environments where Visual Studio, Blend, paid IDE add-ons, or third-party GUI designers cannot be installed or used.

The original WPF sample scripts are kept as compatibility/reference samples. The main tool is now under [`XamlDesigner`](./XamlDesigner/).

## PowerShell XAML Designer

The designer follows a two-file model:

```text
MyWindow.xaml   # UI / layout
MyWindow.ps1    # PowerShell control references, event registration, application logic
```

This is intentional. A standalone PowerShell `XamlReader` does not use the compiled C#/VB code-behind model that Visual Studio WPF projects use. Therefore the designer generates PowerShell event registration such as:

```powershell
[System.Windows.Controls.Button]$Button1 = $Window.FindName('Button1')

$Button1.Add_Click({
    param($sender, $e)

    # Add logic here.
})
```

instead of depending on `Click="Button1_Click"` in XAML.

### Current features

- PowerShell + WPF only; no Visual Studio and no third-party module required at runtime.
- New / Open / Save / Save As for paired `.xaml` and `.ps1` files.
- Runtime-discovered toolbox for public, instantiable WPF visual element types.
- Toolbox search plus a beginner-oriented Common category with short control descriptions.
- Drag-and-drop, double-click, or an explicit Add selected control button for inserting controls.
- Drag and drop from the toolbox to Canvas/Grid/StackPanel/DockPanel/WrapPanel/UniformGrid layouts and supported empty single-child containers such as Border and GroupBox.
- Direct mouse movement for controls whose parent is a `Canvas`.
- Arrow-key Canvas movement (1 px, or 10 px with Shift) plus optional 10-pixel mouse snap-to-grid.
- XAML document Outline, including selection/editing of the root Window.
- Selection of controls on the preview surface.
- Undo/redo for designer-side changes restores XAML and generated PowerShell together, while text editors keep native text undo/redo.
- Reflection-based property browser and property editing, including Canvas/Grid/DockPanel attached properties.
- Reflection-based event browser.
- Double-click an event to generate PowerShell event code.
- Double-click a control on the designer to generate its typical/default event (`Click`, `SelectionChanged`, `TextChanged`, etc.).
- XAML source editing, XML formatting, and well-formedness validation with line/position reporting.
- Live WPF preview through `System.Windows.Markup.XamlReader`.
- Preview-time removal of Visual Studio/Blend build-time attributes such as `x:Class`, `mc:Ignorable`, and `d:*`.
- Preview-time removal of XAML event attributes that cannot be resolved by standalone PowerShell, while preserving the source document.
- Automatic synchronization of named XAML controls into a generated control-reference region in the paired `.ps1` file.
- Generated event handlers are placed in a dedicated region before `$Window.ShowDialog()`, so handlers are registered before the UI runs.
- Existing user event code is not overwritten when control references are refreshed.
- Deleting controls archives their generated event handlers as comments instead of leaving broken references or silently discarding the code.
- Safe preview blocks risky loose-XAML constructs/custom CLR elements and prevents automatic external resource navigation.
- Save As warns before replacing an already-existing paired `.ps1` file; paired saves use temporary files/rollback and UTF-8 BOM for Windows PowerShell 5.1/Japanese compatibility.

### Start the designer

From a PowerShell prompt:

~~~powershell
.\XamlDesigner\Start-XamlDesigner.ps1
~~~

If the current process is not STA, the launcher attempts to relaunch the same PowerShell executable in STA mode automatically. It does not bypass the machine's execution policy.

Explicit launch examples:

~~~powershell
powershell.exe -NoProfile -STA -File .\XamlDesigner\Start-XamlDesigner.ps1
pwsh.exe -NoProfile -STA -File .\XamlDesigner\Start-XamlDesigner.ps1
~~~

For a Japanese beginner walkthrough, see [XamlDesigner/GETTING_STARTED.ja.md](./XamlDesigner/GETTING_STARTED.ja.md). The requested 50 simulated persona reviews are recorded in [XamlDesigner/REVIEW_50_PERSONAS.md](./XamlDesigner/REVIEW_50_PERSONAS.md).

## Design direction

Visual Studio's XML editor provides features such as XML syntax checking, schema-aware validation, IntelliSense, snippets, and document outlining. The PowerShell XAML Designer aims to provide the most useful subset for standalone PowerShell/WPF work without requiring a Visual Studio project.

The visual designer intentionally uses a `Canvas` as the default root layout because absolute positioning makes drag/move behavior deterministic. Existing `Grid`, `StackPanel`, `DockPanel`, `WrapPanel`, and `UniformGrid` layouts can still be opened and previewed, and controls can be added to supported root layout containers. Direct coordinate dragging is currently limited to `Canvas` parents.

See [`XamlDesigner/README.md`](./XamlDesigner/README.md) for architecture, workflow, limitations, and planned editor features.

## Existing samples

The original files remain available at the repository root as WPF/PowerShell examples:

- `WPF_CustomGraphicalInputBoxSample.*`
- `WPF_GraphicalDatePickerSample.*`
- `WPF_InkCanvas.ps1`
- `WPF_OCR_Sample.ps1`
- `WPF_SimpleWeatherFormSample/`

They are useful as real-world XAML compatibility samples for the designer.

## Microsoft references

- Visual Studio XML editor: https://learn.microsoft.com/visualstudio/xml-tools/xml-editor
- Editing XML files: https://learn.microsoft.com/visualstudio/xml-tools/how-to-edit-xml-files
- XML editor IntelliSense: https://learn.microsoft.com/visualstudio/xml-tools/xml-editor-intellisense-features
- WPF drag and drop: https://learn.microsoft.com/dotnet/desktop/wpf/advanced/drag-and-drop-overview
- WPF dependency properties: https://learn.microsoft.com/dotnet/desktop/wpf/properties/dependency-properties-overview
