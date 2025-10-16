<#
Script Name: System Maintenance Automation
Schedule: Monday & Thursday at 3:30 PM
Performs:
✅ Cleans temp files and cache
✅ Disables unwanted startup apps
✅ Stops unnecessary services (SysMain, Fax, DiagTrack)
✅ Clears DNS and resets Winsock
✅ Cleans Windows Update cache
✅ Runs disk optimization
✅ Disables background apps
✅ Creates log file
✅ Sends email report (uptime, memory, disk)
✅ Warns user 5 mins before start
✅ Forces restart at the end
#>

#-------------------- Configuration --------------------
$LogPath = "C:\ITMaintenanceLogs"
$LogFile = "$LogPath\MaintenanceLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$EmailFrom = "IT@tatamd.com"
$EmailTo = "bhanu.priya@tatamd.com, sandeep.a@tatamd.com"
$SMTPServer = "smtp.tatamd.com"  # Update to your SMTP relay
$SMTPPort = 25
$JobStatus = "COMPLETED"
#--------------------------------------------------------

# Create log directory if not exists
if (!(Test-Path -Path $LogPath)) {
    New-Item -ItemType Directory -Force -Path $LogPath | Out-Null
}

Function Write-Log {
    param([string]$Message)
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
    Write-Output "$Timestamp - $Message"
}

#-------------------- User Alert --------------------
msg * "⚠️ Your system is scheduled to perform self-maintenance and will RESTART in 5 minutes. Please save your work immediately."
Write-Log "User notified about maintenance 5 minutes before execution."
Start-Sleep -Seconds 300  # Wait 5 minutes before actual maintenance
#----------------------------------------------------

try {
    Write-Log "=== System Maintenance Started ==="

    #--- Clean Temp Files & Windows Cache ---
    Write-Log "Cleaning temporary files..."
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    #--- Disable Unwanted Startup Apps ---
    Write-Log "Disabling unwanted startup apps..."
    Get-CimInstance Win32_StartupCommand | ForEach-Object {
        Write-Log "Disabled: $($_.Name)"
        $_ | Remove-CimInstance -ErrorAction SilentlyContinue
    }

    #--- Stop Unnecessary Services ---
    $services = @("SysMain", "Fax", "DiagTrack")
    foreach ($service in $services) {
        Write-Log "Stopping and disabling service: $service"
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
    }

    #--- Clear DNS & Reset Winsock ---
    Write-Log "Clearing DNS cache and resetting Winsock..."
    ipconfig /flushdns | Out-Null
    netsh winsock reset | Out-Null

    #--- Clean Windows Update Cache ---
    Write-Log "Cleaning Windows Update cache..."
    net stop wuauserv -ErrorAction SilentlyContinue
    Remove-Item "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    net start wuauserv | Out-Null

    #--- Disk Optimization ---
    Write-Log "Running disk optimization..."
    Optimize-Volume -DriveLetter C -ReTrim -Verbose | Out-Null
    Optimize-Volume -DriveLetter C -Defrag -Verbose | Out-Null

    #--- Disable Background Apps ---
    Write-Log "Disabling background apps..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -ErrorAction SilentlyContinue

    #--- Collect System Info ---
    Write-Log "Collecting system information..."
    $uptime = (Get-Date) - (gcim Win32_OperatingSystem).LastBootUpTime
    $memory = (Get-CimInstance Win32_OperatingSystem)
    $totalRAM = [math]::Round($memory.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($memory.FreePhysicalMemory / 1MB, 2)
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $totalDisk = [math]::Round($disk.Size / 1GB, 2)
    $freeDisk = [math]::Round($disk.FreeSpace / 1GB, 2)

    $SystemReport = @"
=== System Health Report ===
Hostname: $env:COMPUTERNAME
Uptime: $([math]::Round($uptime.TotalHours,2)) hours
Total RAM: $totalRAM GB
Free RAM: $freeRAM GB
Total Disk (C:): $totalDisk GB
Free Disk (C:): $freeDisk GB
"@

    Write-Log $SystemReport
    Write-Log "=== System Maintenance Completed Successfully ==="

} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    $JobStatus = "NOT COMPLETED"
}

#-------------------- Email Notification --------------------
$Subject = "System Maintenance Activity $JobStatus"
$Body = (Get-Content -Path $LogFile | Out-String) + "`r`n" + $SystemReport

try {
    Send-MailMessage -From $EmailFrom -To $EmailTo -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort
    Write-Log "Email notification sent successfully."
} catch {
    Write-Log "Failed to send email: $($_.Exception.Message)"
}
#------------------------------------------------------------

#-------------------- Force Restart -------------------------
Write-Log "Restarting system in 30 seconds..."
shutdown /r /f /t 30 /c "System Maintenance Completed. Restarting to finalize cleanup." | Out-Null
Write-Log "Restart command issued successfully."
#------------------------------------------------------------

Write-Log "=== End of Script ==="
