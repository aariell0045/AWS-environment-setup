<powershell>
# =============================================================================
# Bootstrap — DFS Server (lab/learning)
# Runs in two phases:
#   Phase 1 (first boot):  Set hostname, enable RDP, install DFS roles, reboot
#   Phase 2 (second boot): Join domain, create DFS namespace and folder
# =============================================================================

$phaseFile = 'C:\bootstrap-phase1-done.txt'
$logFile   = 'C:\bootstrap.log'

Start-Transcript -Path $logFile -Append

# ---- Phase 2: Join domain and configure DFS ----
if (Test-Path $phaseFile) {
    Write-Output '=== Phase 2: Joining domain and configuring DFS ==='
    $ErrorActionPreference = 'Stop'

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

    # Wait for the DC/domain to be reachable (DC may still be promoting)
    # DC needs ~15-20 min: Phase 1 install + reboot + Phase 2 promote + reboot + final verify
    $maxAttempts = 120
    for ($i = 1; $i -le $maxAttempts; $i++) {
        try {
            $dc = (Resolve-DnsName -Name ("_ldap._tcp.dc._msdcs.${domain_name}") -Type SRV | Where-Object { $_.NameTarget } | Select-Object -First 1)
            if ($dc -and $dc.NameTarget) {
                Write-Output ("DC locator SRV resolved: " + $dc.NameTarget)
                break
            }
            throw "SRV query returned no NameTarget"
        } catch {
            Write-Output ("Waiting for domain DNS records... attempt " + $i + "/" + $maxAttempts)
            Start-Sleep -Seconds 15
        }
        if ($i -eq $maxAttempts) {
            throw "Domain DNS records not available after waiting; cannot join domain."
        }
    }

    # Extra wait for DC services to fully stabilize after DNS is available
    Write-Output 'DNS resolved. Waiting 60s for DC services to stabilize...'
    Start-Sleep -Seconds 60

    # Join the domain (with retries — DC may not be fully ready even after DNS resolves)
    $domainAdminBase64 = '${domain_admin_password_base64}'
    $domainAdminPlain  = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($domainAdminBase64))
    $cred = New-Object System.Management.Automation.PSCredential('${domain_netbios}\Administrator', (ConvertTo-SecureString $domainAdminPlain -AsPlainText -Force))

    $joinMaxRetries = 10
    for ($j = 1; $j -le $joinMaxRetries; $j++) {
        try {
            Add-Computer -DomainName '${domain_name}' -Credential $cred -Force -ErrorAction Stop
            Write-Output 'Joined domain ${domain_name}.'
            break
        } catch {
            Write-Output ("Domain join attempt " + $j + "/" + $joinMaxRetries + " failed: " + $_.Exception.Message)
            if ($j -eq $joinMaxRetries) { throw }
            Start-Sleep -Seconds 30
        }
    }

    # Create shared folders for DFS
    New-Item -Path 'C:\DFSRoots\Public' -ItemType Directory -Force | Out-Null
    New-Item -Path 'C:\DFSRoots\Departments' -ItemType Directory -Force | Out-Null
    New-SmbShare -Name 'Public' -Path 'C:\DFSRoots\Public' -FullAccess 'Everyone' | Out-Null
    New-SmbShare -Name 'Departments' -Path 'C:\DFSRoots\Departments' -FullAccess 'Everyone' | Out-Null
    Write-Output 'DFS shared folders created.'

    # Clean up
    Unregister-ScheduledTask -TaskName 'BootstrapPhase2' -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item 'C:\bootstrap-phase2.ps1' -Force -ErrorAction SilentlyContinue

    Write-Output 'DFS setup complete. Rebooting...'
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

# Install DFS roles (Namespace + Replication)
Install-WindowsFeature -Name FS-DFS-Namespace, FS-DFS-Replication -IncludeManagementTools
Write-Output 'DFS Namespace and DFS Replication roles installed.'

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
