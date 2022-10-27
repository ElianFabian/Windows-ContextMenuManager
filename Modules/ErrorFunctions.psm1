. "$PSScriptRoot\Scripts\Initialization.ps1"


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

function TestXmlString($XmlString)
{
    try
    {
        [xml]($XmlString) > $null

        return $true
    }
    catch { return $false }
}

function TestFileContentErrors_WriteError([string] $Path, [string] $Content, [psobject] $Object)
{
    $fileExtension = $fileExtension = [System.IO.Path]::GetExtension($Path)

    if (-not (IsRunningAsAdministrator))
    {
        WriteError "Script must run as administrator."
        return $false
    }

    $isJsonError = ($fileExtension -eq '.json') -and (-not (TestJsonString $Content))
    $isXmlError  = ($fileExtension -eq '.xml') -and (-not (TestXmlString $Content))
    $isFileError = $isJsonError -or $isXmlError

    if ($isFileError)
    {
        WriteError "Wrong format in file: $Path" -Category InvalidData
        return $false
    }
    if (-not (TestObjectKeyNamesAndValues_WriteError -Items $Object -Path $Path))
    {
        return $false
    }

    return $true
}

function TestObjectKeyNamesAndValues_WriteError([array] $Items, [string] $Path)
{
    $isValid = $true

    $keysOfTheSameLevelOfDepth = new-Object System.Collections.Generic.HashSet[string]

    foreach ($item in $Items)
    {
        foreach ($propertyName in $item.PSObject.Properties.Name)
        {
            if (-not ($VALID_PROPERTY_SET.Contains($propertyName)))
            {
                WriteError "'$propertyName' is not a valid item property name at:`n$Path`n`nThis is the valid set from settings.ini: [$($VALID_PROPERTY_SET -join ', ')] " -Category InvalidData
                return $false
            }

            $propertyValue = $item.$propertyName

            switch ($propertyName)
            {
                $P_KEY
                {
                    if ( -not $keysOfTheSameLevelOfDepth.Add($propertyValue))
                    {
                        WriteError "'$propertyValue' is a repeated key at:`n$Path`n`nKeys must be unique in the same level of depth."
                        return $false
                    }
                }
                $P_EXTENDED
                {
                    if (-not ($propertyValue -like $true -or $propertyValue -like $false))
                    {
                        WriteError "'$propertyValue' is not a valid value for the 'Extended' property at:`n$Path.`n`nThis is the valid set: [true, false]"
                        return $false
                    }
                }
                $P_TYPE
                {
                    if (-not ($contextMenuTypePaths.Keys -contains $propertyValue))
                    {
                        WriteError "'$propertyValue' is not a valid value for the 'Type' property at:`n$Path.`n`nThis is the valid set: [$($contextMenuTypePaths.Keys -join ', ')]"
                        return $false
                    }
                }
                $P_ICON
                {
                    if (-not (Test-Path $propertyValue))
                    {
                        WriteError "'$propertyValue' is not an existing file at:`n$Path"
                        return $false
                    }
                }
                $P_OPTIONS { $isValid = TestObjectKeyNamesAndValues_WriteError -Items $propertyValue -Path $Path }
            }
        }
    }

    return $isValid
}