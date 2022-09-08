# Add-ContextMenuItem.ps1


Import-Module -Name "$PSScriptRoot/Modules/ContextMenuManager.psm1"


Start-ContextMenuProcess -FunctionName "Add-ContextMenuItem" -ArgumentList "-NonInteractive"
