<#
Script Name: Daily System Maintenance on First Login
Performs:
✅ Cleans temp files and cache
✅ Disables unwanted startup apps
✅ Stops unnecessary services (SysMain, Fax, DiagTrack)
✅ Clears DNS and resets Winsock
✅ Cleans Windows Update cache
✅ Runs disk optimization
✅ Disables background apps
✅ Logs system info (uptime, memory, disk)
✅ Sends email report
✅ Forces restart after completion
✅ Runs automatically on first login of the day
#>

#-------------------- Configuration --------------------
$LogPath = "C:\ITMaintenanceLogs"
$LastRunFile = "$LogPath\LastRun.txt"
$LogFile = "$LogPath\MaintenanceLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$EmailFrom = "IT@tatamd.com"
$EmailTo = "bhanu.priya@tatamd.com, sandeep.a@tatamd.com"
$SMTPServer = "smtp.tatamd.com"
$SMTPPort = 25
$JobStatus = "COMPLETED"
#--------------------------------------------------------

# Create log directory if missing
if (!(Test-Path -Path $LogPath)) {
    New-Item -ItemType Directory -Force -Path $LogPath | Out-Null
}

Function Write-Log {
    param([string]$Message)
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
    Write-Output "$Timestamp - $Message"
}

#-------------------- Run Only Once Per Day --------------------
if (Test-Path $LastRunFile) {
    $LastRun = Get-Content $LastRunFile | Out-String
    if ($LastRun -eq (Get-Date).ToString("yyyy-MM-dd")) {
        Write-Log "Script already executed today. Exiting..."
        exit
    }
}
(Get-Date).ToString("yyyy-MM-dd") | Out-File -FilePath $LastRunFile -Force
#---------------------------------------------------------------

#-------------------- User Alert --------------------
msg * "⚠️ Your system will perform self-maintenance and restart after completion. Please save your work immediately."
Write-Log "User notified about maintenance."
Start-Sleep -Seconds 60
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
Uptime: $([math]::Round($uptime.TotalHours,2))
