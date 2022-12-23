# ContextMenuManager.psm1



Import-Module -Name "$PSScriptRoot\ObjectManipulation.psm1"

. "$PSScriptRoot\Scripts\Initialization.ps1"



# Registry keys
$RP_SHELL       = 'Shell'
$RP_COMMAND     = 'Command'

# Registry properties
$RP_DEFAULT     = '(default)'
$RP_MUI_VERB    = 'MUIVerb'
$RP_SUBCOMMANDS = 'Subcommands'
$RP_EXTENDED    = 'Extended'
$RP_ICON        = 'Icon'
$RP_POSITION    = 'Position'


function NewCommandItem([psobject] $Item, [string] $ItemPath, [switch] $Verbose)
{
    # Create command item
    $commandPath = (New-Item -Path $ItemPath -Name $RP_COMMAND).PSPath

    # Set command name
    New-ItemProperty -Path $ItemPath -Name $RP_DEFAULT -Value $Item.$P_NAME > $null

    # Set command value
    New-ItemProperty -LiteralPath $commandPath -Name $RP_DEFAULT -Value $Item.$P_COMMAND > $null

    Write-Verbose "New item: '$commandPath'" -Verbose:$Verbose
    Write-Verbose "New item property: '$ItemPath\$RP_DEFAULT' = '$($Item.$P_NAME)'" -Verbose:$Verbose
    Write-Verbose "New item property: '$commandPath\$RP_DEFAULT' = '$($Item.$P_COMMAND)'" -Verbose:$Verbose
}

function NewGroupItem([psobject] $Item, [string] $ItemPath, [switch] $Verbose)
{
    # Set group name (MUIVerb)
    New-ItemProperty -Path $ItemPath -Name $RP_MUI_VERB -Value $Item.$P_NAME > $null

    # Allow subitems
    New-ItemProperty -Path $ItemPath -Name $RP_SUBCOMMANDS > $null

    # Create shell (container of subitems)
    $itemShellPath = (New-Item -Path $ItemPath -Name $RP_SHELL).PSPath.Replace("*", "``*")

    Write-Verbose "New item property: '$ItemPath\$RP_MUI_VERB' = '$($Item.$P_NAME)'" -Verbose:$Verbose
    Write-Verbose "New item property: '$ItemPath\$RP_SUBCOMMANDS'" -Verbose:$Verbose
    Write-Verbose "New item: '$itemShellPath'" -Verbose:$Verbose

    return $itemShellPath
}

function NewContextMenuItem([psobject] $Item, [string] $ItemPath, [switch] $Verbose)
{
    if ($Item.$P_ICON)
    {
        $iconPath = Resolve-Path $Item.$P_ICON

        # Set item image
        New-ItemProperty -Path $ItemPath -Name $RP_ICON -Value $iconPath > $null

        Write-Verbose "New item property: '$ItemPath' = '$iconPath'" -Verbose:$Verbose
    }

    if ($item.$P_OPTIONS)
    {
        $itemShellPath = NewGroupItem -Item $Item -ItemPath $ItemPath -Verbose:$Verbose

        # Create subitems
        foreach ($subitem in $Item.$P_OPTIONS)
        {
            $subitemPath = (New-Item -Path $itemShellPath -Name $subitem.$P_KEY).PSPath.Replace("*", "``*")

            Write-Verbose "New item: '$itemShellPath\$($subitem.$P_KEY)'" -Verbose:$Verbose

            NewContextMenuItem -Item $subitem -ItemPath $subitemPath -Verbose:$Verbose
        }
    }
    else
    {
        NewCommandItem -Item $Item -ItemPath $ItemPath -Verbose:$Verbose
    }
}

function Import-ContextMenuItem([string] $Path, [switch] $Verbose)
{
    $contextMenuItemsJson = GetObjectFromJsonOrXml -Path $Path

    foreach ($item in $contextMenuItemsJson)
    {
        $contextMenuTypePath = $contextMenuTypePaths.$($item.$P_TYPE)

        # Create item
        $itemPath = (New-Item -Path $contextMenuTypePath -Name $item.$P_KEY -ErrorAction Stop).PSPath.Replace("*", "``*")

        Write-Verbose "New item: '$contextMenuTypePath\$($item.$P_KEY)'" -Verbose:$Verbose

        if ($null -ne $item.$P_EXTENDED -and $item.$P_EXTENDED -like $true)
        {
            # Mark as extended (must hold Shift to make the option visible)
            New-ItemProperty -Path $itemPath -Name $RP_EXTENDED > $null

            Write-Verbose "New item property: '$itemPath\$RP_EXTENDED'" -Verbose:$Verbose
        }

        if ($null -ne $item.$P_POSITION)
        {
            # Set the position of the item (Top | Bottom)
            New-ItemProperty -Path $itemPath -Name $RP_POSITION -Value $item.$P_POSITION > $null

            Write-Verbose "New item property: '$itemPath\$RP_POSITION'" -Verbose:$Verbose
        }

        NewContextMenuItem -Item $item -ItemPath $itemPath -Verbose:$Verbose
    }
}


function RemoveCommandItem([string] $ItemPath, [switch] $Verbose)
{
    Remove-Item -Path $ItemPath\$RP_COMMAND
    Remove-Item -Path $ItemPath

    Write-Verbose "Remove item: '$ItemPath\$RP_COMMAND'" -Verbose:$Verbose
    Write-Verbose "Remove item: '$ItemPath'" -Verbose:$Verbose
}

function RemoveGroupItem([string] $ItemPath, [switch] $Verbose)
{
    Remove-Item -Path $ItemPath\$RP_SHELL
    Remove-Item -Path $ItemPath

    Write-Verbose "Remove item: '$ItemPath\$RP_SHELL'" -Verbose:$Verbose
    Write-Verbose "Remove item: '$ItemPath'" -Verbose:$Verbose
}

function RemoveContextMenuItem([psobject] $Item, [string] $ItemPath, [switch] $Verbose)
{
    $itemNotExists = -not (Get-Item -Path $ItemPath -ErrorAction Ignore)

    if ($itemNotExists)
    {
        Write-Warning "Trying to remove a non-existing path: '$ItemPath'."
        return
    }

    if ($item.$P_OPTIONS)
    {
        # Remove subitems
        foreach ($item in $item.$P_OPTIONS)
        {
            $subitemPath = "$ItemPath\$RP_SHELL\$($item.$P_KEY)"

            RemoveContextMenuItem -Item $item -ItemPath $subitemPath -Verbose:$Verbose
        }

        RemoveGroupItem -ItemPath $ItemPath -Verbose:$Verbose
    }
    else
    {
        RemoveCommandItem -ItemPath $ItemPath -Verbose:$Verbose
    }
}

function Remove-ContextMenuItem([string] $Path, [switch] $Verbose)
{
    $contextMenuItemsJson = GetObjectFromJsonOrXml -Path $Path

    foreach ($item in $contextMenuItemsJson)
    {
        $contextMenuTypePath = $contextMenuTypePaths.$($item.$P_TYPE)

        $itemPath = "$contextMenuTypePath\$($item.$P_KEY)"

        RemoveContextMenuItem -Item $item -ItemPath $itemPath -Verbose:$Verbose
    }   
}


function Start-ContextMenuProcess
(
    [ValidateSet("Import-ContextMenuItem", "Remove-ContextMenuItem")]
    [string] $FunctionName,
    [string] $ArgumentList,
    [string] $Message
) {
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
