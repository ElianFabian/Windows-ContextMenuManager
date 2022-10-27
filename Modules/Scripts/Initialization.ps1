$basePath = "Registry::HKEY_CLASSES_ROOT"

$contextMenuTypePaths = @{
    File      = "$basePath\``*\shell"
    Directory = "$basePath\Directory\shell"
    Desktop   = "$basePath\Directory\background\shell"
    Drive     = "$basePath\Drive\shell"
}



$settingsFile = "settings.ini"

$settingsIniPath = "$PSScriptRoot\..\..\$settingsFile"

if (-not (Test-Path $settingsIniPath))
{   
    Write-Error "Couldn't find the '$settingsIniPath' file."
    Start-Sleep -Seconds 50
    exit
}

$settings = Get-Content -Path $settingsIniPath -Encoding utf8 | ConvertFrom-StringData

$PROPERTY_KEY      = $settings.PROPERTY_KEY
$PROPERTY_NAME     = $settings.PROPERTY_NAME
$PROPERTY_TYPE     = $settings.PROPERTY_TYPE
$PROPERTY_COMMAND  = $settings.PROPERTY_COMMAND
$PROPERTY_OPTIONS  = $settings.PROPERTY_OPTIONS
$PROPERTY_EXTENDED = $settings.PROPERTY_EXTENDED
$PROPERTY_ICON     = $settings.PROPERTY_ICON

$VALID_PROPERTY_SET = foreach ($propertyName in $settings.Keys)
{
    if ($propertyName.StartsWith("PROPERTY_"))
    {
        $settings.$propertyName
    }
}


$CONSOLE_VERBOSE = [System.Convert]::ToBoolean($settings.CONSOLE_VERBOSE)
$CONSOLE_NO_EXIT = [System.Convert]::ToBoolean($settings.CONSOLE_NO_EXIT)

# This expression throws an error when the administrator console is open because the current directory is different
# and then the relative path of this file fails
# But actully it doesn't matter because this file is not requiered in that context
# So we just ignore the error
$CONTEXT_MENU_LIST_PATH = Resolve-Path $settings.CONTEXT_MENU_LIST_PATH -ErrorAction Ignore

$POWERSHELL_EXE = $settings.POWERSHELL_EXE