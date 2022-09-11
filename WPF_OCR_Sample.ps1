Add-Type -AssemblyName PresentationFramework
Add-Type -Assembly System.Windows.Forms #for messagebox
[xml]$xaml='   
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="WPF_OCR_Sample" Height="400" Width="500"  >
  <ScrollViewer HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto">
  <Grid>
    <DockPanel LastChildFill="False">
      <StackPanel DockPanel.Dock="Top" Orientation="Horizontal">
        <Button Name="ButtonImageFileSelect" Margin="5,5,5,5">イメージファイル選択</Button>
        <Button Name="ButtonDoOCR" Margin="5,5,5,5" >OCR（文字認識）</Button>
      </StackPanel>
      <StackPanel DockPanel.Dock="Top" Orientation="Horizontal">
        <TextBlock Name="FileName" Text="FileName"   Grid.Row="6" Grid.Column="0" Grid.RowSpan="2" Grid.ColumnSpan="3" FontSize="20"
                   Margin="5,5,5,5" HorizontalAlignment="Left" VerticalAlignment="Center"/>
      </StackPanel>
      <StackPanel DockPanel.Dock="left">
        <Label Content="ターゲット画像" Background="Red" Foreground="White"></Label>
        <Image Name="OCRImage" Source=""  Margin="5,5,5,5" />
      </StackPanel>
      <StackPanel DockPanel.Dock="right">
        <Label Content="OCR（文字認識）の結果" Background="Blue" Foreground="White"></Label>
        <TextBox Name="MultiLineTextBox" TextWrapping="Wrap"  AcceptsReturn="True"
          VerticalScrollBarVisibility="Visible"></TextBox>
      </StackPanel>
    </DockPanel>
  </Grid>
  </ScrollViewer>
</Window>
' 

