# https://medium.com/analytics-vidhya/creating-cascading-context-menus-with-the-windows-10-registry-f1cf3cd8398f


$basePath = "Registry::HKEY_CLASSES_ROOT"

$contextMenuTypePaths = @{
    File      = "$basePath\``*\shell"
    Directory = "$basePath\Directory\shell"
    Desktop   = "$basePath\Directory\background\shell"
    Drive     = "$basePath\Drive\shell"
}

$settingsFile = "../settings.ini"
$settings     = (Get-Content -Path "$PSScriptRoot/$settingsFile" -Encoding utf8) | ConvertFrom-StringData

# Set the property names that the json files use
$PROPERTY_KEY      = $settings.PROPERTY_KEY
$PROPERTY_NAME     = $settings.PROPERTY_NAME
$PROPERTY_TYPE     = $settings.PROPERTY_TYPE
$PROPERTY_COMMAND  = $settings.PROPERTY_COMMAND
$PROPERTY_OPTIONS  = $settings.PROPERTY_OPTIONS
$PROPERTY_EXTENDED = $settings.PROPERTY_EXTENDED
$PROPERTY_ICON     = $settings.PROPERTY_ICON

$VALID_PROPERTY_SET = @()

foreach ($propertyName in $settings.PSObject.Properties.Name)
{
    if ($propertyName.StartsWith("PROPERTY_"))
    {
        $VALID_PROPERTY_SET.Add($settings.$propertyName)
    }
}

$VALID_PROPERTY_SET = @("Key", "Name", "Type", "Command", "Options", "Extended", "Icon")


# This expression throws an error when the administrator console is open because the current directory is different
# and then the relative path of this file fails
# But actully it doesn't matter because this file is not requiered in that context
# So we just ignore the error
$CONTEXT_MENU_LIST_PATH = Resolve-Path $settings.CONTEXT_MENU_LIST_PATH -ErrorAction Ignore


