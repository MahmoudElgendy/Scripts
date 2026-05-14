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