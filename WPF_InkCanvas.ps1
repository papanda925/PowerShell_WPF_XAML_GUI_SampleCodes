#参考
#https://codezine.jp/article/detail/5666?p=2
#Silverlight／WPFで使える逆引きTips集――インクキャンバス機能

Add-Type -AssemblyName PresentationFramework
Add-Type -Assembly System.Windows.Forms #for messagebox
[xml]$xaml='
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="WPF_InkCanvas_Sample" Height="500" Width="900">
<Border>
  <Viewbox>
    <StackPanel>
      <StackPanel Name="StackPanel01" Orientation="Horizontal">
        <Button Name="btnInk" Content="インク"/>
        <Button Name="btnEraseByPoint" Content="ポイント消しゴム"/>
        <Button Name="btnEraseByStroke" Content="ストローク消しゴム" />
        <Button Name="btnAllClear" Content="ストローク全消去" Height="23" Width="109" />
        <Button Name="btnInkAndGesture" Content="ジェスチャを認識"/>
        <Button Name="btnStrokeSelect" Content="ストローク選択" Margin="5,0,0,0"/>
        <Button Name="btnStrokeCopy" Content="ストロークをコピー" />
        <Button Name="btnStrokeCut" Content="ストロークをカット" />
        <Button Name="btnSave" Content="保存" Margin="5,0,0,0"/>
        <Button Name="btnSaveAsISF" Content="ISF形式で保存" />
        <Button Name="btnOpenISF" Content="ISF形式ファイルを開く" />
      </StackPanel>
      <StackPanel  Name="StackPanel02" Orientation="Horizontal">
        <TextBlock Text="ペンの形状：" TextAlignment="Right" />
        <RadioButton Content="●" Name="RadioButton1" IsChecked="True" />
        <RadioButton Content="■" Name="RadioButton2" />
        <TextBlock Text="太さ:" />
        <TextBox Text="{Binding ElementName=Slider1, Path=Value, Mode=TwoWay}" />
        <Slider Name="Slider1" Width="107" Minimum="1" 
                SmallChange="1" IsSnapToTickEnabled="True" Maximum="40" />
      </StackPanel>
      <StackPanel  Name="StackPanel03">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="0.5*"/>
            <ColumnDefinition Width="0.25*"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <GroupBox Grid.Row="0" Grid.Column="0" Grid.RowSpan="3"  Header="ペンの種類" HorizontalAlignment="Left">
            <StackPanel>
              <RadioButton Content="通常ペン" Name="radioNormalPen" IsChecked="True" />
              <RadioButton Content="蛍光ペン" Name="radioHighlightPen" />
            </StackPanel>
          </GroupBox>
          <TextBlock  Grid.Row="0" Grid.Column="1" Text="アルファ" VerticalAlignment="Top" />
          <TextBlock  Grid.Row="1" Grid.Column="1" Text="赤" VerticalAlignment="Top" />
          <TextBlock  Grid.Row="2" Grid.Column="1" Text="緑" VerticalAlignment="Top" />
          <TextBlock  Grid.Row="3" Grid.Column="1" Text="青" VerticalAlignment="Top" />
          <Slider  Grid.Row="0" Grid.Column="2" Name="SliderA" Minimum="0" Maximum="255"/>
          <Slider Grid.Row="1" Grid.Column="2" Name="SliderR" Minimum="0" Maximum="255"/>
          <Slider Grid.Row="2" Grid.Column="2" Name="SliderG" Minimum="0" Maximum="255"/>
          <Slider Grid.Row="3" Grid.Column="2" Name="SliderB" Minimum="0" Maximum="255"/>
        </Grid>
      </StackPanel>
      <StackPanel  Name="StackPanel04" Orientation="Horizontal">
        <RadioButton Content="通常の線" Name="rdoFitToCurveOff" />
        <RadioButton Content="滑らかな線" Name="rdoFitToCurveOn" />
      </StackPanel>
      <Border
      BorderThickness="2"
      BorderBrush="Black" Background="LightGray"
      HorizontalAlignment="Left" VerticalAlignment="Top"
      Width="900" Height="400" Margin="0,5,0,10">
        <InkCanvas Name="InkCanvas1" EditingMode="Ink" >
          <InkCanvas.DefaultDrawingAttributes>
            <DrawingAttributes FitToCurve="True" />
          </InkCanvas.DefaultDrawingAttributes>
        </InkCanvas>
      </Border>
    </StackPanel>
  </Viewbox>
