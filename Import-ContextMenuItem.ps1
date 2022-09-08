# Import-ContextMenuItem.ps1


Import-Module -Name "$PSScriptRoot/Modules/ContextMenuManager.psm1"


$settingsFile = "settings.ini"
$settings     = (Get-Content -Path "$PSScriptRoot/$settingsFile" -Encoding utf8) | ConvertFrom-StringData

$CONSOLE_NO_EXIT = [System.Convert]::ToBoolean($settings.CONSOLE_NO_EXIT)

$noExitString = if ($CONSOLE_NO_EXIT) { "-NoExit" } else { "" }


Start-ContextMenuProcess `
    -FunctionName "Import-ContextMenuItem" `
    -ArgumentList "-NonInteractive $noExitString" `
    -Message "Importing the context menus into the registry..."
