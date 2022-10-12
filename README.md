# Windows-ContextMenuManager
A simple set of PowerShell scripts to add options to the Windows' context menu from json or xml files.

![context-menu](https://user-images.githubusercontent.com/86477169/189173085-67539358-1f1c-4bba-86d3-eeacd1c5d038.PNG)

# Introduction
We have 2 main scripts: **Import-ContextMenuItem.ps1** and **Remove-ContextMenuItem.ps1**.
What they do is to read all the files listed in **context-menu-list.txt**, 
they can be single files or folders with files in it, and it allows both absolute and relative paths.

As metion these file paths are stored in **context-menu-list.txt**, it's one path per line, and also allows comments that start with "#" and empty lines.

In case you want to change the configuration you can do it with [**settings.ini**](https://github.com/ElianFabian/Windows-ContextMenuManager/blob/main/settings.ini), it stores the name of the list of paths to read (by default it's context-menu-list.txt),
and also as we'll see later you can change the names of the properties in the files as you wish (I don't think you're going to need to do that, but I it's up to you).

Finally the **BasicSetup.ps1** script, it generates the basic needed files needed for the scripts to work and also generates a json and xml template inside the "Source" folder as an example
(this repository already includes those generated files).
In case you have setup your directory and executes the script, it won't override any of your existing scripts with the same name as the generated ones.

There's also the **Update-ContextMenuItem.ps1** that executes first remove and then import.

# How context menus work
This is an example of how to create items and groups with json and xml:

**JSON**
``` js
[
    // Group item
    {
        "Key" : "utils",
        "Name" : "Utils",
        "Type" : "File",
        "Extended" : true,
        "Icon" : "an/Arbitrary/Path/image.ico",
        "Options" : [...]
    },
    // Command item
    {
        "Key" : "command_util",
        "Name" : "Command Util",
        "Type" : "File",
        "Icon" : "an/Arbitrary/Path/image.ico",
        "Command" : "powershell.exe -NoExit -Command (Get-Content '%1' -Raw).Length"
    }
]
```
**XML**
```xml
<Root>
    <ItemGroup
        Key="utils"
        Name="Utils"
        Type="File"
        Icon="an/Arbitrary/Path/image.ico"
        Extended="true">

        <Item ... />
        <Item ... />
        ...
    </ItemGroup>

    <Item
        Key="command_util"
        Name="Command Util"
        Type="File"
        Icon="an/Arbitrary/Path/image.ico"
        Command="powershell.exe -NoExit -Command (Get-Content '%1' -Raw).Length" />
</Root>
```

We have 2 kind of items in context menus, **commands** and **groups** of commands.
The first type executes code and the other it's just a container.

All the items in context menus have 3 common properties:
- <b>Key</b>: it's the way to identify an item in the same level of depth, this is the name stored in the Windows' registry.
Avoid changing the key because if you import the context menu, then change one key and then try to remove it won't do it properly.
-  **Name**: this is the name you will see in the context menu.
- **Icon**: it's the icon of the item, it must be a .ico file, you can use an absolute or a relative path.

We have to different first-level items, which are the ones who aren't inside another group, these are kind of special because they have 2 properties subitems can't have:
- **Type**: indicates where the context menu items must appear. There are 4 types:
> [File, Directory, Desktop, Drive]
- **Extended**: when present and set to true you have to hold *Shift* to make the item visible. Setting the value to false has the same effect as removing the property.

Lastly there 2 left properties that exclusively belong to either commands or groups:
- **Commad**: it's a string of code.
- **Options**: it's an array of groups and commads (in xml files you add the items as child nodes).

To better undertand the json structure consider checking out this json template: [context-menu-items.json](https://github.com/ElianFabian/Windows-ContextMenuManager/blob/main/Resource/context-menu-items.json).

In here you have the xml template: [context-menu-items.xml](https://github.com/ElianFabian/Windows-ContextMenuManager/blob/main/Resource/context-menu-items.xml).

Keep in mind that in xml the tag names are actually arbitrary, if you change the names of **Root**, **Item** or **ItemGroup** tags it will have no effect.

# How to use

Assuming you downloaded the repository and you already have your file(s) ready you only have to execute **Import-ContextMenuItem.ps1** to import your context menu items. It may take a few seconds to import it, you will know it finished when the empty console window closes automatically.
When you want to remove the context menu just execute **Remove-ContextMenuItem.ps1**.
Removing it's faster than importing.

In case your file has a wrong format or even inappropriate keys or values it will stop executing and shows you what's the error and the specific file (remember you can work with more than one file).

# Extra
In case you want to know what is the manual way of adding context menus items check this [medium article](https://medium.com/analytics-vidhya/creating-cascading-context-menus-with-the-windows-10-registry-f1cf3cd8398f).
