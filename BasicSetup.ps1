# Setup.ps1


# Generated files:
# - context-menu-items.txt
#    Contains all the paths of the jsons that will be imported.
#    They can be single files or a path to a folder with jsons.
#
# - settings.ini:
#    It's the configuration, you can change the name
#    that the json properties must use and the path to the
#    list of json paths (can also be a folder with jsons).
#    You can also change the name of "context-menu-items.txt".
#
# - context-menu-items.json:
#    This file it's just a template, you can remove it
#    and use create the ones you want, and then add their paths
#    to "context-menu-items.txt".
#
# - context-menu-items.xml:
#    The same as context-menu-items.json but in xml.
#
# The "Source" folder is actually not required, it's only to store the json but you can change it in "context-menu-list.txt"

# If the generated files already exists they won't be overriden.


$sourceFileName          = "Source"
$contextMenuListFilename = "context-menu-list.txt"
$defaultContextMenuBasename = "context-menu-items"

# Create settings.ini ------------------------------------------------------------------------------
$settingsDefaultContent = @"
# Names of the context menu properties
PROPERTY_KEY     =Key
PROPERTY_NAME    =Name
PROPERTY_TYPE    =Type
PROPERTY_COMMAND =Command
PROPERTY_OPTIONS =Options
PROPERTY_EXTENDED=Extended
PROPERTY_ICON    =Icon

# File with the list of json paths (or folders with json files) to import
CONTEXT_MENU_LIST_PATH=./context-menu-list.txt

# If true shows information about what is happening when importing or removing
CONSOLE_VERBOSE=false

# If true when you execute the import ot remove script it will not close automatically
CONSOLE_NO_EXIT=false

"@

New-Item -Path "settings.ini" -Value $settingsDefaultContent -ErrorAction Ignore



# Create default context-menu-list.txt ------------------------------------------------------------------------------
$contextMenuListFileContent = @"
# You can add all the files you want, with relative or absolute path, also folders with a list of json files
# As you see commets starts with a hash (#)

# This is the deafault json with a context menu
$sourceFileName/$defaultContextMenuJson

"@

New-Item -Path $contextMenuListFilename -Value $contextMenuListFileContent -ErrorAction Ignore


# Create default json template ------------------------------------------------------------------------------
$contextMenuTemplateJsonContent = @"
[
    {
        "Key" : "file_utils",
        "Name" : "File Utils",
        "Type" : "File",
        "Extended" : true,
        "Icon" : "C:/Program Files/internet explorer/images/bing.ico",
        "Options" : [
            {
                "Key" : "read_content",
                "Name" : "Read content",
                "Icon" : "C:/Program Files/internet explorer/images/bing.ico",
                "Command" : "powershell.exe -NoExit -Command Get-Content '%1'"
            },
            {
                "Key" : "remove_content",
                "Name" : "Remove content",
                "Icon" : "C:/Program Files/internet explorer/images/bing.ico",
                "Command" : "powershell.exe -Command Set-Content %1 -Value ''"
            },
            {
                "Key" : "subutils",
                "Name" : "SubUtils",
                "Icon" : "C:/Program Files/internet explorer/images/bing.ico",
                "Options" : [
                    {
                        "Key" : "nothing",
                        "Name" : "Press me! Nothing won't happen.",
                        "Icon" : "C:/Program Files/internet explorer/images/bing.ico"
                    }
                ]
            }
        ]
    },
    {
        "Key" : "get_size_of_all_files",
        "Name" : "Get size of folder",
        "Type" : "Directory",
        "Icon" : "C:/Program Files/internet explorer/images/bing.ico",
        "Command" : "powershell.exe -NoExit -Command (Get-ChildItem -File) | ForEach-Object {`$total = 0}  { `$total += `$_.Length } { `$total }"
    },
    {
        "Key" : "get_number_of_characters",
        "Name" : "Get number of characters",
        "Type" : "File",
        "Icon" : "C:/Program Files/internet explorer/images/bing.ico",
        "Command" : "powershell.exe -NoExit -Command (Get-Content '%1' -Raw).Length"
    }
]

"@

New-Item -Path $sourceFileName -ItemType Directory -ErrorAction Ignore
New-Item -Path "$sourceFileName/$defaultContextMenuBasename.json" -Value $contextMenuTemplateJsonContent -ErrorAction Ignore


# Create default xml template ------------------------------------------------------------------------------
$contextMenuTemplateXmlContent = @"
<Root>
    <Item
        Key="file_utils"
        Name="File Utils"
        Icon="C:/Program Files/internet explorer/images/bing.ico"
        Extended="true"
        Type="File"
    >
        <Item
            Key="read_content"
            Name="Read content"
            Icon="C:/Program Files/internet explorer/images/bing.ico"
            Command="powershell.exe -NoExit -Command Get-Content '%1'"
        />
        <Item
            Key="remove_content"
            Name="Remove content"
            Icon="C:/Program Files/internet explorer/images/bing.ico"
            Command="powershell.exe -Command Set-Content %1 -Value ''"
        />
        <Item
            Key="subutils"
            Name="Get size of folder"
            Icon="C:/Program Files/internet explorer/images/bing.ico"
        >
            <Item
                Key="nothing"
                Name="Press me! Nothing will happen."
                Icon="C:/Program Files/internet explorer/images/bing.ico"
            />
        </Item>
    </Item>
    <Item
        Key="get_size_of_all_files"
        Name="Get size of folder"
        Icon="C:/Program Files/internet explorer/images/bing.ico"
        Type="Directory"
        Command="powershell.exe -NoExit -Command (Get-ChildItem -File) | ForEach-Object { `$total = 0 } { `$total += `$_.Length } { `$total }"
    />
    <Item
        Key="get_number_of_characters"
        Name="Get number of characters"
        Icon="C:/Program Files/internet explorer/images/bing.ico"
        Type="File"
        Command="powershell.exe -NoExit -Command (Get-Content '%1' -Raw).Length" />
</Root>

"@

New-Item -Path "$sourceFileName/$defaultContextMenuBasename.xml" -Value $contextMenuTemplateXmlContent -ErrorAction Ignore
