# はじめての PowerShell XAML Designer

このページは、PowerShell や WPF/XAML にまだ慣れていない方向けの手順です。

## 1. まず知っておくこと

このツールは Windows の WPF を使うため、**Windows 専用**です。

Visual Studio や Blend、PowerShell Gallery の追加モジュールは必要ありません。基本的に Windows と PowerShell の機能だけで動作します。

画面と処理は、次の2ファイルに分けます。

~~~text
MyWindow.xaml   ← 画面・レイアウト・プロパティ
MyWindow.ps1    ← ボタンのクリック等のイベント・処理
~~~

この2ファイルは同じフォルダーに置き、同じ基本ファイル名で扱います。

## 2. 起動する

リポジトリのフォルダーで PowerShell を開き、次を実行します。

~~~powershell
.\XamlDesigner\Start-XamlDesigner.ps1
~~~

WPFに必要なSTAモードでなかった場合、起動スクリプトが同じPowerShellをSTAモードで自動的に起動し直します。

会社PCで実行ポリシーによってスクリプトが禁止されている場合は、組織のルールや管理者の案内に従ってください。ツール側から実行ポリシーを無理に回避することはしません。

## 3. 最初のボタンを置く

1. 左側の **Toolbox** を開く。
2. Category は最初 **Common** になっている。
3. **Button** を選ぶ。
4. **Add selected control** を押す。
   - Button をダブルクリックしても追加可能。
   - Designerへドラッグ＆ドロップしても追加可能。
5. 中央のDesignerに Button1 が表示される。

初心者の場合、最初は Canvas レイアウトのままで問題ありません。マウスや矢印キーで部品を自由に移動できます。

## 4. ボタンの文字を変える

1. Designer上の Button1 をクリック。
2. 右側の **Properties** を開く。
3. Content を選ぶ。
4. 下の入力欄へ、たとえば「実行」と入力。
5. **Apply property** を押す。

プロパティを選ぶと、入力欄の下に型や候補値のヒントが表示されます。

たとえば HorizontalAlignment のような列挙型では、使用可能な候補が表示されます。

## 5. ボタンを押したときの処理を作る

もっとも簡単な方法は、Designer上のボタンを**ダブルクリック**することです。

Buttonの場合は代表イベントである Click が選ばれ、PowerShellタブに次のようなコードが生成されます。

~~~powershell
# <XamlDesigner:Event Control="Button1" Name="Click">
${Button1}.Add_Click({
    param($sender, $e)

    # TODO: Add Click logic for Button1 here.
})
# </XamlDesigner:Event>
~~~

たとえば、TODO部分を次のように変更できます。

~~~powershell
[System.Windows.MessageBox]::Show('こんにちは')
~~~

イベント一覧から作りたい場合は、右側の **Events** タブを開き、イベント名をダブルクリックします。初心者がよく使うイベントは上のほうに表示されます。

## 6. 保存する

Ctrl+S、または File → Save を使います。

初回はXAMLファイル名を指定します。たとえば、

~~~text
SampleWindow.xaml
SampleWindow.ps1
~~~

の2ファイルが保存されます。

Windows PowerShell 5.1で日本語が文字化けしにくいよう、保存時はUTF-8 BOM付きで書き込みます。

Save As時に同名の .ps1 がすでに存在する場合は、上書き前に確認されます。

保存中に2ファイルの片方でエラーが起きた場合は、可能な限り保存前のペアへ戻す処理を行います。

## 7. 作成した画面を実行する

保存した .ps1 を実行します。

~~~powershell
powershell.exe -NoProfile -STA -File .\SampleWindow.ps1
~~~

PowerShell 7の場合:

~~~powershell
pwsh.exe -NoProfile -STA -File .\SampleWindow.ps1
~~~

## 8. よく使う部品

| 部品 | 用途 |
|---|---|
| Button | ボタン |
| TextBlock | 説明文や結果表示 |
| TextBox | 文字入力 |
| CheckBox | ON/OFF選択 |
| RadioButton | 複数候補から1つ選択 |
| ComboBox | ドロップダウン |
| ListBox | 一覧 |
| DataGrid | 表形式 |
| DatePicker | 日付入力 |
| ProgressBar | 進捗表示 |
| Image | 画像 |
| Canvas | 自由配置 |
| Grid | 行・列を使った本格的な配置 |
| StackPanel | 縦または横に順番に配置 |
| Border | 枠・背景・余白を付ける |

Toolboxで部品を選択すると、その部品の簡単な説明も表示されます。

## 9. Canvasでの移動

Canvas上の部品は次の方法で移動できます。

- マウスでドラッグ
- 矢印キー: 1px
- Shift + 矢印キー: 10px

Snap 10 px がONの場合、マウス移動やドロップ位置が10px単位に揃います。

## 10. Undo / Redo

- Ctrl+Z: Undo
- Ctrl+Y: Redo

Designerの変更では、XAMLだけでなくDesignerが生成・変更したPowerShellコードも一緒に戻すようにしています。

XAMLソースやPowerShellコードのテキストボックスへ直接入力している最中は、通常のテキスト編集のUndo/Redoとして動作します。

## 11. コントロールを削除するとイベントはどうなるか

コントロールを削除したとき、そのコントロール用にDesignerが生成したイベントコードをそのまま残すと、存在しない変数を参照して実行エラーになります。

一方、イベント内に自分で書いた処理を消してしまうのも危険です。

そのため、イベントコードは削除せず、**コメント化して ArchivedEvent として保存**します。

必要ならそこからコードをコピーできます。間違えて削除した直後なら Ctrl+Z でも戻せます。

## 12. Safe Previewについて

XAMLは単なる見た目のXMLとは限らず、読み込み時に.NETオブジェクトを生成します。

そのためDesignerのプレビューでは、安全側に次を制限します。

- ObjectDataProvider
- XmlDataProvider
- カスタム clr-namespace: のコントロールを自動生成するXAML
- 外部 ResourceDictionary Source
- 一部の外部URL/UNCパスを自動読込する属性
- x:Code やファクトリメソッド構築

Visual Studioが付けるだけで実際には未使用の xmlns:local="clr-namespace:..." 宣言は、標準WPF部品だけのXAMLであれば許容します。

この制限は**Designerがファイルを開いただけで意図しないコードや外部リソースを読み込まないため**のものです。

## 13. XAMLエラーが出たら

まず **XAML source** タブを開きます。

- **Validate / Apply**: XAMLを検査してプレビュー更新
- **Format XML**: XMLとして正しければ整形
- F5: Validate / Apply

失敗しても、直前に表示できていたプレビューは可能な限り残します。

プロパティ編集で不正な値を入れた場合も、変更前のXAMLとPowerShellへ戻してからエラーを表示します。

## 14. 最初は触らなくてよいもの

初心者の段階では、次は後回しで構いません。

- ControlTemplate / DataTemplate
- ResourceDictionary
- Bindingの複雑な設定
- Style / Trigger
- Gridの複雑なRow/Column定義

まずは Canvas + Button + TextBox + TextBlock の組み合わせから始めると分かりやすいです。

## 15. まだ実装していない主な機能

現時点ではVisual Studioの完全な代替ではありません。

今後の候補:

- リサイズハンドル
- Grid行・列のGUI編集
- XAML入力補完
- XAML構文色分け
- Style / Resource / Templateの専用GUI
- カスタムコントロールを安全に明示ロードする仕組み
- 複数画面をまとめるプロジェクト管理

現在の目標は、**Visual Studioを導入できない環境でも、標準WPF/XAMLの画面とPowerShell処理を分離して、できるだけGUIで作成できること**です。
