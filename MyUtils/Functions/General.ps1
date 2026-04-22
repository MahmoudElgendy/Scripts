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