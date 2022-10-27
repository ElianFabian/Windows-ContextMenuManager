Import-Module -Name "$PSScriptRoot\ErrorFunctions.psm1"



function ConvertXmlObjectToJsonObject($XmlRoot)
{
    $itemArray = New-Object System.Collections.Generic.List[PSCustomObject]

    foreach ($child in $XmlRoot.ChildNodes)
    {
        $jsonItem = [PSCustomObject]@{}

        foreach ($attribute in $child.Attributes)
        {
            Add-Member -InputObject $jsonItem -Name $attribute.Name -Value $attribute.'#text' -MemberType NoteProperty
        }

        $itemArray.Add($jsonItem)

        if ($child.HasChildNodes)
        { 
            Add-Member -InputObject $jsonItem -Name $PROPERTY_OPTIONS -Value (ConvertXmlObjectToJsonObject $child) -MemberType NoteProperty
        }
    }

    return $itemArray
}

function GetObjectFromJsonOrXml($Path)
{
    $fileExtension = [System.IO.Path]::GetExtension($Path)

    $fileContent = Get-Content $Path -Encoding utf8 -Raw

    $object = switch ($fileExtension)
    {
        .json { $fileContent | ConvertFrom-Json }
        .xml { ConvertXmlObjectToJsonObject -XmlRoot ([xml]($fileContent)).DocumentElement }
        default
        {
            Write-Error "$Path file type '$fileExtension' not supported."
            return $null
        }
    }

    if (-not (TestFileContentErrors_WriteError -Path $Path -Content $fileContent -Object $object))
    {
        return $null
    }

    return $object
}