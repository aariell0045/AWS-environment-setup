<powershell>
# =============================================================================
# Bootstrap — Sets up the machine as an AD Domain Controller + DNS Server
#   1. Set hostname
#   2. Initialize the NTDS data disk (D:)
#   3. Enable RDP
#   4. Install AD DS + DNS roles
#   5. Promote to Domain Controller (new forest)
# =============================================================================

$ErrorActionPreference = "Stop"
Start-Transcript -Path "C:\bootstrap.log" -Append

# --- Set hostname ---
$currentName = $env:COMPUTERNAME
$targetName  = "${hostname}"

if ($currentName -ne $targetName) {
    Rename-Computer -NewName $targetName -Force
    Write-Output "Hostname set to $targetName"
}

# --- Initialize the NTDS data disk (D:) ---
$disk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and $_.Size -gt 10GB } | Select-Object -First 1
if ($disk) {
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
    $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter D
    Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel "NTDS" -Confirm:$false
    Write-Output "NTDS volume initialized as D:"
} else {
    Write-Output "No raw disk found — NTDS volume may already be initialized."
}

# --- Enable RDP ---
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Write-Output "RDP enabled."

# --- Install AD DS and DNS roles ---
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools
Write-Output "AD DS and DNS roles installed."

# --- Promote to Domain Controller (new forest) ---
$dsrmPassword = ConvertTo-SecureString "${dsrm_password}" -AsPlainText -Force

Install-ADDSForest `
    -DomainName "${domain_name}" `
    -DomainNetbiosName "${domain_netbios}" `
    -SafeModeAdministratorPassword $dsrmPassword `
    -DatabasePath "D:\NTDS" `
    -LogPath "D:\NTDS" `
    -SysvolPath "D:\SYSVOL" `
    -InstallDns:$true `
    -NoRebootOnCompletion:$false `
    -Force:$true

Write-Output "DC promotion initiated. Machine will reboot automatically."
Stop-Transcript
</powershell>
