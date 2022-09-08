# Remove-ContextMenuItem.ps1


Import-Module -Name "$PSScriptRoot/Modules/ContextMenuManager.psm1"


$settingsFile = "settings.ini"
$settings     = (Get-Content -Path "$PSScriptRoot/$settingsFile" -Encoding utf8) | ConvertFrom-StringData

$CONSOLE_NO_EXIT = [System.Convert]::ToBoolean($settings.CONSOLE_NO_EXIT)

$noExitString = if ($CONSOLE_NO_EXIT) { "-NoExit" } else { "" }


Start-ContextMenuProcess `
    -FunctionName "Remove-ContextMenuItem" `
    -ArgumentList "-NonInteractive $noExitString" `
    -Message "Removing the context menus from the registry..."
