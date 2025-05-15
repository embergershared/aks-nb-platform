[CmdletBinding()]

param
(
  [Parameter(ValuefromPipeline = $true, Mandatory = $true)] [string]$Param1,
  [Parameter(ValuefromPipeline = $true, Mandatory = $true)] [string]$Param2,
  [Parameter(ValuefromPipeline = $true, Mandatory = $true)] [string]$Param3,
  [Parameter(ValuefromPipeline = $true, Mandatory = $true)] [string]$Param4
)

Start-Transcript -Path "C:\GitLab-Runner-setup_transcript.txt"
$filePath = "C:\GitLab-Runner-setup_log.txt"

function AddLog ($message) {
  Add-Content -Path $filePath -Value "$(Get-Date): $message"
  Write-Host "$(Get-Date): $message"
}

New-Item -Path $filePath -ItemType File -Force
AddLog "GitLab Runner setup started"
AddLog "Parameters received: Param1 = ""$($Param1)"", Param2 = ""$($Param2)"", Param3 = ""$($Param3)"", Param4 = ""$($Param4)"""

AddLog "Setting values from parameters"
$TOKEN = $Param1
$StAcctName = $Param2
$StContainerName = $Param3
$MsiClientId = $Param4
AddLog "Variables values: TOKEN = ""$($TOKEN)"", StAcctName = ""$($StAcctName)"", StContainerName = ""$($StContainerName)"", MsiClientId = ""$($MsiClientId)"""

Set-TimeZone -Name "Eastern Standard Time"
AddLog "Time zone set to EST"

Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
AddLog "Chocolatey installed"

Function Install-ChocoPackage {
  param (
    [Parameter(Mandatory = $true)]
    [Object]$Packages
  )

  foreach ($package in $Packages) {
    $command = "choco install $package -y"
    Write-Host
    AddLog "Chocolatey installing package: $package"
    Write-Host "Install-ChocoPackage => Executing: $command"
    Invoke-Expression $command
  }
}

$gl_runner_packages = @(
  "git",
  "powershell-core",
  "azure-cli",
  "kubernetes-cli",
  "kubernetes-helm"
  "azure-kubelogin",
  "terraform",
  "sqlpackage",
  "sqlcmd",
  "visualstudio2022buildtools",
  "vscode"
)

Install-ChocoPackage -Packages $gl_runner_packages
AddLog "Chocolatey Packages installed"

Enable-WindowsOptionalFeature -Online -FeatureName containers -All -NoRestart
AddLog "Added Windows feature containers"

curl.exe -o docker.zip -LO https://download.docker.com/win/static/stable/x86_64/docker-20.10.13.zip
Expand-Archive docker.zip -DestinationPath C:\
[Environment]::SetEnvironmentVariable("Path", "$($env:path);C:\docker", [System.EnvironmentVariableTarget]::Machine)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
dockerd --register-service
AddLog "Docker installed"

New-Item -Path 'C:\GitLab-Runner' -ItemType Directory
Set-Location 'C:\GitLab-Runner'

curl.exe -o gitlab-runner.exe -LO https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe

.\gitlab-runner.exe install
.\gitlab-runner.exe start

.\gitlab-runner.exe register --url https://gitlab.com --token $TOKEN --executor "shell" --non-interactive --description "hww poc windows runner"
AddLog "GitLab Runner installed"

[Environment]::SetEnvironmentVariable("Path", "$($env:path);C:\Program Files\Git\bin;C:\Program Files\Microsoft VS Code\bin;C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin;C:\Program Files\PowerShell\7;C:\Program Files\SqlCmd;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin", [System.EnvironmentVariableTarget]::Machine)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
AddLog "Added paths to the PATH environment variable"

AddLog "Downloading BACPAC files from Azure Blob"
AddLog "Creating directory C:\sql-bacpac"
New-Item -Path 'C:\sql-bacpac' -ItemType Directory
AddLog "Az login with User Assigned Identity"
az login --identity --client-id $MsiClientId
AddLog "Loading blob list from Azure Blob Storage Container"
$blobList = az storage blob list --account-name $StAcctName --container-name $StContainerName --auth-mode login | ConvertFrom-Json
$blobList
foreach ($blob in $blobList) {
  AddLog "Downloading blob $($blob.name)"
  az storage blob download --account-name $StAcctName --container-name $StContainerName --name $blob.name --file "c:\sql-bacpac\$($blob.name)" --auth-mode login
}

AddLog "Launching Server restart"
Restart-Computer -Force