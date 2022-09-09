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

#region settings.ini

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

$CONSOLE_VERBOSE = [System.Convert]::ToBoolean($settings.CONSOLE_VERBOSE)

#endregion


# This expression throws an error when the administrator console is open because the current directory is different
# and then the relative path of this file fails
# But actully it doesn't matter because this file is not requiered in that context
# So we just ignore the error
$CONTEXT_MENU_LIST_PATH = Resolve-Path $settings.CONTEXT_MENU_LIST_PATH -ErrorAction Ignore



function WriteError($Message) 
{
    [Console]::ForegroundColor = 'Red'
    [Console]::Error.WriteLine($Message)
    [Console]::ResetColor()
}

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

    $sameLevelItemKeys = new-Object System.Collections.Generic.HashSet[string]

    foreach ($item in $Items)
    {
        foreach ($propertyName in $item.PSObject.Properties.Name)
        {
            if (-not ($VALID_PROPERTY_SET.Contains($propertyName)))
            {
                WriteError "'$propertyName' is not a valid item property name at:`n$JsonPath`n`nThis is the valid set from settings.ini: [$($VALID_PROPERTY_SET -join ', ')] " -Category InvalidData
                return $false
            }

            $propertyValue = $item.$propertyName

            switch ($propertyName)
            {
                $PROPERTY_KEY
                {
                    if ( -not $sameLevelItemKeys.Add($propertyValue))
                    {
                        WriteError "'$propertyValue' is a repeated key at:`n$JsonPath`n`nKeys must be unique in the same level of depth."
                        return $false
                    }
                }
                $PROPERTY_TYPE
                {
                    if (-not ($contextMenuTypePaths.Keys -contains $propertyValue))
                    {
                        WriteError "'$propertyValue' is not a valid value for the 'Type' property at:`n$JsonPath.`n`nThis is the valid set: [$($contextMenuTypePaths.Keys -join ', ')]"
                        return $false
                    }
                }
                $PROPERTY_ICON
                {
                    if (-not (Test-Path $propertyValue))
                    {
                        WriteError "'$propertyValue' is not an existing file at:`n$JsonPath"
                        return $false
                    }
                }
                $PROPERTY_OPTIONS { $isValid = TestJsonObjectKeyNamesAndValues -Items $propertyValue -JsonPath $JsonPath }
            }
        }
    }

    return $isValid
}

function TestErrorsBeforeAction([string] $JsonString, [psobject] $JsonObject, [string] $JsonPath)
{
    if (-not (IsRunningAsAdministrator))
    {
        WriteError "Script must run as administrator."
        return $false
    }
    if (-not (TestJsonString $JsonString))
    {
        WriteError "Wrong format in json file: $JsonPath" -Category InvalidData
        return $false
    }
    if (-not (TestJsonObjectKeyNamesAndValues -Items $JsonObject -JsonPath $JsonPath))
    {
        return $false
    }

    return $true
}


