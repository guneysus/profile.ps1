Import-Module posh-git

set-alias which get-command
set-alias run Invoke-NpmServe

Function Get-HarSummary () {
  Param(
    [parameter(mandatory=$true)][string]$File
  )
  cat $File | jq '.log.entries' | `
    jq '[.[] | {
      url: .request.url,
      blocked: .timings.blocked,
      connect: .timings.connect,
      send: .timings.send,
      wait: .timings.wait,
      receive: .timings.receive,
    }]' | ConvertFrom-Json
}

$scriptblock = {
    param($commandName,$parameterName,$stringMatch)
    ls | Where-Object { $_ -like "*$stringMatch*.har" }
}

Function Invoke-NpmServe {
  Param(
    [parameter(mandatory=$true)][string]$Target
  )
  if(Test-Path -Path package.json -PathType Leaf) {
    echo $Target
    # echo (cat package.json | ConvertFrom-Json).scripts.serve
    yarn $Target
  }
}

Register-ArgumentCompleter -CommandName Get-HarSummary -ParameterName File -ScriptBlock {
    param($commandName,$parameterName,$stringMatch)
    ls | Where-Object { $_ -like "*$stringMatch*.har" }
}

Register-ArgumentCompleter -CommandName Invoke-NpmServe -ParameterName Target -ScriptBlock {
  echo serve clean build lint
}

Function Set-VsDevShell {
  Import-Module "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
  Enter-VsDevShell fbd9eb8b
}

######## PROMPT

set-content Function:prompt {
    # Start with a blank line, for breathing room :)
    Write-Host ""

    # Reset the foreground color to default
    $Host.UI.RawUI.ForegroundColor = "Gray"

    # Write ERR for any PowerShell errors
    if ($Error.Count -ne 0) {
        Write-Host " $([char]27)[38;5;227;48;5;131m  ERR $([char]27)[0m" -NoNewLine
        $Error.Clear()
    }

    # Write non-zero exit code from last launched process
    if ($LASTEXITCODE -ne "") {
        Write-Host " $([char]27)[38;5;227;48;5;131m  $LASTEXITCODE $([char]27)[0m" -NoNewLine
        $LASTEXITCODE = ""
    }

    # Write any custom prompt environment (f.e., from vs2019.ps1)
    if (get-content variable:\PromptEnvironment -ErrorAction Ignore) {
        Write-Host " $([char]27)[38;5;54;48;5;183m$PromptEnvironment$([char]27)[0m" -NoNewLine
    }

    # Write .NET SDK version
    if ($null -ne (Get-Command "dotnet" -ErrorAction Ignore)) {
        $dotNetVersion = (& dotnet --version)
        Write-Host " $([char]27)[38;5;254;48;5;54m  $dotNetVersion $([char]27)[0m" -NoNewLine
    }

    # Write the current kubectl context
    if ($null -ne (Get-Command "kubectl" -ErrorAction Ignore)) {
        $currentContext = (& kubectl config current-context 2> $null)
        if ($Error.Count -eq 0) {
            Write-Host " $([char]27)[38;5;112;48;5;242m  $([char]27)[38;5;254m$currentContext $([char]27)[0m" -NoNewLine
        }
        else {
            $Error.Clear()
        }
    }

    # Write the current public cloud Azure CLI subscription
    # NOTE: You will need sed from somewhere (for example, from Git for Windows)
    if (Test-Path ~/.azure/clouds.config) {
        $cloudsConfig = parseIniFile ~/.azure/clouds.config
        $azureCloud = $cloudsConfig | Where-Object { $_.Section -eq "[AzureCloud]" }
        if ($null -ne $azureCloud) {
            $currentSub = $azureCloud.Content.subscription
            if ($null -ne $currentSub) {
                $currentAccount = (Get-Content ~/.azure/azureProfile.json | ConvertFrom-Json).subscriptions | Where-Object { $_.id -eq $currentSub }
                if ($null -ne $currentAccount) {
                    Write-Host " $([char]27)[38;5;227;48;5;30m  $([char]27)[38;5;254m$($currentAccount.name) $([char]27)[0m" -NoNewLine
                }
            }
        }
    }

    # Write the current Git information
    if ($null -ne (Get-Command "Get-GitDirectory" -ErrorAction Ignore)) {
        if (Get-GitDirectory -ne $null) {
            Write-Host (Write-VcsStatus) -NoNewLine
        }
    }

    # Write the current directory, with home folder normalized to ~
    $currentPath = (get-location).Path.replace($home, "~")
    $idx = $currentPath.IndexOf("::")
    if ($idx -gt -1) { $currentPath = $currentPath.Substring($idx + 2) }
    $host.UI.RawUI.WindowTitle=$currentPath

    Write-Host " $([char]27)[38;5;227;48;5;28m  $([char]27)[38;5;254m$currentPath $([char]27)[0m " -NoNewline

    # Reset LASTEXITCODE so we don't show it over and over again
    $global:LASTEXITCODE = 0

    # Write one + for each level of the pushd stack
    if ((get-location -stack).Count -gt 0) {
        Write-Host " " -NoNewLine
        Write-Host (("+" * ((get-location -stack).Count))) -NoNewLine -ForegroundColor Cyan
    }

    # Newline
    Write-Host ""

    # Determine if the user is admin, so we color the prompt green or red
    $isAdmin = $false
    $isDesktop = ($PSVersionTable.PSEdition -eq "Desktop")

    if ($isDesktop -or $IsWindows) {
        $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $windowsPrincipal = new-object 'System.Security.Principal.WindowsPrincipal' $windowsIdentity
        $isAdmin = $windowsPrincipal.IsInRole("Administrators") -eq 1
    }
    else {
        $isAdmin = ((& id -u) -eq 0)
    }

    if ($isAdmin) { $color = "Red"; }
    else { $color = "Green"; }

    # Write PS> for desktop PowerShell, pwsh> for PowerShell Core
    if ($isDesktop) {
        Write-Host " PS>" -NoNewLine -ForegroundColor $color
    }
    else {
        Write-Host " pwsh>" -NoNewLine -ForegroundColor $color
    }

    # Always have to return something or else we get the default prompt
    return " "
}

## -- path
$env:PATH +=-join(";", (Join-Path ([System.IO.FileInfo]$PROFILE).Directory "bin"))
$env:PATH +=";C:\Users\aguneysu\AppData\Roaming\Python\Python39\Scripts"
$env:PATH +=";c:\users\aguneysu\scoop\apps\python\3.9.1\Scripts"
$env:PATH +=";C:\Users\aguneysu\.local\bin"

function Set-ProfileDirectory {
  cd ([System.IO.FileInfo]$PROFILE).Directory
}

function Get-Bytes () {
  Param(
    [parameter(mandatory=$true)][string]$text
  )
  $bytes=[System.Text.Encoding]::UTF8.GetBytes($text)
  echo $bytes
}

function Get-Key () {
  Param(
    [parameter(mandatory=$true)][string]$pass,
    [parameter(mandatory=$true)][string]$salt
  )
  $saltBytes=get-bytes $salt
  $passDerive = New-Object Security.Cryptography.Rfc2898DeriveBytes -ArgumentList @($pass, $saltBytes)
  
  $keySize = 256
  $key = $passDerive.GetBytes($keySize / 8)
  echo $key
}

function Get-AesEncrypted () {
  Param(
    [parameter(mandatory=$true)][string]$pass,
    [parameter(mandatory=$true)][string]$salt,
    [parameter(mandatory=$true)][string]$text
  )
  $saltBytes=get-bytes $salt
  $passDerive = New-Object Security.Cryptography.Rfc2898DeriveBytes -ArgumentList @($pass, $saltBytes)
  
  $key = $passDerive.GetBytes(32)
  $IV = $passDerive.GetBytes(16)
  
  $cipher = [Security.Cryptography.SymmetricAlgorithm]::Create('AesManaged')
  $cipher.Mode = [Security.Cryptography.CipherMode]::CBC
  
  $encryptor = $cipher.CreateEncryptor($key, $IV)
  $memoryStream = New-Object -TypeName IO.MemoryStream
  
  $cryptoStream = New-Object -TypeName Security.Cryptography.CryptoStream -ArgumentList @( $memoryStream, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
  
  $strBytes=(Get-Bytes $text)
  
  $cryptoStream.Write($strBytes, 0, $strBytes.Length)
  $cryptoStream.FlushFinalBlock()
  $encryptedBytes = $memoryStream.ToArray()

  # Base64 Encode the encrypted bytes to get a string
  $encryptedString = [Convert]::ToBase64String($encryptedBytes)
  
  echo $encryptedString
}

function Get-QrLink () {
  Param(
    [parameter(mandatory=$true)][string]$text
  )
  $result="https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${text}"
  echo $result
}

function Generate-Qr () {
  $file="C:\Users\aguneysu\Documents\wiki\tasks\PICR-390 Image Recognition Backend API Connection\qr-codes.txt"
  cat $file | % { 
   $text=$_
   $pass=Get-AesEncrypted -pass "7B801AA7-1EBA-4672-8849-7E6B977043B8" -salt "Ivan Medvedev" -text $text
   $qrLink=Get-QrLink $pass
   echo $qrLink
  }
}