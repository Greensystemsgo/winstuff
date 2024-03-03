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
    "all" = @(
        "7zip.install",
        "adobereader",
        "audacity",
        "ccleaner",
        "firefox",
        "git.install",
        "googlechrome",
        "jre8",
        "microsoft-teams",
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
}

function Show-Help {
    Write-Host "Usage: .\choco.ps1 [options]"
    Write-Host "Options:"
    Write-Host "  -InstallSchTask         Install a scheduled task for updating Chocolatey packages."
    Write-Host "  -UserGroup <GroupName>  Install packages for a predefined user group (e.g., 'default', 'groupA', 'groupB')."
    Write-Host "                          Without this option, the script will prompt for installation of each package in the 'all' list."
    Write-Host "  -Help                   Show this help message."
    Write-Host "  -ForceReinstallChoco    Force reinstalling Chocolatey, even if it's already installed."
    Write-Host "  -ForceUpdateTask        Force updating the scheduled task, even if it exists and matches the configuration."
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  .\choco.ps1 -UserGroup groupA"
    Write-Host "  This will automatically install all packages defined for 'groupA' without prompting."
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

    # Determine the list of packages to install based on the user group
    $packagesToInstall = $null
    if ($UserGroup -and $packageGroups.ContainsKey($UserGroup)) {
        $packagesToInstall = $packageGroups[$UserGroup]
    } else {
        $packagesToInstall = $packageGroups["all"]
    }

    # Interactive or automated installation based on the user group or absence thereof
    foreach ($package in $packagesToInstall) {
        $installPackage = $false
        if (-not $UserGroup -or $UserGroup -eq "all") {
            $userResponse = Read-Host "Install $package? (Y/N)"
            $installPackage = $userResponse -eq 'Y'
        } else {
            $installPackage = $true
        }

        if ($installPackage -and !(choco list --local-only | Select-String "^$package$")) {
            Write-Host "Installing $package..."
            choco install $package -y
        } elseif ($installPackage) {
            Write-Host "$package is already installed."
        }
    }
}

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
