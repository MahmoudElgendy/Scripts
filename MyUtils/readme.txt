// to get the available modul paths

$env:psmodulepath -split ";"


C:\Users\MahmoudElgendi\OneDrive - MiView Integrated Solutions, LLC\Documents\PowerShell\Modules  ( highly recommended)
C:\Program Files\PowerShell\Modules
c:\program files\powershell\7\Modules
C:\Program Files\WindowsPowerShell\Modules
C:\Windows\system32\WindowsPowerShell\v1.0\Modules
PS C:\Users\MahmoudElgendi>


$target = ($env:PSModulePath -split ";")[0]
$source = (Get-Location).Path
sync-folder -targetparent  $target -sourceparent $source -foldername "MyUtils"

sync-modul -foldername "MyUtils"

sync-MyUtils