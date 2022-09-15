$locations = 'C:\Program Files\program\', 'C:\Program Files (x86)\program\', 'C:\Program Files\Common Files\program\', 'C:\Program Files (x86)\Common Files\program\', 'C:\ProgramData\program\'
foreach ($location in $locations) {
        $Apps = Get-ChildItem -recurse $location
        foreach ($App in $Apps -match ".exe") {
                write-output $App.FullName
                New-NetFirewallRule -DisplayName "Block $App.Name Outbound" -Direction Outbound -Program $App.FullName -RemoteAddress Any -Action Block
                New-NetFirewallRule -DisplayName "Block $App.Name Inbound" -Direction Inbound -Program $App.FullName -RemoteAddress Any -Action Block
        }
}