</Border>
</Window>
' 
#Read xaml file
#[xml]$xaml = Get-Content '.\WPF_StopWatch_Sample.xaml'
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
[System.Windows.Window]$window = [Windows.Markup.XamlReader]::Load($reader)
#InkCanvas
[System.Windows.Controls.InkCanvas]$InkCanvas1 = $window.FindName("InkCanvas1")

#StackPanel01 関連
[System.Windows.Controls.StackPanel]$StackPanel01 =  $window.FindName("StackPanel01")
[System.Windows.Controls.Button]$btnInk =  $StackPanel01.FindName("btnInk")
[System.Windows.Controls.Button]$btnEraseByPoint =  $StackPanel01.FindName("btnEraseByPoint")
[System.Windows.Controls.Button]$btnEraseByStroke =  $StackPanel01.FindName("btnEraseByStroke")
[System.Windows.Controls.Button]$btnAllClear =  $StackPanel01.FindName("btnAllClear")
[System.Windows.Controls.Button]$btnStrokeSelect =  $StackPanel01.FindName("btnStrokeSelect")
[System.Windows.Controls.Button]$btnInkAndGesture =  $StackPanel01.FindName("btnInkAndGesture")
[System.Windows.Controls.Button]$btnStrokeCopy =  $StackPanel01.FindName("btnStrokeCopy")
[System.Windows.Controls.Button]$btnStrokeCut =  $StackPanel01.FindName("btnStrokeCut")
[System.Windows.Controls.Button]$btnSave =  $StackPanel01.FindName("btnSave")
[System.Windows.Controls.Button]$btnSaveAsISF =  $StackPanel01.FindName("btnSaveAsISF")
[System.Windows.Controls.Button]$btnOpenISF =  $StackPanel01.FindName("btnOpenISF")

#［インク］ボタンクリック時の処理
$btnInk.add_click.Invoke({
  #インクを使用できる状態にする
  $InkCanvas1.EditingMode = [System.Windows.Controls.InkCanvasEditingMode]::Ink 
})
#［ポイント消しゴム］ボタンクリック時の処理
$btnEraseByPoint.add_click.Invoke({
  #ペンがストロークと交差した部分のみを消去する
  $InkCanvas1.EditingMode = [System.Windows.Controls.InkCanvasEditingMode]::EraseByPoint 
})
#［ストローク消しゴム］ボタンクリック時の処理
$btnEraseByStroke.add_click.Invoke({
  #ペンが交差したストロークの全体を消去する
  $InkCanvas1.EditingMode =  [System.Windows.Controls.InkCanvasEditingMode]::EraseByStroke
})
#［ストローク全消去］ボタンクリック時の処理
$btnAllClear.add_click.Invoke({
  #全ストロークを消去する
  $InkCanvas1.Strokes.Clear()
})
#［ストローク選択］ボタンクリック時の処理
$btnStrokeSelect.add_click.Invoke({
    #'描画されたストロークを選択できる状態にする
    $InkCanvas1.EditingMode =[System.Windows.Controls.InkCanvasEditingMode]::Select 
})
#［ストローク選択］ボタンクリック時の処理
$btnInkAndGesture.add_click.Invoke({
  #'描画されたストロークを選択できる状態にする
  $InkCanvas1.EditingMode =[System.Windows.Controls.InkCanvasEditingMode]::InkAndGesture 
})

