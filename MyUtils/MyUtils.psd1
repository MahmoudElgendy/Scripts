# myutils/MyUtils.psd1
@{
    RootModule = 'MyUtils.psm1'
    ModuleVersion = '1.0.0'
    Author = 'Mahmoud Elgendi'
    Description = 'Utility module'

    FunctionsToExport = @(
        'Add',
        'Greet',
        'Sync-Folder',
        'Sync-Module',
        'Sync-MyUtils',
        'Log-Info',
        'Create-ACR'
        'Delete-RGS'
    )
}