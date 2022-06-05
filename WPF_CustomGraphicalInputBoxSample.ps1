#presentationframeworkを読み込み
Add-Type -AssemblyName presentationframework

#XAMLファイルを読み込んでxmlに変換
[System.Xml.XmlDocument]$xaml = Get-Content .\WPF_CustomGraphicalInputBoxSample.xaml
$xaml.GetType().FullName
#visual studio でデザインした場合に付与され、Powershellで読み込む時に不要な要素を削除
$xaml.window.RemoveAttribute("x:Class")
$xaml.window.RemoveAttribute("mc:Ignorable")

#読み込んだxamlをXmlNodeReaderにキャスト
[System.Xml.XmlNodeReader]$xamlReader = $xaml -as "System.Xml.XmlNodeReader"
$xamlReader.GetType().FullName
#Windows.Markup.XamlReaderで読み込み
[System.Windows.Window]$mainWindow = [Windows.Markup.XamlReader]::Load($xamlReader)
$mainWindow.gettype().FullName

#各種コントロールを取得
[System.Windows.Controls.Button]$okButton = $mainWindow.FindName("OkButton")
$okButton.gettype().FullName
[System.Windows.Controls.Button]$CancelButton = $mainWindow.FindName("CancelButton")
$CancelButton.gettype().FullName
[System.Windows.Controls.TextBox]$TextBox = $mainWindow.FindName("TextBox")
$TextBox.gettype().FullName
[System.Windows.Controls.Label]$Label = $mainWindow.FindName("Label")
$Label.gettype().FullName

#イベントを追加
$okButton.add_Click.Invoke({
    Write-Output "Using $textBox.Text" | Out-Host 
    $mainWindow.DialogResult = $true
    $mainWindow.Close()
    return  
})
$CancelButton.add_Click.Invoke({
    Write-Output "Cancel Click Bye" | Out-Host 
    $mainWindow.DialogResult = $false
    $mainWindow.Close()
    return     
})

#表示
#$mainWindow.showDialog() | out-null
[System.Boolean]$result = $mainWindow.showDialog()
$result.GetType().FullName
Write-Output "Result is $result" | Out-Host 

if ($result -eq  $true )
{
    $x = $textBox.Text
    $x
}
