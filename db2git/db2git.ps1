# 2018 (c) Solovev Aleksei <lelkaklel@gmail.com>

$SettingsFile = '.\settings.ini'

function Write-Log {
     [CmdletBinding()]
     param(
         [Parameter()]
         [ValidateNotNullOrEmpty()]
         [ValidateSet('NOTSET','DEBUG','INFO','WARN','ERROR','CRIT')]
         [string]$Severity = 'NOTSET',

         [Parameter()]
         [ValidateNotNullOrEmpty()]
         [string]$ServerName,

         [Parameter()]
         [ValidateNotNullOrEmpty()]
         [string]$Database,
         
         [Parameter()]
         [ValidateNotNullOrEmpty()]
         [string]$Message
     )
     Write-Output ("{0}`t{1}`t{2}`t{3}`t{4}" -f $(Get-Date -f yyyy-MM-ddTHH:mm:ss.ffff),$Severity,$ServerName,$Database,$Message)
 }

function Get-IniContent ($filePath)
{
    $ini = @{}
    switch -regex -file $FilePath
    {
        "^\[(.+)\]" # Section
        {
            $section = $matches[1]
            $ini[$section] = @{}
            $CommentCount = 0
        }
        "^(;.*)$" # Comment
        {
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = "Comment" + $CommentCount
            $ini[$section][$name] = $value
        } 
        "(.+?)\s*=(.*)" # Key
        {
            $name,$value = $matches[1..2]
            $ini[$section][$name] = $value
        }
    }
    return $ini
}

function Get-SettingsValue ([System.Object]$SettingsObject, [string]$Section, [string]$Key)
{
    $Val = ''
    Try { 
        $Val = $SettingsObject[$Section][$Key]
    }
    Catch [system.exception] {
        Write-Error "Error while loading ['$Section']/'$Key' value from file '$SettingsFile' $_"
        return
    }
    return $Val
}

Try { 
    $Settings = Get-IniContent $SettingsFile 
}
Catch [system.exception] {
    Write-Error "Error while loading settings from file '$SettingsFile' $_"
    return
}

$DirectoryToSaveTo = Get-SettingsValue $Settings 'General' 'DirectoryToSaveTo'
$ServerName = Get-SettingsValue $Settings 'General' 'ServerName'
$Database = Get-SettingsValue $Settings 'General' 'Database'
$Login = Get-SettingsValue $Settings 'General' 'Login'
$Password = Get-SettingsValue $Settings 'General' 'Password'
$ExcludeSchemas = Get-SettingsValue $Settings 'General' 'ExcludeSchemas'

Write-Log "INFO" $ServerName $Database "Main script start"

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

#Clear-Host  # clear terminal screen

####################### DELETE OLD FILES #########################

Write-Log "INFO" $ServerName $Database "Delete old files start"
Get-ChildItem -Path $DirectoryToSaveTo -Recurse -exclude .git/ |
Select -ExpandProperty FullName |
sort length -Descending |
Remove-Item -force 
Write-Log "INFO" $ServerName $Database "Delete old files end"

####################### INITIALIZATION ###########################

If (-not (Test-Path $DirectoryToSaveTo)) {
    Try { 
        New-Item $DirectoryToSaveTo -type directory | out-null 
    }
    Catch [system.exception]{
        Write-Error "error while creating '$DirectoryToSaveTo' $_"
        return
    }
}

Write-Log "INFO" $ServerName $Database "'Microsoft.SqlServer.SMO' initialization start"

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
        #[long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::DatabaseRole +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::ExtendedStoredProcedure +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::MessageType +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::ServiceBroker +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::ServiceContract +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::ServiceQueue +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::ServiceRoute +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::SqlAssembly +
        [long][Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::DatabaseScopedConfiguration
) 
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

Write-Log "INFO" $ServerName $Database "'Microsoft.SqlServer.SMO' initialization end"
Write-Log "INFO" $ServerName $Database "Script objects start"

Write-Progress -Activity "Extracting scripts" -status "Scripting 0 / $objects_count" -percentComplete 0

####################### SCRIPT OBJECTS ###########################

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
    
    $File = "$($SavePath)\$($_.name -replace '[\\\/\:\.|]','-').sql"
    
    # tell the scripter object where to write it
    $scripter.Options.Filename = $File;

    Write-Progress -Activity "Extracting scripts" -status "Scripting $i / $objects_count ($($_.Schema)) $File" -percentComplete ($i / $objects_count * 100)
    Write-Log "DEBUG" $ServerName $Database "$File"

    # Create a single element URN array
    $UrnCollection = new-object ("$My.urnCollection")
    $URNCollection.add($_.urn)
    # and write out the object to the specified file
    $scripter.script($URNCollection)
}

"All is written out, stupid human! ╭∩╮(Ο_Ο)╭∩╮"

Write-Progress -Activity "Push to GIT repository"

Write-Log "INFO" $ServerName $Database "Script objects end"

Write-Log "INFO" $ServerName $Database "Push to GIT repository start"

####################### PUSH TO GIT ###########################

Set-Location -Path $DirectoryToSaveTo

git add --all
git commit -m "autocommit $(Get-Date -Format FileDateTime)"
git push origin master

Write-Log "INFO" $ServerName $Database "Push to GIT repository end"

Write-Log "INFO" $ServerName $Database "Main script end"
