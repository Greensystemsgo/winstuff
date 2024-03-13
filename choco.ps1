param (
    [switch]$InstallSchTask,
    [string]$UserGroup,
    [switch]$Help,
    [switch]$ForceReinstallChoco,
    [switch]$ForceUpdateTask
)

$packageGroups = @{
    "default" = @("7zip.install", "firefox", "notepadplusplus.install", "powershell")
    "family" = @("7zip.install", "adobereader", "firefox", "powershell", "teamviewer", "vlc")
    "dev" = @("7zip.install", "firefox", "git.install", "notepadplusplus.install", "powershell", "putty", "python", "vscode")
    "dev2" = @("7zip.install", "adobereader", "firefox", "git.install", "go", "googlechrome", "microsoft-windows-terminal", "notepadplusplus.install", "powershell", "putty", "python", "vscode")
    "all" = @(
        "1password",
        "7zip.install",
        "adobereader",
        "audacity",
        "autodesk-fusion360",
        "ccleaner",
        "chirp",
        "cura-new",
        "discord",
        "ea-app",
        "expressvpn",
        "firefox",
        "foxitreader",
        "freedoom",
        "gimp",
        "git.install",
        "go",
        "googlechrome",
        "handbrake.install",
        "jre8",
        "makemkv",
        "mkvtoolnix",
        "microsoft-teams",
        "microsoft-windows-terminal",
        "naps2",
        "nmap",
        "notepadplusplus.install",
        "openshot",
        "openvpn",
        "openttd",
        "origin",
        "pia",
        "powershell",
        "prusaslicer",
        "putty",
        "python",
        "qflipper",
        "realvnc",
        "slack",
        "steam",
        "superslicer",
        "tailscale",
        "teamviewer",
        "telegram",
        "ultravnc",
        "virtualbox",
        "virtualbox-guest-additions-guest.install",
        "vlc",
        "vnc-viewer",
        "vscode",
        "wesnoth",
        "zoom"
    )
}

function Show-Help {
    Write-Host "Usage: .\choco.ps1 [options]"
    Write-Host ""
    Write-Host "This script manages the installation of specified Chocolatey packages and can configure a scheduled task to automatically update those packages. It allows for flexible package management based on user groups."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallSchTask         Install or update a scheduled task to automatically update Chocolatey packages."
    Write-Host "                          The task runs with the highest privileges at user logon."
    Write-Host "  -UserGroup <GroupName>  Specify a predefined user group for package installation. Available groups include 'default',"
    Write-Host "                          'groupA', 'groupB', etc. Each group has a predefined list of packages."
    Write-Host "                          Without this option, or if 'all' is specified, the script will prompt for the installation"
    Write-Host "                          of each package listed under the 'all' group, allowing for selective installation."
    Write-Host "  -Help                   Displays this help message and exits the script."
    Write-Host "  -ForceReinstallChoco    Forces the reinstallation of Chocolatey, even if it is already installed. Useful for"
    Write-Host "                          repairing a Chocolatey installation or ensuring the latest version."
    Write-Host "  -ForceUpdateTask        Forces the update of the scheduled task, regardless of its current configuration. Use this"
    Write-Host "                          if changes have been made to the task settings within the script."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\choco.ps1 -InstallSchTask"
    Write-Host "      Installs or updates the scheduled task without installing any packages."
    Write-Host ""
    Write-Host "  .\choco.ps1 -UserGroup groupA"
    Write-Host "      Installs all packages defined for 'groupA' without prompting. Does not touch the scheduled task."
    Write-Host ""
    Write-Host "  .\choco.ps1 -InstallSchTask -UserGroup groupA"
    Write-Host "      Installs or updates the scheduled task and installs all packages for 'groupA' without prompting."
    Write-Host ""
    Write-Host "  .\choco.ps1"
    Write-Host "      Without any options, the script will prompt the user for the installation of each package listed under 'all'."
    Write-Host ""
    Write-Host "Note: Use the -ForceReinstallChoco or -ForceUpdateTask options with caution, as they can alter your system configuration."
}