function IsRunningAsAdministrator()
{
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function TestJsonString($JsonString)
{
    try
    {
        ConvertFrom-Json $JsonString -ErrorAction Stop > $null

        return $true
    }
    catch { return $false }
}

function TestJsonObjectKeyNamesAndValues([array] $Items, [string] $JsonPath)
{
    $isValid = $true

    foreach ($item in $Items)
    {
        foreach ($propertyName in $item.PSObject.Properties.Name)
        {
            if (-not ($VALID_PROPERTY_SET.Contains($propertyName)))
            {
                Write-Error "'$propertyName' is not a valid item property name at: '$JsonPath'.`nThis is the valid set from settings.ini: [$($VALID_PROPERTY_SET -join ', ')] " -Category InvalidData
                return $false
            }

            switch ($propertyName)
            {
                $PROPERTY_TYPE
                {
                    $typeValue = $item.$PROPERTY_TYPE

                    if (-not ($contextMenuTypePaths.Keys -ccontains $typeValue))
                    {
                        Write-Error "'$typeValue' is not a valid value for the 'Type' property at: '$JsonPath'.`nThis is the valid set: [$($contextMenuTypePaths.Keys -join ', ')]"
                        return $false
                    }
                }
                $PROPERTY_ICON
                {
                    $iconValue = $item.$PROPERTY_ICON
    
                    if (-not (Test-Path $iconValue))
                    {
                        Write-Error "'$iconValue' is not an existing path at: $JsonPath"
                        return $false
                    }
                }
                $PROPERTY_OPTIONS { $isValid = TestJsonObjectKeyNamesAndValues -Items $item.$PROPERTY_OPTIONS -JsonPath $JsonPath }
            }
        }
    }

    return $isValid
}

function TestErrorsBeforeAction([string] $JsonString, [psobject] $JsonObject, [string] $JsonPath)
{
    if (-not (IsRunningAsAdministrator))
    {
        Write-Error "Script must run as administrator."
        return $false
    }
    if (-not (TestJsonString $JsonString))
    {
        Write-Error "Wrong format in json file: $JsonPath" -Category InvalidData
        return $false
    }
    if (-not (TestJsonObjectKeyNamesAndValues -Items $JsonObject -JsonPath $JsonPath))
    {
        return $false
    }

    return $true
}


function NewContextMenuItem([psobject] $Item, [string] $ItemPath)
{
    if ($Item.$PROPERTY_ICON)
    {
        $iconPath = Resolve-Path $Item.$PROPERTY_ICON

        # Set item image
        New-ItemProperty -Path $ItemPath -Name Icon -Value $iconPath > $null
    }

    if ($item.$PROPERTY_OPTIONS)
    {
        # Set group name (MUIVerb)
        New-ItemProperty -Path $ItemPath -Name MUIVerb -Value $Item.$PROPERTY_NAME > $null

        # Allow subitems
        New-ItemProperty -Path $ItemPath -Name subcommands > $null

        # Create shell (container of subitems)
        $itemShellPath = (New-Item -Path $ItemPath -Name Shell).PSPath.Replace("*", "``*")

        # Create subitem
        foreach ($subitem in $Item.$PROPERTY_OPTIONS)
        {
            $subitemPath = (New-Item -Path $itemShellPath -Name $subitem.$PROPERTY_KEY).PSPath.Replace("*", "``*")

            NewContextMenuItem -Item $subitem -ItemPath $subitemPath
        }
    }
    else
    {
        # Create command item
        $commandPath = (New-Item -Path $ItemPath -Name command).PSPath

        # Set command name
        New-ItemProperty -Path $ItemPath -Name '(default)' -Value $Item.$PROPERTY_NAME > $null

        # Set command value
        New-ItemProperty -LiteralPath $commandPath -Name '(default)' -Value $Item.$PROPERTY_COMMAND > $null
    }
}

function Add-ContextMenuItem([string] $JsonPath)
{
    $jsonString = Get-Content $JsonPath -Encoding utf8 -Raw

    $contextMenuItemsJson = $jsonString | ConvertFrom-Json

    if (-not (TestErrorsBeforeAction -JsonString $jsonString -JsonObject $contextMenuItemsJson -JsonPath $JsonPath))
    {
        # Allows the user the read the error message
        Start-Sleep -Seconds 50
        return
    }

    foreach ($item in $contextMenuItemsJson)
    {
        $contextMenuTypePath = $contextMenuTypePaths.$($item.$PROPERTY_TYPE)

        # Create item
        $itemPath = (New-Item -Path $contextMenuTypePath -Name $item.$PROPERTY_KEY).PSPath.Replace("*", "``*")

        if ($item.$PROPERTY_EXTENDED)
        {
            # Set as extended (must hold Shift to make the option visble)
            New-ItemProperty -Path $itemPath -Name Extended > $null
        }

        NewContextMenuItem -Item $item -ItemPath $itemPath
    }
}


function RemoveContextMenuItem([psobject] $Item, [string] $ItemPath)
{
    if ($item.$PROPERTY_OPTIONS)
    {
        $itemShellPath = "$ItemPath\Shell"

        foreach ($item in $item.$PROPERTY_OPTIONS)
        {
            $subitemPath = "$itemShellPath\$($item.$PROPERTY_KEY)"

            $itemNotExists = -not (Get-Item -Path $subitemPath -ErrorAction Ignore)
            if ($itemNotExists)
            {
                Write-Warning "Trying to remove a non-existent path: '$subitemPath'."
                return
            }

            RemoveContextMenuItem -Item $item -ItemPath $subitemPath
        }

        Remove-Item -Path $itemShellPath
        Remove-Item -Path $ItemPath
    }
    else
    {
        Remove-Item -Path $ItemPath\command
        Remove-Item -Path $ItemPath
    }
}

function Remove-ContextMenuItem([string] $JsonPath)
{
    $jsonString = Get-Content $JsonPath -Encoding utf8 -Raw

    $contextMenuItemsJson = $jsonString | ConvertFrom-Json

    if (-not (TestErrorsBeforeAction -JsonString $jsonString -JsonObject $contextMenuItemsJson -JsonPath $JsonPath))
    {
        # Allows the user the read the error message
        Start-Sleep -Seconds 50
        return
    }

    foreach ($item in $contextMenuItemsJson)
    {
        $contextMenuTypePath = $contextMenuTypePaths.$($item.$PROPERTY_TYPE)

        $itemPath = "$contextMenuTypePath\$($item.$PROPERTY_KEY)"

        RemoveContextMenuItem -Item $item -ItemPath $itemPath
    }   
}


function Start-ContextMenuProcess([string] $FunctionName, [string] $ArgumentList)
{
    $emptyRegex    = "^(\s|)*$"
    $commentsRegex = "^#"

    # Get files and folders from list (it ignores empty lines and comments)
    $fileAndFolderPaths = Get-Content $CONTEXT_MENU_LIST_PATH | Where-Object { $_ -notmatch "($emptyRegex|$commentsRegex)" }

    # Transform the possible relative paths to absolute and get the files of the folders
    $filePaths = New-Object Collections.Generic.List[string]
    foreach ($path in $fileAndFolderPaths)
    {
        if ((Get-Item $path).PSIsContainer)
        {
            $files = Get-ChildItem $path -File -Filter *.json

            foreach ($file in $files) { $filePaths.Add($file.FullName) }
        }
        else
        {
            $absolutePath = Resolve-Path $path

            $filePaths.Add($absolutePath)
        }
    }

    # Create one function call per json file
    $functionCalls = ""
    foreach ($filePath in $filePaths)
    {
        $functionCalls += "$FunctionName -JsonPath '$filePath'`n"
    }

    $command = @(
        "Import-Module -Name '$PSCommandPath'",
        $functionCalls
    ) -join "`n"

    Start-Process -Verb RunAs -Path Powershell -ArgumentList "$ArgumentList -Command $command"
}



Export-ModuleMember -Function *-*