function NewContextMenuItem([psobject] $Item, [string] $ItemPath, [switch] $Verbose)
{
    if ($Item.$PROPERTY_ICON)
    {
        $iconPath = Resolve-Path $Item.$PROPERTY_ICON

        # Set item image
        New-ItemProperty -Path $ItemPath -Name Icon -Value $iconPath > $null

        Write-Verbose "New item property: '$ItemPath' = '$iconPath'" -Verbose:$Verbose
    }

    if ($item.$PROPERTY_OPTIONS)
    {
        # Set group name (MUIVerb)
        New-ItemProperty -Path $ItemPath -Name MUIVerb -Value $Item.$PROPERTY_NAME > $null

        # Allow subitems
        New-ItemProperty -Path $ItemPath -Name subcommands > $null

        # Create shell (container of subitems)
        $itemShellPath = (New-Item -Path $ItemPath -Name Shell).PSPath.Replace("*", "``*")

        Write-Verbose "New item property: '$ItemPath\MUIVerb' = '$($Item.$PROPERTY_NAME)'" -Verbose:$Verbose
        Write-Verbose "New item property: '$ItemPath\subcommands'" -Verbose:$Verbose
        Write-Verbose "New item: '$itemShellPath'" -Verbose:$Verbose

        # Create subitems
        foreach ($subitem in $Item.$PROPERTY_OPTIONS)
        {
            $subitemPath = (New-Item -Path $itemShellPath -Name $subitem.$PROPERTY_KEY).PSPath.Replace("*", "``*")

            Write-Verbose "New item: '$itemShellPath\$($subitem.$PROPERTY_KEY)'" -Verbose:$Verbose

            NewContextMenuItem -Item $subitem -ItemPath $subitemPath -Verbose:$Verbose
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

        Write-Verbose "New item: '$commandPath'" -Verbose:$Verbose
        Write-Verbose "New item property: '$ItemPath\(default)' = '$($Item.$PROPERTY_NAME)'" -Verbose:$Verbose
        Write-Verbose "New item property: '$commandPath\(default)' = '$($Item.$PROPERTY_COMMAND)'" -Verbose:$Verbose
    }
}

function Import-ContextMenuItem([string] $JsonPath, [switch] $Verbose)
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
        $itemPath = (New-Item -Path $contextMenuTypePath -Name $item.$PROPERTY_KEY -ErrorAction Stop).PSPath.Replace("*", "``*")

        Write-Verbose "New item: '$contextMenuTypePath\$($item.$PROPERTY_KEY)'" -Verbose:$Verbose

        if ($item.$PROPERTY_EXTENDED)
        {
            # Set as extended (must hold Shift to make the option visble)
            New-ItemProperty -Path $itemPath -Name Extended > $null

            Write-Verbose "New item property: '$itemPath\Extended'" -Verbose:$Verbose
        }

        NewContextMenuItem -Item $item -ItemPath $itemPath -Verbose:$Verbose
    }
}


function RemoveContextMenuItem([psobject] $Item, [string] $ItemPath, [switch] $Verbose)
{
    $itemNotExists = -not (Get-Item -Path $ItemPath -ErrorAction Ignore)
    if ($itemNotExists)
    {
        Write-Warning "Trying to remove a non-existing path: '$ItemPath'."
        return
    }

    if ($item.$PROPERTY_OPTIONS)
    {
        $itemShellPath = "$ItemPath\Shell"

        foreach ($item in $item.$PROPERTY_OPTIONS)
        {
            $subitemPath = "$itemShellPath\$($item.$PROPERTY_KEY)"

            RemoveContextMenuItem -Item $item -ItemPath $subitemPath -Verbose:$Verbose
        }

        Remove-Item -Path $itemShellPath
        Remove-Item -Path $ItemPath

        Write-Verbose "Remove item: '$itemShellPath'" -Verbose:$Verbose
        Write-Verbose "Remove item: '$ItemPath'" -Verbose:$Verbose
    }
    else
    {
        Remove-Item -Path $ItemPath\command
        Remove-Item -Path $ItemPath

        Write-Verbose "Remove item: '$ItemPath\command'" -Verbose:$Verbose
        Write-Verbose "Remove item: '$ItemPath'" -Verbose:$Verbose
    }
}

function Remove-ContextMenuItem([string] $JsonPath, [switch] $Verbose)
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

        RemoveContextMenuItem -Item $item -ItemPath $itemPath -Verbose:$Verbose
    }   
}


function Start-ContextMenuProcess([string] $FunctionName, [string] $ArgumentList, [string] $Message)
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

    $verboseString = if ($CONSOLE_VERBOSE) { "-Verbose"} else { "" }

    # Create one function call per json file
    $functionCalls = ""

    foreach ($filePath in $filePaths)
    {
        $functionCalls += "$FunctionName -JsonPath '$filePath' $verboseString`n"
    }

    $command = @(
        "Import-Module -Name '$PSCommandPath'",
        "Write-Host '$Message' -ForegroundColor Green",
        $functionCalls
    ) -join "`n"

    Start-Process -Verb RunAs -Path Powershell -ArgumentList "$ArgumentList -Command $command"
}



Export-ModuleMember -Function *-*
