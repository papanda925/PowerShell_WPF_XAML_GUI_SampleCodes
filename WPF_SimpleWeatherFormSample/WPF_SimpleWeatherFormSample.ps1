#参考URL
#https://docs.microsoft.com/en-us/windows/apps/design/layout/grid-tutorial
#Tutorial: Use Grid and StackPanel to create a simple weather app より

#presentationframeworkを読み込み
Add-Type -AssemblyName presentationframework

#動的絶対パスを作成
$scriptPath = $MyInvocation.MyCommand.Path
Write-Output  "---------scriptPath ------------"
Write-Output  $scriptPath
$scriptPath2 = Split-Path -Parent $scriptPath
Write-Output  "---------scriptPath2------------"
Write-Output  $scriptPath2
$ImagePath = Join-Path $scriptPath2 "partially-cloudy.png"
Write-Output  "----------ImagePath-------------"
Write-Output  $ImagePath
Write-Output  "--------------------------------"

#XAMLファイルを読み込んでxmlに変換
[System.Xml.XmlDocument]$xaml = Get-Content .\WPF_SimpleWeatherFormSample.xaml

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
[System.Windows.Controls.Image]$Image = $mainWindow.FindName("imageData")
$Image.gettype().FullName
$Image.Source = $ImagePath #絶対パスでないとエラーとなるため、動的取得の絶対パスを再設定

#表示
[System.Boolean]$result = $mainWindow.showDialog()
$result.GetType().FullName
Write-Output "Result is $result" | Out-Host 

