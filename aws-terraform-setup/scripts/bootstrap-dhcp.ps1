<powershell>
# =============================================================================
# Bootstrap — DHCP Server (lab/learning only)
# Runs in two phases:
#   Phase 1 (first boot):  Set hostname, enable RDP, install DHCP, reboot
#   Phase 2 (second boot): Join domain, authorize DHCP in AD, configure scope
# =============================================================================

$phaseFile = 'C:\bootstrap-phase1-done.txt'
$logFile   = 'C:\bootstrap.log'

Start-Transcript -Path $logFile -Append

# ---- Phase 2: Join domain and configure DHCP ----
if (Test-Path $phaseFile) {
    Write-Output '=== Phase 2: Joining domain and configuring DHCP ==='

    # Skip if already domain-joined
    if ((Get-WmiObject Win32_ComputerSystem).Domain -eq '${domain_name}') {
        Write-Output 'Already joined to domain. Cleaning up.'
        Unregister-ScheduledTask -TaskName 'BootstrapPhase2' -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item 'C:\bootstrap-phase2.ps1' -Force -ErrorAction SilentlyContinue
        Stop-Transcript
        exit 0
    }

    # Set DNS to point to the DC so we can find the domain
    $dcIp = '${dc_private_ip}'
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dcIp
    Write-Output ('DNS set to DC at ' + $dcIp)

    # Wait for the DC/domain to be reachable (DC may still be promoting)
    $maxAttempts = 60
    for ($i = 1; $i -le $maxAttempts; $i++) {
        try {
            $dc = (Resolve-DnsName -Name ("_ldap._tcp.dc._msdcs.${domain_name}") -Type SRV -ErrorAction Stop | Select-Object -First 1)
            Write-Output ("DC locator SRV resolved: " + $dc.NameTarget)
            break
        } catch {
            Write-Output ("Waiting for domain DNS records... attempt " + $i + "/" + $maxAttempts)
            Start-Sleep -Seconds 10
        }
        if ($i -eq $maxAttempts) {
            throw "Domain DNS records not available after waiting; cannot join domain."
        }
    }

    # Join the domain
    $domainAdminBase64 = '${domain_admin_password_base64}'
    $domainAdminPlain  = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($domainAdminBase64))
    $cred = New-Object System.Management.Automation.PSCredential('${domain_netbios}\ds-admin', (ConvertTo-SecureString $domainAdminPlain -AsPlainText -Force))

    Add-Computer -DomainName '${domain_name}' -Credential $cred -Force
    Write-Output 'Joined domain ${domain_name}.'

    # Authorize DHCP server in AD
    Add-DhcpServerInDC -DnsName ('${hostname}' + '.${domain_name}') -IPAddress $((Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1).IPAddress)
    Write-Output 'DHCP server authorized in AD.'

    # Configure DHCP scope
    Add-DhcpServerSecurityGroup -ErrorAction SilentlyContinue
    Restart-Service DHCPServer

    Add-DhcpServerv4Scope `
        -Name 'Lab Scope' `
        -StartRange 192.168.10.100 `
        -EndRange 192.168.10.200 `
        -SubnetMask 255.255.255.0 `
        -State Active

    Set-DhcpServerv4OptionValue `
        -ScopeId 192.168.10.0 `
        -DnsDomain '${domain_name}' `
        -DnsServer $dcIp `
        -Router 192.168.10.1

    Set-DhcpServerv4Scope -ScopeId 192.168.10.0 -LeaseDuration (New-TimeSpan -Days 8)

    Write-Output 'DHCP scope 192.168.10.0/24 configured (range .100-.200, lease 8 days).'

    # Clean up
    Unregister-ScheduledTask -TaskName 'BootstrapPhase2' -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item 'C:\bootstrap-phase2.ps1' -Force -ErrorAction SilentlyContinue

    Write-Output 'DHCP setup complete. Rebooting...'
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

# Install DHCP role
Install-WindowsFeature -Name DHCP -IncludeManagementTools
Write-Output 'DHCP role installed.'

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
