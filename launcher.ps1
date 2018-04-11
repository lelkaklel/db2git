# 2018 (c) Solovev Aleksei <lelkaklel@gmail.com>

$SettingsFile = '.\src\settings.ini'

Clear-Host  # clear terminal screen

# change work dir to launcher dir
$ScriptPath = $MyInvocation.MyCommand.Path
$Dir = Split-Path $ScriptPath
Set-Location -Path $Dir

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

git clone $ScriptRepository ".\src"

powershell -ExecutionPolicy Unrestricted -File ".\src\db_to_git.ps1"