#StackPanel02関　
[System.Windows.Controls.StackPanel]$StackPanel02 =  $window.FindName("StackPanel02")
[System.Windows.Controls.RadioButton]$RadioButton1 =  $window.FindName("RadioButton1")
[System.Windows.Controls.RadioButton]$RadioButton2 =  $window.FindName("RadioButton2")
[System.Windows.Controls.Slider]$Slider1 =  $window.FindName("Slider1")
[System.Windows.Ink.DrawingAttributes]$inkDA = new-object System.Windows.Ink.DrawingAttributes

#ペンの形状を●にした場合
$RadioButton1.add_Checked.Invoke({
    If ($InkCanvas1 -eq $null){
        Return
    }
    #楕円形の先端に設定
    $inkDA.StylusTip = [System.Windows.Ink.StylusTip]::Ellipse
    #属性をセット
    $InkCanvas1.DefaultDrawingAttributes = $inkDA
})

#ペンの形状を■にした場合
$RadioButton2.add_Checked.Invoke({
    #楕円形の先端に設定
    $inkDA.StylusTip = [System.Windows.Ink.StylusTip]::Rectangle
    #属性をセット
    $InkCanvas1.DefaultDrawingAttributes = $inkDA
})
# ペンの太さ変更時の処理
$Slider1.add_ValueChanged.Invoke({
    If ($InkCanvas1 -eq $null){
        Return
    }
    #ペン先の幅と高さを設定
    $inkDA.Width = $Slider1.Value
    $inkDA.Height = $Slider1.Value
    $InkCanvas1.DefaultDrawingAttributes = $inkDA
})
#StackPanel03関連
[System.Windows.Controls.StackPanel]$StackPanel03 =  $window.FindName("StackPanel03")
[System.Windows.Controls.RadioButton]$radioNormalPen =  $window.FindName("radioNormalPen")
[System.Windows.Controls.RadioButton]$radioHighlightPen =  $window.FindName("radioHighlightPen")
[System.Windows.Controls.Slider]$SliderA =  $window.FindName("SliderA")
[System.Windows.Controls.Slider]$SliderR =  $window.FindName("SliderR")
[System.Windows.Controls.Slider]$SliderG =  $window.FindName("SliderG")
[System.Windows.Controls.Slider]$SliderB =  $window.FindName("SliderB")

#通常ペン
$radioNormalPen.Add_Checked({
    # 蛍光ペンをオフ（通常のペン）
    $inkDA.IsHighlighter = $false
    $inkCanvas1.DefaultDrawingAttributes = $inkDA
})

#蛍光ペン
$radioHighlightPen.Add_Checked({
    #蛍光ペンをオン
    $inkDA.IsHighlighter = $true;
    $inkCanvas1.DefaultDrawingAttributes = $inkDA
})

#スライダーの設定を反映させる
function UpdatePen()
{
    #ペンの色を作成
    $penColor = [System.Windows.Media.Color]::FromArgb(
        [System.Convert]::ToByte($sliderA.Value),
        [System.Convert]::ToByte($sliderR.Value),
        [System.Convert]::ToByte($sliderG.Value),
        [System.Convert]::ToByte($sliderB.Value))

    #作成した色をペンに割り当てる
    $inkDA.Color = $penColor
    $inkCanvas1.DefaultDrawingAttributes = $inkDA
}

#アルファ、R,G,B変更時
$SliderA.add_ValueChanged.Invoke({ UpdatePen })
$SliderR.add_ValueChanged.Invoke({ UpdatePen })
$SliderG.add_ValueChanged.Invoke({ UpdatePen })
$SliderB.add_ValueChanged.Invoke({ UpdatePen })

