param (
    [string]$ProgramName,
    [string[]]$Directories,
    [switch]$Help
)

function Show-Help {
    Write-Host "Usage: .\bulk_firewall_add.ps1 -ProgramName 'ProgramName' [-Directories 'Dir1', 'Dir2', ...]"
    Write-Host "Example: .\bulk_firewall_add.ps1 -ProgramName 'Adobe'"
    Write-Host "Example: .\bulk_firewall_add.ps1 -Directories 'C:\CustomDir\Program', 'D:\AnotherDir\Program'"
}

if ($Help.IsPresent) {
    Show-Help
    return
}

$programDirectories = @{
    "Adobe" = @(
        'C:\Program Files\Adobe',
        'C:\Program Files (x86)\Adobe',
        'C:\Program Files\Common Files\Adobe',
        'C:\Program Files (x86)\Common Files\Adobe',
        'C:\ProgramData\Adobe'
    )
    "Sketchup" = @(
        'C:\Program Files\SketchUp'
    )
}

function Add-FirewallRules {
    param (
        [string]$ProgramName,
        [string[]]$Directories
    )

    foreach ($dir in $Directories) {
        if (Test-Path $dir) {
            $Apps = Get-ChildItem -Path $dir -Recurse -File -Filter "*.exe"
            foreach ($App in $Apps) {
                $ruleNameOut = "Block $($App.Name) Outbound - $ProgramName"
                $ruleNameIn = "Block $($App.Name) Inbound - $ProgramName"
                New-NetFirewallRule -DisplayName $ruleNameOut -Direction Outbound -Program $App.FullName -Action Block
                New-NetFirewallRule -DisplayName $ruleNameIn -Direction Inbound -Program $App.FullName -Action Block
                Write-Output "Firewall rules added for $($App.FullName)"
            }
        }
        else {
            Write-Warning "Directory '$dir' not found."
        }
    }
}

if ($Directories) {
    Add-FirewallRules -ProgramName "Custom" -Directories $Directories
}
elseif ($ProgramName -and $programDirectories.ContainsKey($ProgramName)) {
    Add-FirewallRules -ProgramName $ProgramName -Directories $programDirectories[$ProgramName]
} else {
    Write-Host "Please specify either a predefined program name or manually input directories."
    Write-Host "Use the --help flag for more information on usage."
}
