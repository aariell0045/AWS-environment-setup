<powershell>
# =============================================================================
# Bootstrap — MINIMAL. Only does what Ansible can't do before connecting:
#   1. Set hostname
#   2. Enable WinRM over HTTPS (Ansible connects via SSM port forwarding)
#   3. Initialize the NTDS data disk (D:)
# Everything else (AD DS install, DC promotion) is Ansible's job.
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

# --- Configure WinRM HTTPS ---
# Self-signed cert for WinRM transport (Ansible connects via SSM port forward to localhost:5986)
$cert = New-SelfSignedCertificate `
    -DnsName $targetName, "localhost" `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -NotAfter (Get-Date).AddYears(3)

# Remove existing HTTPS listener if any
Get-ChildItem WSMan:\localhost\Listener | Where-Object {
    $_.Keys -contains "Transport=HTTPS"
} | ForEach-Object {
    Remove-Item -Path $_.PSPath -Recurse -Force
}

# Create HTTPS listener
New-Item -Path WSMan:\localhost\Listener `
    -Transport HTTPS `
    -Address * `
    -CertificateThumbPrint $cert.Thumbprint `
    -Force

# Firewall rule for WinRM HTTPS
New-NetFirewallRule `
    -DisplayName "WinRM HTTPS (Ansible)" `
    -Direction Inbound `
    -LocalPort 5986 `
    -Protocol TCP `
    -Action Allow `
    -Profile Any

# Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# WinRM settings
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $false
Set-Item WSMan:\localhost\MaxTimeoutms -Value 1800000

Restart-Service WinRM

Write-Output "WinRM HTTPS listener configured."

# --- Reboot to apply hostname ---
Stop-Transcript
Restart-Computer -Force
</powershell>
