Start-Transcript -Path "C:\Dev-VM-setup_transcript.txt"
$filePath = "C:\Dev-VM-setup_log.txt"

function AddLog ($message) {
  Add-Content -Path $filePath -Value "$(Get-Date): $message"
  Write-Host "$(Get-Date): $message"
}

New-Item -Path $filePath -ItemType File -Force

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
    AddLog
    AddLog "Chocolatey installing package: $package"
    AddLog "Install-ChocoPackage => Executing: $command"
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
  "notepadplusplus",
  "sysinternals",
  "kubectx",
  "kubens",
  "nerd-fonts-jetbrainsmono",
  "nerd-fonts-firamono",
  "nerd-fonts-firacode",
  "openssl",
  "vscode"
)

Install-ChocoPackage -Packages $gl_runner_packages
AddLog "Chocolatey Packages installed"

AddLog "  Processing PowerShell Aliases"
If (!(test-path $PsHome\profile.ps1)) {
  New-Item -Force -Path $PsHome\profile.ps1
}
$content = Get-Content -Path $PsHome\profile.ps1
$shortcuts = @{ tf = "terraform"; k = "kubectl"; kctx = "kubectx"; kns = "kubens" }
$shortcuts.keys | ForEach-Object { 
  AddLog "    Processing shortcut: $_ for $($shortcuts.$_).exe"
  $aliasToCheckAdd = "Set-Alias -Name $_ -Value $($shortcuts.$_).exe" # $path\$($shortcuts.$_).exe
  AddLog "    Checking: ""$aliasToCheckAdd"""
  if (($content -eq $null) -or (!$content.Contains($aliasToCheckAdd))) {
    AddLog "    Alias is not present, creating it."
    Add-Content $PsHome\profile.ps1 $aliasToCheckAdd -Force
  }
  else { AddLog "    Alias is present." }
}
AddLog "  Done with PowerShell Aliases"

Enable-WindowsOptionalFeature -Online -FeatureName containers -All -NoRestart
AddLog "Added Windows feature containers"

curl.exe -o docker.zip -LO https://download.docker.com/win/static/stable/x86_64/docker-20.10.13.zip
Expand-Archive docker.zip -DestinationPath C:\
[Environment]::SetEnvironmentVariable("Path", "$($env:path);C:\docker", [System.EnvironmentVariableTarget]::Machine)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
dockerd --register-service
AddLog "Docker installed"

[Environment]::SetEnvironmentVariable("Path", "$($env:path);C:\Program Files\Git\bin;C:\Program Files\Microsoft VS Code\bin;C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin;C:\Program Files\PowerShell\7;C:\Program Files\SqlCmd;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin", [System.EnvironmentVariableTarget]::Machine)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
AddLog "Added paths to the PATH environment variable"

AddLog "Launching Server restart"
Restart-Computer -Force