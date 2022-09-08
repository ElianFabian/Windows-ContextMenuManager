# Import-ContextMenuItem.ps1


Import-Module -Name "$PSScriptRoot/Modules/ContextMenuManager.psm1"


Start-ContextMenuProcess `
    -FunctionName "Import-ContextMenuItem" `
    -ArgumentList "-NonInteractive" `
    -Message "Importing the context menus into the registry..."
