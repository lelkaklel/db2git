# 2018 (c) Solovev Aleksei <lelkaklel@gmail.com>

$SettingsFile = '.\settings.ini'

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

function Out-IniFile($InputObject, $FilePath)
{
    $outFile = New-Item -ItemType file -Path $Filepath
    foreach ($i in $InputObject.keys)
    {
        if (!($($InputObject[$i].GetType().Name) -eq "Hashtable"))
        {
            #No Sections
            Add-Content -Path $outFile -Value "$i=$($InputObject[$i])"
        } else {
            #Sections
            Add-Content -Path $outFile -Value "[$i]"
            Foreach ($j in ($InputObject[$i].keys | Sort-Object))
            {
                if ($j -match "^Comment[\d]+") {
                    Add-Content -Path $outFile -Value "$($InputObject[$i][$j])"
                } else {
                    Add-Content -Path $outFile -Value "$j=$($InputObject[$i][$j])" 
                }

            }
            Add-Content -Path $outFile -Value ""
        }
    }
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

function Db2Git-Setup {
    $ini = @{}
    $ini['General'] = @{}
    Write-Host "=============== DB2GIT SETUP ================"
    $DirectoryToSaveTo = Read-Host "Directory for storing scripts:"
    $ini['General']['DirectoryToSaveTo'] = $DirectoryToSaveTo
    $ServerName = Read-Host "SQL Server name:"
    $ini['General']['ServerName'] = ''
    $Database = Read-Host "Database name:"
    $ini['General']['Database'] = ''
    $Login = Read-Host "SQL Server authentication Login:"
    $ini['General']['Login'] = ''
    $Password = Read-Host "SQL Server authentication Password:"
    $ini['General']['Password'] = ''
    $ExcludeSchemas = Read-Host "SQL Server schemas to be excluded (default 'sys,Information_Schema'):"
    If ($ExcludeSchemas -eq '') {"sys,Information_Schema"} else {$ExcludeSchemas}
    $ini['General']['ExcludeSchemas'] = If ($ExcludeSchemas -eq '') {"sys,Information_Schema"} else {$ExcludeSchemas}
    Out-IniFile $ini ".\settings.ini"
    Write-Host "============================================="
}

# create settings file if not exitsts
If (-not (Test-Path ".\settings.ini")) {
    Db2Git-Setup
}

Try { 
    $Settings = Get-IniContent $SettingsFile 
}
Catch [system.exception] {
    Write-Error "Error while loading settings from file '$SettingsFile' $_"
    return
}

git pull

powershell -ExecutionPolicy Unrestricted -File ".\db2git\db2git.ps1"