#StackPanel04関連
[System.Windows.Controls.StackPanel]$StackPanel04 =  $window.FindName("StackPanel04")
[System.Windows.Controls.RadioButton]$rdoFitToCurveOff =  $window.FindName("rdoFitToCurveOff")
[System.Windows.Controls.RadioButton]$rdoFitToCurveOn =  $window.FindName("rdoFitToCurveOn")

#/// 「通常の線」選択時の処理
$rdoFitToCurveOff.add_Checked.Invoke({
  #// FitToCurve を Off にする
  $inkDA.FitToCurve = $False
  $inkCanvas1.DefaultDrawingAttributes = $inkDA
})
#/// 「滑らかな線」選択時の処理
$rdoFitToCurveOn.add_Checked.Invoke({
  #// FitToCurve を On にする
  $inkDA.FitToCurve = $True
  $inkCanvas1.DefaultDrawingAttributes = $inkDA
})

#ジェスチャの認識
$InkCanvas1.Add_Gesture.Invoke({
    #VisualBasicでは「sender」と「e」によって、イベントソース、イベントデータの取得できました。
    #PowerShellで「sender」と「e」に相当するのが、「$this」と「$_」です。
    #この２つの変数はイベントハンドラの中でのみ、イベントソース、イベントデータへの参照を持ちます。
    #              イベントソース	イベントデータ
    #VisualBasic       sender           e
    #PowerShell         $this           $_
  ($sender, $e) = $this, $_
  #// ジェスチャの認識結果を取得  
  $gestureResults = $_.GetGestureRecognitionResults() 
  $RecognitionConfidence =  $gestureResults[0].RecognitionConfidence
  $ApplicationGesture = $gestureResults[0].ApplicationGesture

  #認識結果の信頼性が高い場合に、メッセージを表示する
  If( $RecognitionConfidence -eq [System.Windows.Ink.RecognitionConfidence]::Strong ) 
  {
    [System.Windows.Forms.MessageBox]::Show( "判定は" +   $ApplicationGesture.ToString() + "です","判定" )
  }

  #条件を満たす判定の場合は、図形を自動でリメイクさせる
  switch ( $ApplicationGesture  )  
  {
    ([System.Windows.Ink.ApplicationGesture]::Circle) #円
    {
      [System.Windows.Forms.DialogResult]$DialogResult = [System.Windows.Forms.MessageBox]::Show( "リメイクしますか：" + $gestureResults[0].ApplicationGesture.ToString() ,"リメイク" , [System.Windows.Forms.MessageBoxButtons]::YesNo)
      if( $DialogResult = [System.Windows.Forms.DialogResult]::Yes )
      {
        #認識時の領域（外枠）サイズを取得
        [System.Windows.Rect]$strokeRect = $e.Strokes.GetBounds()
        #認識した外枠サイズに合わせて円を作成する
        [System.Windows.Shapes.ellipse]$ellipse = New-Object System.Windows.Shapes.ellipse
        $ellipse.Width = $strokeRect.Width
        $ellipse.Height = $strokeRect.Height
        $ellipse.SetValue([System.Windows.Controls.InkCanvas]::LeftProperty, $strokeRect.X)
        $ellipse.SetValue([System.Windows.Controls.InkCanvas]::TopProperty, $strokeRect.Y)
        $ellipse.Stroke = [System.Windows.Media.Brushes]::Black
        #'作成した円をキャンバスに追加
        $InkCanvas1.Children.Add($ellipse)        
      }
      break
    } 
    ([System.Windows.Ink.ApplicationGesture]::Square) #四角
    {
      [System.Windows.Forms.DialogResult]$DialogResult = [System.Windows.Forms.MessageBox]::Show( "リメイクしますか：" + $gestureResults[0].ApplicationGesture.ToString() ,"リメイク" , [System.Windows.Forms.MessageBoxButtons]::YesNo)
      if( $DialogResult = [System.Windows.Forms.DialogResult]::Yes )
      {
        #認識時の領域（外枠）サイズを取得
        [System.Windows.Rect]$strokeRect = $e.Strokes.GetBounds()

        #'認識した外枠サイズに合わせて四角形を作成する
        [System.Windows.Shapes.Rectangle]$square  = New-Object System.Windows.Shapes.Rectangle

        $square.Width = $strokeRect.Width
        $square.Height = $strokeRect.Height
        $square.SetValue([System.Windows.Controls.InkCanvas]::LeftProperty, $strokeRect.X)
        $square.SetValue([System.Windows.Controls.InkCanvas]::TopProperty, $strokeRect.Y)
        $square.Stroke = [System.Windows.Media.Brushes]::Black
  
        #'作成した四角形をキャンバスに追加
        $InkCanvas1.Children.Add($square)
      }
      break
    } 
  }
})