#以下、開発サイトのソースを流用　コメントに日本語訳つき：https://github.com/TobiasPSP/PsOcr
# make sure all required assemblies are loaded BEFORE any class definitions use them:
#クラス定義がそれらを使用する前に、必要なすべてのアセンブリがロードされていることを確認してください
try
{
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
    
  # WinRT assemblies are loaded indirectly:
  # WinRT アセンブリが間接的に読み込まれる:
  $null = [Windows.Storage.StorageFile,                Windows.Storage,         ContentType = WindowsRuntime]
  $null = [Windows.Media.Ocr.OcrEngine,                Windows.Foundation,      ContentType = WindowsRuntime]
  $null = [Windows.Foundation.IAsyncOperation`1,       Windows.Foundation,      ContentType = WindowsRuntime]
  $null = [Windows.Graphics.Imaging.SoftwareBitmap,    Windows.Foundation,      ContentType = WindowsRuntime]
  $null = [Windows.Storage.Streams.RandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
  $null = [WindowsRuntimeSystemExtensions]
    
  # some WinRT assemblies such as [Windows.Globalization.Language] are loaded indirectly by returning
  # the object types:
  #[Windows.Globalization.Language] などの一部の WinRT アセンブリは、オブジェクト タイプを返すことによって間接的に読み込まれます。
  $null = [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages

  # grab the async awaiter method:
  # async awaiter メソッドを取得します。
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  # find the awaiter method
  #awaiter メソッドを見つけます
  $awaiter = [WindowsRuntimeSystemExtensions].GetMember('GetAwaiter', 'Method',  'Public,Static') |
  Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } |
  Select-Object -First 1

  # define awaiter function
  #awaiter 関数の定義
  function Invoke-Async([object]$AsyncTask, [Type]$As)
  {
    return $awaiter.
    MakeGenericMethod($As).
    Invoke($null, @($AsyncTask)).
    GetResult()
  }
}
catch
{
  #OCR には、Windows 10 と Windows PowerShell が必要です。このモジュールは PowerShell 7 では使用できません
  throw 'OCR requires Windows 10 and Windows PowerShell. You cannot use this module in PowerShell 7'
}

function Convert-PsoImageToText
{
  <#
      .SYNOPSIS
      Converts an image file to text by using Windows 10 built-in OCR
      Windows 10 組み込みの OCR を使用して、画像ファイルをテキストに変換します
      .DESCRIPTION
      Detailed Description
      詳細な説明
      .EXAMPLE
      Convert-ImageToText -Path c:\temp\image.png
      Converts the image in image.png to text  
      Convert-ImageToText -パス c:\temp\image.png
      image.png の画像をテキストに変換します
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string]
    [Alias('FullName')]
    $Path,
    
    # dynamically create auto-completion from available OCR languages:
    # 利用可能な OCR 言語から動的にオートコンプリートを作成:
    [ArgumentCompleter({
          # receive information about current state:
          # 現在の状態に関する情報を受け取る:
          param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
          [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages |
          Foreach-Object { 
            # create completionresult items:
            # 完了結果アイテムを作成:
            $displayname = $_.DisplayName
            $id = $_.LanguageTag
            [System.Management.Automation.CompletionResult]::new($id, $displayname, "ParameterValue", "$displayName`r`n$id")
          }
            })]
    [Windows.Globalization.Language]
    $Language
  )
  
  begin
  { 
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
     
    # [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages
    if ($PSBoundParameters.ContainsKey('Language'))
    {
      $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($Language)
    }
    else
    {
      $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    }
  
    
    # PowerShell doesn't have built-in support for Async operations, 
    # but all the WinRT methods are Async.
    # This function wraps a way to call those methods, and wait for their results.
    # PowerShell には、非同期操作のサポートが組み込まれていません。
    # ただし、すべての WinRT メソッドは非同期です。
    # この関数は、これらのメソッドを呼び出す方法をラップし、結果を待ちます。
  }
  
  process
  {
    # all of these methods run asynchronously because they are tailored for responsive UIs
    # PowerShell is single-threaded and synchronous so a helper function is used to 
    # run the async methods and wait for them to complete, essentially reversing the async 
    # behavior
    # これらのメソッドはすべて、レスポンシブ UI 用に調整されているため、非同期で実行されます 
    # PowerShell はシングルスレッドで同期的であるため、ヘルパー関数を使用して非同期メソッドを実行し、
    #それらが完了するまで待機して、基本的に非同期の動作を逆にします
    # Invoke() requires the async method and the desired return type
   # Invoke() には、非同期メソッドと目的の戻り値の型が必要です
    # get image file:
    $file = [Windows.Storage.StorageFile]::GetFileFromPathAsync($path)
    $storageFile = Invoke-Async $file -As ([Windows.Storage.StorageFile])
  
    # read image content:
    $content = $storageFile.OpenAsync([Windows.Storage.FileAccessMode]::Read)
    $fileStream = Invoke-Async $content -As ([Windows.Storage.Streams.IRandomAccessStream])
  
    # get bitmap decoder:
    $decoder = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($fileStream)
    $bitmapDecoder = Invoke-Async $decoder -As ([Windows.Graphics.Imaging.BitmapDecoder])
  
    # decode bitmap:
    $bitmap = $bitmapDecoder.GetSoftwareBitmapAsync()
    $softwareBitmap = Invoke-Async $bitmap -As ([Windows.Graphics.Imaging.SoftwareBitmap])
  
    # do optical text recognition (OCR) and return lines and words:
    $ocrResult = $ocrEngine.RecognizeAsync($softwareBitmap)
    (Invoke-Async $ocrResult -As ([Windows.Media.Ocr.OcrResult])).Lines | 
      Select-Object -Property Text, @{Name='Words';Expression={$_.Words.Text}}
  }
}

#参考：GUIを使わないコマンド実行で結果を取得する場合の例
#Convert-PsoImageToText -Path "C:\タイトルなし.bmp" | select-object Text

#以下、GUI用の処理
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
[System.Windows.Window]$window = [Windows.Markup.XamlReader]::Load($reader)
[System.Windows.Controls.Button]$ButtonImageFileSelect =  $window.FindName("ButtonImageFileSelect")
[System.Windows.Controls.Button]$ButtonDoOCR =  $window.FindName("ButtonDoOCR")
[System.Windows.Controls.TextBlock]$FileName = $window.FindName("FileName")
[System.Windows.Controls.Image]$OCRImage = $window.FindName("OCRImage")
[System.Windows.Controls.TextBox]$MultiLineTextBox = $window.FindName("MultiLineTextBox")

#ボタン実行でConvert-PsoImageToTextをキックすると、画面が固まるため、処理はタイマー預ける（一種のマルチスレッド）
[System.Windows.Threading.DispatcherTimer]$dispatcherTimer = New-Object System.Windows.Threading.DispatcherTimer
$dispatcherTimer.Interval = [TimeSpan]::New(0,0,0,0,10) #10 millisecond Interval
$dispatcherTimer.Add_Tick.Invoke( {
    $ret = (Convert-PsoImageToText -Path $FileName.Text  | select-object Text)
    
    $MultiLineTextBox.Text = "" #状態を初期化
    foreach($val in  $ret){
     $MultiLineTextBox.Text +=  $val.Text + "`n" #結果書き込み
    }
    $dispatcherTimer.Stop() #自分自身でタイマー停止、起動は1度だけにするため
})

$ButtonDoOCR.add_click.Invoke({
   $MultiLineTextBox.Text = "★解析開始★" #状態を解析開始にする
   $dispatcherTimer.Start()  #タイマー軌道
})


$ButtonImageFileSelect.add_click.Invoke({
  [System.Windows.Forms.OpenFileDialog]$OpenFileDialog  = New-Object System.Windows.Forms.OpenFileDialog
  $OpenFileDialog.Filter = "Image File(*.bmp,*.jpg,*.png,*.tif)|*.bmp;*.jpg;*.png;*.tif|Bitmap(*.bmp)|*.bmp|Jpeg(*.jpg)|*.jpg|PNG(*.png)|*.png"
  $OpenFileDialog.InitialDirectory = "C:\"
  $OpenFileDialog.Title = "ファイルを選択してください"
  # 複数選択を許可したい時は Multiselect を設定する
  #$dialog.Multiselect = $true
  if($OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
      [System.Windows.MessageBox]::Show('選択したファイル：' + $OpenFileDialog.FileName)
      $FileName.Text = $OpenFileDialog.FileName
      $OCRImage.Source = $FileName.Text
  }else{
      [System.Windows.MessageBox]::Show('ファイルは選択されませんでした！')
  }
})

$result = $window.ShowDialog()
if ($result -eq $false)
{
    [System.Windows.MessageBox]::Show('WPF_OCR_Sample End')
}
