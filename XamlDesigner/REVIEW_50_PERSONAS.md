# 50 Persona Self-Review Record

This file records the requested 50-pass review. These are **simulated reviewer personas** used to force different perspectives; they are not independent human reviewers.

| # | Simulated reviewer persona | Main finding | Disposition |
|---:|---|---|---|
| 1 | First-time PowerShell learner | Drag-and-drop alone is not an obvious way to add a control. | Fixed: Add selected control button and double-click insertion. |
| 2 | Excel/VBA user new to WPF | Raw WPF type names do not explain what a control is for. | Fixed: beginner descriptions for toolbox items. |
| 3 | Office administrator without Visual Studio | Startup should not require knowing STA terminology. | Fixed: startup script automatically relaunches in STA when possible. |
| 4 | Japanese beginner | Japanese UI/code can be damaged by Windows PowerShell 5.1 encoding behavior. | Fixed: UTF-8 BOM save plus UTF-8/legacy read detection. |
| 5 | Mouse/drag beginner | Precise drag-and-drop is difficult. | Fixed: button/double-click insertion and sensible default positions. |
| 6 | Keyboard-only beginner | Toolbox was effectively mouse-only. | Fixed: keyboard-selectable toolbox plus Add button; Canvas arrow movement retained. |
| 7 | Small corporate laptop user | 1500x920 with large minimum size was intimidating on small/high-DPI screens. | Fixed: smaller minimum dimensions and narrower side panes. |
| 8 | User creating a first button event | Alphabetical event lists hide common events. | Fixed: common events are sorted first. |
| 9 | User afraid of overwriting files | Save As can also overwrite the paired .ps1 unexpectedly. | Fixed: explicit paired-file overwrite confirmation. |
| 10 | User entering an invalid property | Property editor did not explain legal values. | Fixed: type/enum/boolean hints and rollback message. |
| 11 | Windows PowerShell 5.1 expert | UTF-8 without BOM can break Japanese .ps1 execution in 5.1. | Fixed: write XAML and PS1 with UTF-8 BOM. |
| 12 | PowerShell 7 expert | WPF STA requirements should not be a manual setup trap. | Fixed: automatic STA relaunch and dual-version CI. |
| 13 | WPF layout specialist | Single-child containers with property elements could be mistaken for already-filled containers. | Fixed: property elements are not treated as content children. |
| 14 | WPF NameScope specialist | Template/resource x:Name values must not become Window.FindName variables. | Fixed: separate NameScope nodes are excluded from generated references. |
| 15 | PowerShell code-behind reviewer | XAML and generated code must remain one logical edit during undo/redo. | Fixed: unified XAML+code+selection history snapshots. |
| 16 | Encoding/internationalization reviewer | Existing no-BOM legacy files need a reasonable fallback. | Fixed: strict UTF-8 first, system code page fallback only when invalid UTF-8. |
| 17 | WPF Binding specialist | Duplicating a subtree can leave ElementName bindings pointing at the original control. | Fixed: duplicated known name references are rewritten. |
| 18 | Toolbox UX reviewer | Showing every reflected WPF type first overwhelms beginners. | Fixed: Common category is default while All remains available. |
| 19 | Resource/template specialist | Template names and ResourceDictionary behaviors can differ from Window content. | Fixed: NameScope filtering; external ResourceDictionary Source is blocked in safe preview. |
| 20 | WPF memory/performance reviewer | Repeated preview reloads kept old Window references. | Fixed: previous preview Window is released/closed after successful replacement. |
| 21 | Application security engineer | ObjectDataProvider can invoke methods during XAML construction. | Fixed: blocked by safe preview. |
| 22 | Corporate network administrator | Merely previewing XAML should not automatically contact remote URLs/UNC paths. | Fixed: external Source/UriSource/NavigateUri values are stripped in the preview clone. |
| 23 | File-system reliability reviewer | Two-file saves can leave an inconsistent pair after a partial failure. | Fixed: both temporary files are written first and previous files are backed up/restored on failure. |
| 24 | Enterprise execution-policy reviewer | Documentation/CI should not normalize ExecutionPolicy Bypass. | Fixed in new startup guidance and CI commands; organizational policy is respected. |
| 25 | Untrusted-file reviewer | Custom clr-namespace elements should not instantiate automatically when a file is opened. | Fixed: custom CLR elements/attached attributes are blocked by safe preview. |
| 26 | Keyboard accessibility reviewer | Core add/move operations need non-mouse paths. | Fixed: Add button, double-click alternative, arrow movement, existing shortcuts. |
| 27 | Screen-reader reviewer | Unlabelled source/search/property controls are difficult to identify. | Fixed: AutomationProperties.Name added to key controls. |
| 28 | High-DPI reviewer | Fixed large minimum window dimensions reduce usability under scaling. | Fixed: lower minimum dimensions and flexible columns. |
| 29 | High-contrast reviewer | Designer chrome should avoid unnecessary hard-coded colors. | Improved: shell uses defaults/system border brush; white remains only where it represents the designed surface. |
| 30 | Cognitive-load reviewer | First-run UI lacked a short sequence of what to do next. | Fixed: Getting Started dialog, Common toolbox, contextual status text. |
| 31 | QA engineer | Critical behavior was reviewed manually but not locked in tests. | Fixed: Test-DesignerCore.ps1 added. |
| 32 | Regression-test engineer | Duplication, NameScope, encoding, and event cleanup need direct regression cases. | Fixed: dedicated core behavior checks. |
| 33 | CI maintainer | Only part of behavior was exercised across PowerShell versions. | Fixed: PowerShell 7 and Windows PowerShell 5.1 run repository/core/codegen/startup tests. |
| 34 | Maintainability reviewer | Safety/encoding logic should be explicit named helpers rather than repeated snippets. | Improved: Read-DesignerTextFile, Write-DesignerDocumentPair, Test-XamlPreviewSafety and related helpers. |
| 35 | Module-structure reviewer | Responsibilities should remain separated among Documents, Xml, Preview, Events, History, and UI. | Maintained: new logic was placed in the corresponding modules rather than one monolith. |
| 36 | Technical writer | README alone is too dense for a novice tutorial. | Fixed: Japanese getting-started guide added. |
| 37 | Internal trainer | A user should be able to learn the six basic steps without leaving the app. | Fixed: bilingual Getting Started message. |
| 38 | OSS maintainer | Repository has no explicit license, which makes reuse rights unclear. | Deferred: license choice is an owner/legal decision and was not selected automatically. |
| 39 | Backward-compatibility reviewer | Legacy ANSI PowerShell files should not be immediately corrupted on open. | Improved: fallback decoding for non-UTF-8 files, with standardized UTF-8 BOM on save. |
| 40 | Error-recovery reviewer | A failed preview should not blank the last working design. | Fixed: previous successful preview remains until a new preview succeeds. |
| 41 | Visual Studio XAML compatibility reviewer | presentation/options is a standard WPF namespace and should not be treated as custom code. | Fixed: standard presentation-options attributes are allowed. |
| 42 | Existing-sample user | Visual Studio x:Class/d:/mc: metadata should remain source-compatible while PowerShell previews work. | Preserved: unsupported build/design attributes are removed only from the runtime clone. |
| 43 | Drag-and-drop usability reviewer | Newly added advanced controls can be invisible or too small with generic defaults. | Improved: practical defaults for DataGrid, DatePicker, Calendar, GroupBox, ScrollViewer, Viewbox, UniformGrid, TabControl, etc. |
| 44 | Non-mouse corporate user | There must be a way to insert a control without drag/drop precision. | Fixed: Add selected control. |
| 45 | Property-editor novice | Grid.Row and DockPanel.Dock are not self-explanatory. | Fixed: attached-property help text and examples. |
| 46 | Event-programming novice | Double-click generation is useful but should clearly say where code was created. | Fixed: status guidance and event ordering/help text. |
| 47 | Generated-code safety reviewer | Deleting a control can leave executable handlers referencing missing variables. | Fixed: handlers for deleted subtree controls are disabled. |
| 48 | Data-loss reviewer | Simply deleting generated event blocks would also delete user-written logic inside them. | Fixed: deleted-control handlers are archived as commented ArchivedEvent blocks instead of discarded. |
| 49 | Product UX reviewer | A beginner needs a safe path from “empty window” to “saved working button” with minimal concepts. | Fixed: Common controls, descriptions, beginner dialog/guide, defaults, hints, and safer save flow. |
| 50 | Release-gate reviewer | Merge should require syntax, security regression, code generation, startup, PS5.1 and PS7 checks. | Implemented in CI; final merge is gated on successful workflow results. |

## Remaining intentional boundaries

The review did not convert the project into a complete Visual Studio clone. The following remain future work rather than hidden defects:

- visual resize handles/adorners;
- a graphical Grid row/column editor;
- syntax coloring and XAML completion;
- dedicated Style/Resource/Template designers;
- explicit user-approved custom-control assembly loading;
- multi-window/project explorer support.

## Review principle for beginners

Where ease-of-use and power conflicted, the review preferred a safe default with an advanced path still available. Examples include Common versus All toolbox categories, safe preview versus automatic custom CLR loading, and archiving deleted event code instead of silently discarding it.
