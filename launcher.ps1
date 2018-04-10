Clear-Host  # clear terminal screen

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Set-Location -Path $dir

$SettingsFile = '.\settings.ini'

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


$ScriptRepository = Get-SettingsValue $Settings 'General' 'ScriptRepository'
$DirectoryToSaveTo = Get-SettingsValue $Settings 'General' 'DirectoryToSaveTo'
$ServerName = Get-SettingsValue $Settings 'DB' 'ServerName'
$Database = Get-SettingsValue $Settings 'DB' 'Database'
$Login = Get-SettingsValue $Settings 'DB' 'Login'
$Password = Get-SettingsValue $Settings 'DB' 'Password'
$ExcludeSchemas = Get-SettingsValue $Settings 'DB' 'ExcludeSchemas'

Write-Verbose "ScriptRepository = $ScriptRepository"
Write-Verbose "DirectoryToSaveTo = $DirectoryToSaveTo"
Write-Verbose "ServerName = $ServerName"
Write-Verbose "Database = $Database"
Write-Verbose "Login = $Login"
Write-Verbose "Password = $Password"
Write-Verbose "ExcludeSchemas = $ExcludeSchemas"

powershell -ExecutionPolicy Unrestricted -File ".\db_to_git.ps1" $ServerName $Database $Login $Password $DirectoryToSaveTo $ExcludeSchemas