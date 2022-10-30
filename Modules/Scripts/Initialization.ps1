$basePath = "Registry::HKEY_CLASSES_ROOT"

$contextMenuTypePaths =
@{
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

# JSON/XML property names
$P_KEY      = $settings.PROPERTY_KEY
$P_NAME     = $settings.PROPERTY_NAME
$P_TYPE     = $settings.PROPERTY_TYPE
$P_COMMAND  = $settings.PROPERTY_COMMAND
$P_OPTIONS  = $settings.PROPERTY_OPTIONS
$P_EXTENDED = $settings.PROPERTY_EXTENDED
$P_ICON     = $settings.PROPERTY_ICON
$P_POSITION = $settings.PROPERTY_POSITION

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