function CheckAndReportTaskDiscrepancies {
    $discrepanciesFound = $false
    $existingTask = Get-ScheduledTask -TaskName "ChocoAutoUpdate"

    $desiredAction = 'PowerShell.exe -WindowStyle Hidden -NoProfile -Command "choco upgrade all -y"'
    $existingAction = $existingTask.Actions.Execute + ' ' + $existingTask.Actions.Arguments
    if ($existingAction -ne $desiredAction) {
        Write-Host "Action mismatch. Expected: '$desiredAction', found: '$existingAction'"
        $discrepanciesFound = $true
    }

    $triggerMatch = $false
    foreach ($trigger in $existingTask.Triggers) {
        if ($trigger -is [CimInstance] -and $trigger.CimClass.CimClassName -eq "MSFT_TaskLogonTrigger") {
            $triggerMatch = $true
            break
        }
    }

    if (-not $triggerMatch) {
        $foundTypes = $existingTask.Triggers | ForEach-Object {
            if ($_ -is [CimInstance]) {
                $_.CimClass.CimClassName
            }
        } -join ', '
        Write-Host "Trigger mismatch. Expected type: 'MSFT_TaskLogonTrigger', found types: '$foundTypes'"
        $discrepanciesFound = $true
    }

    $desiredRunLevel = 'Highest'
    $existingRunLevel = $existingTask.Principal.RunLevel
    if ($existingRunLevel -ne $desiredRunLevel) {
        Write-Host "Principal mismatch. Expected RunLevel: '$desiredRunLevel', found RunLevel: '$existingRunLevel'"
        $discrepanciesFound = $true
    }

    return $discrepanciesFound
}

function Install-ScheduledChocoUpdate {
    $taskName = "ChocoAutoUpdate"
    $existingTask = Get-ScheduledTask | Where-Object { $_.TaskName -eq $taskName }

    if ($existingTask) {
        Write-Host "Task $taskName already exists. Checking configuration..."
        
        $discrepanciesFound = CheckAndReportTaskDiscrepancies

        if ($discrepanciesFound -or $ForceUpdateTask) {
            Write-Host "Updating task due to configuration mismatch..."
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Register-ScheduledTaskWithNewSettings
        } else {
            Write-Host "Existing task configuration matches the intended setup. No changes made."
        }
    } else {
        Write-Host "Creating the task $taskName..."
        Register-ScheduledTaskWithNewSettings
    }
}

function Register-ScheduledTaskWithNewSettings {
    $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-WindowStyle Hidden -NoProfile -Command "choco upgrade all -y"'
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
    $principal.RunLevel = 'Highest'

    Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "ChocoAutoUpdate" -Description "Automatically update Chocolatey packages at logon"
    Write-Host "Scheduled task ChocoAutoUpdate created/updated for Chocolatey package auto-update with admin privileges."
}

function Ensure-ChocolateyInstalled {
    if (-not $ForceReinstallChoco -and (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey is already installed."
    } else {
        Write-Host "Installing or reinstalling Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}

function Install-ChocolateyPackages {
    if ($Help) {
        Show-Help
        return
    }

    Ensure-ChocolateyInstalled

    if ($InstallSchTask) {
        Install-ScheduledChocoUpdate
        return
    }

    $selectedPackages = @()

    $packagesToInstall = $null
    if ($UserGroup -and $packageGroups.ContainsKey($UserGroup)) {
        $packagesToInstall = $packageGroups[$UserGroup]
    } else {
        $packagesToInstall = $packageGroups["all"]
    }

    Write-Host "Packages to install: $($packagesToInstall -join ', ')"

    foreach ($package in $packagesToInstall) {
        $installPackage = $false
        if (-not $UserGroup -or $UserGroup -eq "all") {
            $userResponse = Read-Host ("Install " + $package + "? (Y/N)")
            $installPackage = $userResponse -eq 'Y'
        } else {
            $installPackage = $true
        }

        if ($installPackage) {
            $selectedPackages += $package
        }
    }

    if ($selectedPackages.Count -gt 0) {
        Write-Host "Installing selected packages: $($selectedPackages -join ', ')"
        foreach ($pkg in $selectedPackages) {
            choco install $pkg -y
        }
    } else {
        Write-Host "No packages selected for installation."
    }
}

if ($Help) {
    Show-Help
} else {
    Ensure-ChocolateyInstalled

    if ($InstallSchTask) {
        Install-ScheduledChocoUpdate
    } else {
        Install-ChocolateyPackages
    }
}
