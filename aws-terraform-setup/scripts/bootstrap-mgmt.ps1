<powershell>
# =============================================================================
# Bootstrap — Management Server (all RSAT tools)
# Runs in two phases:
#   Phase 1 (first boot):  Set hostname, enable RDP, install RSAT tools, reboot
#   Phase 2 (second boot): Join domain
# =============================================================================

$phaseFile = 'C:\bootstrap-phase1-done.txt'
$logFile   = 'C:\bootstrap.log'

Start-Transcript -Path $logFile -Append

# ---- Phase 2: Join domain ----
if (Test-Path $phaseFile) {
    Write-Output '=== Phase 2: Joining domain ==='

    # Skip if already domain-joined
    if ((Get-WmiObject Win32_ComputerSystem).Domain -eq '${domain_name}') {
        Write-Output 'Already joined to domain. Cleaning up.'
        Unregister-ScheduledTask -TaskName 'BootstrapPhase2' -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item 'C:\bootstrap-phase2.ps1' -Force -ErrorAction SilentlyContinue
        Stop-Transcript
        exit 0
    }

    # Set DNS to point to the DC
    $dcIp = '${dc_private_ip}'
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dcIp
    Write-Output ('DNS set to DC at ' + $dcIp)

    # Join the domain
    $domainAdminBase64 = '${domain_admin_password_base64}'
    $domainAdminPlain  = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($domainAdminBase64))
    $cred = New-Object System.Management.Automation.PSCredential('${domain_netbios}\Administrator', (ConvertTo-SecureString $domainAdminPlain -AsPlainText -Force))

    Add-Computer -DomainName '${domain_name}' -Credential $cred -Force
    Write-Output 'Joined domain ${domain_name}.'

    # Clean up
    Unregister-ScheduledTask -TaskName 'BootstrapPhase2' -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item 'C:\bootstrap-phase2.ps1' -Force -ErrorAction SilentlyContinue

    Write-Output 'Management server setup complete. Rebooting...'
    Stop-Transcript
    Restart-Computer -Force
    exit 0
}

# ---- Phase 1: Prepare the machine ----
Write-Output '=== Phase 1: Preparing machine ==='

$ErrorActionPreference = 'Stop'

# Set hostname
$currentName = $env:COMPUTERNAME
$targetName  = '${hostname}'

if ($currentName -ne $targetName) {
    Rename-Computer -NewName $targetName -Force
    Write-Output ('Hostname set to ' + $targetName)
}

# Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
Write-Output 'RDP enabled.'

# Install ALL RSAT management tools
Install-WindowsFeature -Name RSAT-AD-Tools -IncludeAllSubFeature       # dsa.msc, dssite.msc, AD PowerShell
Install-WindowsFeature -Name RSAT-DNS-Server                           # dnsmgmt.msc
Install-WindowsFeature -Name RSAT-DHCP                                 # dhcpmgmt.msc
Install-WindowsFeature -Name RSAT-DFS-Mgmt-Con                        # dfsmgmt.msc
Install-WindowsFeature -Name GPMC                                      # gpmc.msc (Group Policy)
Install-WindowsFeature -Name RSAT-File-Services                        # File services tools
Write-Output 'All RSAT management tools installed.'

# Schedule Phase 2
$action    = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-ExecutionPolicy Unrestricted -File C:\bootstrap-phase2.ps1"
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'BootstrapPhase2' -Action $action -Trigger $trigger -Principal $principal -Force

Copy-Item $MyInvocation.MyCommand.Path 'C:\bootstrap-phase2.ps1' -Force

New-Item -Path $phaseFile -ItemType File -Force | Out-Null
Write-Output 'Phase 1 complete. Rebooting...'

Stop-Transcript
Restart-Computer -Force
</powershell>
