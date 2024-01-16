param (
    [switch]$InstallSchTask,
    [switch]$Help
)

function Show-Help {
    Write-Host "Usage:"
    Write-Host "  .\choco.ps1 [-InstallSchTask] [-Help]"
    Write-Host "Options:"
    Write-Host "  -InstallSchTask   Install a scheduled task for updating Chocolatey packages"
    Write-Host "  -Help             Show this help message"
}

function Ensure-ChocolateyInstalled {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

function Install-ScheduledChocoUpdate {
    $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-NoProfile -Command "choco upgrade all -y"'
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive

    Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "ChocoAutoUpdate" -Description "Automatically update Chocolatey packages at logon"
    Write-Host "Scheduled task created for Chocolatey package auto-update."
}

function Install-ChocolateyPackages {
    $packages = @(
        "7zip.install",
        "adobereader",
        "audacity",
        "ccleaner",
        "firefox",
        "git.install",
        "googlechrome",
        "jre8", 
        "microsoft-teams",
		"naps2.install",
        "notepadplusplus.install",
		"openshot",
        "powershell",
        "putty",
        "python",
        "slack",
        "teamviewer",
        "vlc",
        "vscode", 
        "zoom"
    )

    $selectedPackages = @()

    foreach ($package in $packages) {
        Write-Host "Current package: $package"
        $userResponse = Read-Host ("Install " + $package + "? (Y/N)")
        if ($userResponse -eq 'Y') {
            if (!(choco list --local-only | Select-String "$package")) {
                $selectedPackages += $package
            } else {
                Write-Host "$package is already installed."
            }
        }
    }

    if ($selectedPackages.Count -gt 0) {
        choco install $selectedPackages -y
    } else {
        Write-Host "No packages selected for installation."
    }
}

if ($Help) {
    Show-Help
    return
}

Ensure-ChocolateyInstalled

if ($InstallSchTask) {
    Install-ScheduledChocoUpdate
} else {
    Install-ChocolateyPackages
}
