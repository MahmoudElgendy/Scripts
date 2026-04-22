Function Log-Info{
    param(
        [string]$Message,
        [System.ConsoleColor]$Color = "Gray"
    )
    $timestamp = Get-date -format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}