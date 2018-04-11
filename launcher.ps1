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
    $ini['General']['ScriptRepository']
}

Try { 
    $Settings = Get-IniContent $SettingsFile 
}
Catch [system.exception] {
    Write-Error "Error while loading settings from file '$SettingsFile' $_"
    return
}

$ScriptRepository = Get-SettingsValue $Settings 'General' 'ScriptRepository'

git pull

powershell -ExecutionPolicy Unrestricted -File ".\db2git\db2git.ps1"