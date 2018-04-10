<#
.SYNOPSIS
Generate file-per-object scripts of specified server and database.
.DESCRIPTION
Generate file-per-object scripts of specified server and database to specified directory. Attempts to create specified directory if not found.
.PARAMETER ServerName
Specifies the database server hostname.
.PARAMETER Database
Specifies the name of the database you want to script as objects to files.
.PARAMETER Login
Specifies the SQL Server authentication Login.
.PARAMETER Password
Specifies the SQL Server authentication Password.
.PARAMETER DirectoryToSaveTo
Specifies the directory where you want to store the generated scripts.
.PARAMETER ExcludeSchemas
Specifies the database schemas that you do not want to script.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, Position = 1)]
        [string]$ServerName,
    [Parameter(Mandatory = $true, Position = 2)]
        [string]$Database,
    [Parameter(Mandatory = $true, Position = 3)]
        [string]$Login,
    [Parameter(Mandatory = $true, Position = 4)]
        [string]$Password,
    [Parameter(Mandatory = $true, Position = 5)]
        [string]$DirectoryToSaveTo,
    [Parameter(Mandatory = $false, Position = 6)]
        [string]$ExcludeSchemas
)

$ExcludeSchemasList = @()

ForEach ($_ in $ExcludeSchemas.Split("{,}")) {
    $ExcludeSchemasList += $_
}

###################### CHANGE COLORS ############################

$bckgrnd = 'Black'
$Host.UI.RawUI.BackgroundColor = $bckgrnd
$Host.UI.RawUI.ForegroundColor = 'White'
$Host.PrivateData.ErrorBackgroundColor
$Host.PrivateData.ConsolePaneBackgroundColor = $bckgrnd
$Host.PrivateData.ConsolePaneForegroundColor = 'White'
$Host.PrivateData.ConsolePaneTextBackgroundColor = $bckgrnd
$Host.PrivateData.ErrorForegroundColor = 'Red'
$Host.PrivateData.ErrorBackgroundColor = $bckgrnd
$Host.PrivateData.WarningForegroundColor = 'Magenta'
$Host.PrivateData.WarningBackgroundColor = $bckgrnd
$Host.PrivateData.DebugForegroundColor = 'Yellow'
$Host.PrivateData.DebugBackgroundColor = $bckgrnd
$Host.PrivateData.VerboseForegroundColor = 'Green'
$Host.PrivateData.VerboseBackgroundColor = $bckgrnd
Try { 
    $Host.PrivateData.ProgressForegroundColor = 'White'
    $Host.PrivateData.ProgressBackgroundColor = 'DarkRed'
}
Catch [system.exception]{
}

Clear-Host  # clear terminal screen

####################### DELETE OLD FILES #########################

Get-ChildItem -Path $DirectoryToSaveTo -Recurse -exclude .git/ |
Select -ExpandProperty FullName |
sort length -Descending |
Remove-Item -force 

####################### SCRIPT OBJECTS ###########################

# Load SMO assembly, and if we're running SQL 2008 DLLs load the SMOExtended and SQLWMIManagement libraries
$v = [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.SMO')
if ((($v.FullName.Split(','))[1].Split('='))[1].Split('.')[0] -ne '9') {
   [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended') | out-null
}
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoEnum') | out-null
 
set-psdebug -strict # catch a few extra bugs
$ErrorActionPreference = "stop"
$My='Microsoft.SqlServer.Management.Smo'
$srv = new-object ("$My.Server") $ServerName # attach to the server
$srv.ConnectionContext.LoginSecure = $false
$srv.ConnectionContext.Login = $Login
$srv.ConnectionContext.Password = $Password
if ($srv.ServerType-eq $null) # if it managed to find a server
   {
   Write-Error "Sorry, but I couldn't find Server '$ServerName' "
   return
}
$scripter = new-object ("$My.Scripter") $srv # create the scripter
$scripter.Options.ToFileOnly = $true
$scripter.Options.ExtendedProperties= $true # yes, we want these
$scripter.Options.DRIAll= $true # and all the constraints
$scripter.Options.Indexes= $true # Yup, these would be nice
$scripter.Options.Triggers= $true # This should be includede
$scripter.Options.AllowSystemObjects = $false
$scripter.Options.AppendToFile = $false
$scripter.Options.ChangeTracking = $false
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
$scripter.Options.Encoding = $Utf8NoBomEncoding
# first we get the bitmap of all the object types we want

$objectsToDo = [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::All -bxor (
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::Certificate +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::DatabaseRole +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::ExtendedStoredProcedure +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::MessageType +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::ServiceBroker +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::ServiceContract +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::ServiceQueue +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::ServiceRoute +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::SqlAssembly) 
# and we store them in a datatable
$d = new-object System.Data.Datatable
# get just the tables
$d = $srv.databases[$Database].EnumObjects($objectsToDo) 

# filter by objects database schema
if ($ExcludeSchemasList.Count -gt 0) {
    $d = $d | Where-object { $ExcludeSchemasList -notcontains $_.schema -and -not $_.IsSystemObject } 
}

$objects_count = $d.Rows.Count
$i = 0

Write-Progress -Activity "Extracting scripts" -status "Scripting 0 / $objects_count" -percentComplete 0

# and write out each scriptable object as a file in the directory you specify
$d | ForEach-Object { # for every object we have in the datatable.
    
    $i += 1

    $SavePath="$($DirectoryToSaveTo)\$($_.DatabaseObjectTypes)\$($_.Schema)"

    # create the directory if necessary (SMO doesn't).
    if (!( Test-Path -path $SavePath )) { # create it if not existing
        Try { 
            New-Item $SavePath -type directory | out-null 
        }
        Catch [system.exception]{
             Write-Error "error while creating '$SavePath' $_"
             return
        }
    }
    # tell the scripter object where to write it
    $scripter.Options.Filename = "$($SavePath)\$($_.name -replace '[\\\/\:\.]','-').sql";

    Write-Progress -Activity "Extracting scripts" -status "Scripting $i / $objects_count ($($_.Schema)) $SavePath\$($_.name -replace '[\\\/\:\.]','-').sql" -percentComplete ($i / $objects_count * 100)

    # Create a single element URN array
    $UrnCollection = new-object ("$My.urnCollection")
    $URNCollection.add($_.urn)
    # and write out the object to the specified file
    $scripter.script($URNCollection)
}

"All is written out, stupid human! ╭∩╮(Ο_Ο)╭∩╮"

Write-Progress -Activity "Pushing to GIT repository"

Set-Location -Path $DirectoryToSaveTo

git add --all
git commit -m "autocommit $(Get-Date -Format FileDateTime)"
git push origin master

#Clear-Host  # clear terminal screen

git diff --text HEAD HEAD^

