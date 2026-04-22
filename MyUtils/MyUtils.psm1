# load function files
. $PSScriptRoot\Functions\Math.ps1
. $PSScriptRoot\Functions\Text.ps1
. $PSScriptRoot\Functions\General.ps1
. $PSScriptRoot\Functions\Logging.ps1

# Export functions beter move it to .psd1 file
#Export-ModuleMember -Function Add, Greeting 