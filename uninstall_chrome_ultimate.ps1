# Ultimate Chrome Uninstaller with Force Removal
# MUST RUN AS ADMINISTRATOR

# Step 1: Remove Chrome desktop shortcuts
Write-Host "[1/9] Removing Chrome desktop shortcuts..."
$desktopPaths = @(
    [Environment]::GetFolderPath('Desktop'),
    "C:\Users\Public\Desktop"
)

foreach ($desktop in $desktopPaths) {
    $shortcutPath = Join-Path -Path $desktop -ChildPath "Google Chrome.lnk"
    if (Test-Path $shortcutPath) {
        Write-Host "Removing desktop shortcut: $shortcutPath"
        Remove-Item -Path $shortcutPath -Force -ErrorAction SilentlyContinue
    }
}

# Step 2: Terminate all Chrome processes with extreme prejudice
Write-Host "[1/6] Terminating all Chrome processes..."
$processes = @("chrome", "chrome.exe", "chromedriver", "chrome_remote_desktop_host")
foreach ($proc in $processes) {
    Get-Process $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 5

# Run official uninstaller if available
Write-Host "[2/6] Attempting official uninstall..."
$uninstallKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome"
if (Test-Path $uninstallKey) {
    $uninstallString = (Get-ItemProperty $uninstallKey).UninstallString
    if ($uninstallString) {
        Write-Host "Executing: $uninstallString /silent /force-uninstall"
        Start-Process -FilePath cmd.exe -ArgumentList "/c $uninstallString /silent /force-uninstall" -Wait -NoNewWindow
    }
}

# Force delete remaining files with ownership acquisition
Write-Host "[3/6] Force removing program files..."
$chromePaths = @(
    "$env:ProgramFiles\Google\Chrome",
    "$env:ProgramFiles(x86)\Google\Chrome",
    "$env:LOCALAPPDATA\Google\Chrome",
    "$env:USERPROFILE\AppData\Local\Google\Chrome",
    "$env:USERPROFILE\AppData\Roaming\Google\Chrome"
)

foreach ($path in $chromePaths) {
    if (Test-Path $path) {
        Write-Host "Processing: $path"
        # Advanced ownership acquisition using PowerShell ACL
        $acl = Get-Acl -Path $path
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.SetAccessRule($rule)
        Set-Acl -Path $path -AclObject $acl
        # Take ownership recursively
        takeown /f "$path" /r /d y > $null
        icacls "$path" /reset /t /c /q > $null
        icacls "$path" /grant Administrators:F /t /c /q > $null
        # Delete recursively
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        # Verify deletion
        if (Test-Path $path) {
            Write-Host "WARNING: Failed to delete $path"
        }
    }
}

# Clean registry entries
Write-Host "[4/6] Cleaning registry..."
$regPaths = @(
    "HKLM:\Software\Google\Chrome",
    "HKCU:\Software\Google\Chrome",
    "HKLM:\Software\Wow6432Node\Google\Chrome",
    "HKCR:\ChromeHTML",
    "HKCR:\Applications\chrome.exe"
)
foreach ($path in $regPaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Final verification
Write-Host "[5/6] Performing final verification..."
$remainingPaths = @()
foreach ($path in $chromePaths) {
    if (Test-Path $path) {
        $remainingPaths += $path
    }
}

# Report results
Write-Host "[6/6] Uninstallation results..."
if ($remainingPaths.Count -eq 0) {
    Write-Host "SUCCESS: Chrome has been completely uninstalled"
    exit 0
} else {
    Write-Host "FAILURE: The following paths could not be removed:"
    $remainingPaths | ForEach-Object { Write-Host "- $_" }
    exit 1
}