#ストークのカット、コピー貼り付け
[System.Windows.Controls.Button]$btnStrokeCopy =  $StackPanel01.FindName("btnStrokeCopy")
[System.Windows.Controls.Button]$btnStrokeCut =  $StackPanel01.FindName("btnStrokeCut")

$btnStrokeCopy.add_click.Invoke({
  #選択されたストロークをクリップボードにコピー
  $InkCanvas1.CopySelection()
})
$btnStrokeCut.add_click.Invoke({
  #選択されたストロークをカットしてクリップボードにコピー
  $InkCanvas1.CutSelection()
})

#マウスダウン時の処理
$InkCanvas1.Add_PreviewMouseDown.Invoke({
    #VisualBasicでは「sender」と「e」によって、イベントソース、イベントデータの取得できました。
    #PowerShellで「sender」と「e」に相当するのが、「$this」と「$_」です。
    #この２つの変数はイベントハンドラの中でのみ、イベントソース、イベントデータへの参照を持ちます。
    #              イベントソース	イベントデータ
    #VisualBasic       sender           e
    #PowerShell         $this           $_
    ($sender, $e) = $this, $_
    #// マウスの右ボタンが押されたか？
    if ($e.RightButton -eq [System.Windows.Input.MouseButtonState]::Pressed)
    {
        #// 右ボタンが押された位置を取得
        $position = $e.GetPosition($inkCanvas1)


        #// 貼り付け可能か？
        if ($inkCanvas1.CanPaste() -eq $true )
        {
            #// 右ボタンが押された位置に貼り付け
            $inkCanvas1.Paste($position)
        }
    }
})

