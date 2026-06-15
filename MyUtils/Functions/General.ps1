function Sync-Folder {
    param(
        [string]$TargetParent,
        [string]$SourceParent,
        [string]$FolderName
    )

    $target = Join-Path $TargetParent $FolderName
    $source = Join-Path $SourceParent $FolderName

    if (Test-Path $target) {
        Remove-Item $target -Recurse -Force
    }

    Copy-Item $source $TargetParent -Recurse
}
<<<<<<< HEAD

function Sync-Module {
    param(
        [string]$FolderName
    )
    $target = ($env:PSModulePath -split ";")[0]
    $source = (Get-Location).Path
    sync-folder -targetparent  $target -sourceparent $source -foldername $FolderName
}
function Sync-MyUtils {
     Sync-Module -foldername "MyUtils"
}
=======
#  whating file if there is changes sync
# $source = "C:\SourceRepo"
# $target = "C:\Backup"

# $lastState = ""

# while ($true) {

#     $currentState = git -C $source status --porcelain | Out-String

#     if ($currentState -ne $lastState) {

#         Write-Host "Changes detected..."

#         robocopy $source $target /MIR

#         Write-Host "Sync completed"

#         $lastState = $currentState
#     }

#     Start-Sleep 5
# }
>>>>>>> 9c785449320fecf6231a566fc97231183660b568
