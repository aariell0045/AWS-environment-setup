<powershell>
# =============================================================================
# Bootstrap — Sets up the machine as an AD Domain Controller + DNS Server
# Runs in two phases:
#   Phase 1 (first boot):  Set hostname, init disk, enable RDP, install roles, reboot
#   Phase 2 (second boot): Promote to Domain Controller
# =============================================================================

$phaseFile = 'C:\bootstrap-phase1-done.txt'
$logFile   = 'C:\bootstrap.log'

Start-Transcript -Path $logFile -Append

# ---- Phase 2: Promote to DC (runs after reboot) ----
if (Test-Path $phaseFile) {
    Write-Output '=== Phase 2: Promoting to Domain Controller ==='

    # Wait for D: drive to be ready
    $retries = 0
    while (-not (Test-Path 'D:\') -and $retries -lt 30) {
        Write-Output 'Waiting for D: drive...'
        Start-Sleep -Seconds 10
        $retries++

        # Try to initialize if raw disk exists
        $disk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and $_.Size -gt 5GB } | Select-Object -First 1
        if ($disk) {
            Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
            New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter D | Out-Null
            Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel 'NTDS' -Confirm:$false
            Write-Output 'NTDS volume initialized as D:'
        }
    }

    if (-not (Test-Path 'D:\')) {
        Write-Output 'ERROR: D: drive not available after waiting. Aborting.'
        Stop-Transcript
        exit 1
    }

    $dsrmPasswordBase64 = '${dsrm_password_base64}'
    $dsrmPasswordPlain  = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($dsrmPasswordBase64))
    $dsrmPassword       = ConvertTo-SecureString $dsrmPasswordPlain -AsPlainText -Force

    Install-ADDSForest `
        -DomainName '${domain_name}' `
        -DomainNetbiosName '${domain_netbios}' `
        -SafeModeAdministratorPassword $dsrmPassword `
        -DatabasePath 'D:\NTDS' `
        -LogPath 'D:\NTDS' `
        -SysvolPath 'D:\SYSVOL' `
        -InstallDns:$true `
        -NoRebootOnCompletion:$false `
        -Force:$true

    Write-Output 'DC promotion complete. Machine will reboot.'
    Stop-Transcript
    exit 0
}

# ---- Phase 1: Prepare the machine (first boot) ----
Write-Output '=== Phase 1: Preparing machine ==='

$ErrorActionPreference = 'Stop'

# Set hostname
$currentName = $env:COMPUTERNAME
$targetName  = '${hostname}'

if ($currentName -ne $targetName) {
    Rename-Computer -NewName $targetName -Force
    Write-Output ('Hostname set to ' + $targetName)
}

# Initialize the NTDS data disk (D:)
$disk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and $_.Size -gt 5GB } | Select-Object -First 1
if ($disk) {
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
    New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter D | Out-Null
    Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel 'NTDS' -Confirm:$false
    Write-Output 'NTDS volume initialized as D:'
} else {
    Write-Output 'No raw disk found yet - will retry in Phase 2.'
}

# Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
Write-Output 'RDP enabled.'

# Install AD DS and DNS roles
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools
Write-Output 'AD DS and DNS roles installed.'

# Schedule Phase 2 to run after reboot
$action  = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-ExecutionPolicy Unrestricted -File C:\bootstrap-phase2.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'BootstrapPhase2' -Action $action -Trigger $trigger -Principal $principal -Force

# Copy this script as Phase 2 (it will detect the phase file and run promotion)
Copy-Item $MyInvocation.MyCommand.Path 'C:\bootstrap-phase2.ps1' -Force

# Mark Phase 1 as done
New-Item -Path $phaseFile -ItemType File -Force | Out-Null
Write-Output 'Phase 1 complete. Rebooting...'

Stop-Transcript
Restart-Computer -Force
</powershell>
