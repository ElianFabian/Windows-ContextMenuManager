# ContextMenuManager.psm1



Import-Module -Name "$PSScriptRoot\ObjectManipulation.psm1"

. "$PSScriptRoot\Scripts\Initialization.ps1"



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

function Import-ContextMenuItem([string] $Path, [switch] $Verbose)
{
    $contextMenuItemsJson = GetObjectFromJsonOrXml -Path $Path

    foreach ($item in $contextMenuItemsJson)
    {
        $contextMenuTypePath = $contextMenuTypePaths.$($item.$PROPERTY_TYPE)

        # Create item
        $itemPath = (New-Item -Path $contextMenuTypePath -Name $item.$PROPERTY_KEY -ErrorAction Stop).PSPath.Replace("*", "``*")

        Write-Verbose "New item: '$contextMenuTypePath\$($item.$PROPERTY_KEY)'" -Verbose:$Verbose

        $extendedValue = $item.$PROPERTY_EXTENDED

        if ($null -ne $extendedValue -and $extendedValue -like $true)
        {
            # Mark as extended (must hold Shift to make the option visible)
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

function Remove-ContextMenuItem([string] $Path, [switch] $Verbose)
{
    $contextMenuItemsJson = GetObjectFromJsonOrXml -Path $Path

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

    $verboseArg = if ($CONSOLE_VERBOSE) { "-Verbose" } else { "" }

    # Create one function call per json file
    $functionCalls = foreach ($filePath in $filePaths)
    {
        "$FunctionName -Path '$filePath' $verboseArg`n"
    }

    $command = @(
        "Import-Module -Name '$PSCommandPath'",
        "Write-Host '$Message' -ForegroundColor Green",
        $functionCalls -join "`n"
    ) -join "`n"

    $noExitArg = if ($CONSOLE_NO_EXIT) { "-NoExit" } else { "" }

    Start-Process -Verb RunAs -Path $POWERSHELL_EXE -ArgumentList "$noExitArg $ArgumentList -Command $command"
}



Export-ModuleMember -Function *-*