#保存関連
#// ［保存］ボタンクリック時の処理
$btnSave.add_click.Invoke({
  [Microsoft.Win32.SaveFileDialog]$dlgSave = New-Object  Microsoft.Win32.SaveFileDialog
  $dlgSave.Filter = "ビットマップファイル(*.bmp)|*.bmp|" +
  "JPEGファイル(*.jpg)|*,jpg|" +
  "PNGファイル(*.png)|*.png"
  $dlgSave.AddExtension = $true

  if ($dlgSave.ShowDialog() -eq $true)
  {
    #// 拡張子を取得する
    [string]$extension = [System.IO.Path]::GetExtension($dlgSave.FileName).ToUpper()
    Write-Host $extension
    
    #// ストロークが描画されている境界を取得
    [System.Windows.Rect]$rectBounds = $inkCanvas1.Strokes.GetBounds()

    #// 描画先を作成
    [System.Windows.Media.DrawingVisual]$dv = New-Object System.Windows.Media.DrawingVisual

    [System.Windows.Media.DrawingContext]$dc = $dv.RenderOpen()
    #// 描画エリアの位置補正（補正しないと黒い部分ができてしまう）
    $dc.PushTransform([System.Windows.Media.TranslateTransform]::new( -($rectBounds.X), -($rectBounds.Y)))
    #/ 描画エリア(dc)に四角形を作成
    #// 四角形の大きさはストロークが描画されている枠サイズとし、
    #// 背景色はInkCanvasコントロールと同じにする
    $dc.DrawRectangle($inkCanvas1.Background, $null, $rectBounds)

    #// 上記で作成した描画エリア(dc)にInkCanvasのストロークを描画
    $inkCanvas1.Strokes.Draw($dc)
    $dc.Close()
    
    # // ビジュアルオブジェクトをビットマップに変換する
    [System.Windows.Media.Imaging.RenderTargetBitmap]$rtb = [System.Windows.Media.Imaging.RenderTargetBitmap]::new( [int32]$rectBounds.Width, [int32]$rectBounds.Height,96,96,[System.Windows.Media.PixelFormats]::Default)
      $rtb.Render($dv)

      #// ビットマップエンコーダー変数の宣言
      $enc = $null;

    switch ($extension)
    {
      ".BMP" { 
        [System.Windows.Media.Imaging.BmpBitmapEncoder]$enc = new-object System.Windows.Media.Imaging.BmpBitmapEncoder
        break
      }

      ".JPG"{
        [System.Windows.Media.Imaging.JpegBitmapEncoder]$enc = new-object System.Windows.Media.Imaging.JpegBitmapEncoder
        break
      }
      ".PNG"{
        [System.Windows.Media.Imaging.PngBitmapEncoder]$enc = new-object System.Windows.Media.Imaging.PngBitmapEncoder
        break
      }
    }

    if ($enc -ne  $null)
    {
        #// ビットマップフレームを作成してエンコーダーにフレームを追加する
        $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        #// ファイルに書き込む
        [System.IO.Stream]$stream = [System.IO.File]::Create($dlgSave.FileName)
        $enc.Save($stream)
        $stream.Close()
    }

  }

})

#// ［ISF形式で保存する］ボタンクリック時の処理
$btnSaveAsISF.add_click.Invoke({
  [Microsoft.Win32.SaveFileDialog]$dlgSave = New-Object  Microsoft.Win32.SaveFileDialog
  $dlgSave.Filter = "ISFファイル(*.isf)|*.isf"

  if ($dlgSave.ShowDialog() -eq $true)
  {
    $inkCanvas1.Strokes.count
    [System.IO.FileStream]$fs = [System.IO.FileStream]::new($dlgSave.FileName, [System.IO.FileMode]::Create)
    $inkCanvas1.Strokes.Save($fs)
    [System.Windows.MessageBox]::Show('保存しました')
  }

})

#// ［ISF形式ファイルを開く］ボタンクリック時の処理
$btnOpenISF.add_click.Invoke({
  [Microsoft.Win32.SaveFileDialog]$dlgSave = New-Object  Microsoft.Win32.SaveFileDialog
  $dlgSave.Filter = "ISFファイル(*.isf)|*.isf"

  if ($dlgSave.ShowDialog() -eq $true)
  {
    #// 現在のストロークをクリア
    $inkCanvas1.Strokes.Clear();
    [System.IO.FileStream]$fs = [System.IO.FileStream]::new($dlgSave.FileName, [System.IO.FileMode]::Open)
    $inkCanvas1.Strokes = new-object System.Windows.Ink.StrokeCollection($fs)
  }
})

#Private inkDA As New DrawingAttributes
$window.add_Loaded.Invoke({ 
  $inkDA.Width = 1
  $inkDA.Height = 1
  #初期化
  $inkDA.Width = 1     #ペンの幅
  $inkDA.Height = 1    #ペンの高さ
  #ペンの色を黒で初期化
  $inkDA.Color =  [System.Windows.Media.Colors]::black 

  # 蛍光ペンをオフ（通常のペン）
  $inkDA.IsHighlighter = $false
  $InkCanvas1.DefaultDrawingAttributes = $inkDA    
})

$result = $window.ShowDialog()
if ($result -eq $false)
{
    [System.Windows.MessageBox]::Show('WPF_InkCanvas End')
}

#参考URL
#https://codezine.jp/article/detail/5666?p=5
