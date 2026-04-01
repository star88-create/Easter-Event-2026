@echo off
setlocal DisableDelayedExpansion

:: 1. Check for Admin rights and elevate if needed
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting Administrator permissions...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: 2. Run PowerShell (Skipping 16 lines)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -LiteralPath '%~f0' | Select-Object -Skip 16 | Out-String | Invoke-Expression"
pause
exit /b

# --- POWERSHELL STARTS HERE ---

# A. DISABLE QUICKEDIT & FORCE UI REFRESH
$definition = '[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode); [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode); [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle); [DllImport("user32.dll")] public static extern bool UpdateWindow(IntPtr hWnd); [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();'
$type = Add-Type -MemberDefinition $definition -Name "Win32Utils" -Namespace "Win32" -PassThru
$hConsoleInput = $type::GetStdHandle(-10) 
$hConsoleWindow = $type::GetConsoleWindow()
$mode = 0
if ($type::GetConsoleMode($hConsoleInput, [ref]$mode)) {
    $type::SetConsoleMode($hConsoleInput, $mode -band -not 0x0040) 
}

Clear-Host
Write-Host "--- Lineage Justice Automated Installer ---" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "Initializing setup..." -ForegroundColor Gray

# 1. DYNAMIC PATH SETUP (Handles OneDrive Automatically)
$desktopPath = [Environment]::GetFolderPath("Desktop")

if ($desktopPath -match "OneDrive") {
    Write-Host "OneDrive detected! Routing installation to: $desktopPath" -ForegroundColor Magenta
} else {
    Write-Host "Standard Desktop detected: $desktopPath" -ForegroundColor Gray
}

$targetFolder = Join-Path $desktopPath "Lineage Justice"
$exePath = Join-Path $targetFolder "jLauncher.exe"

# 2. INITIAL CHECK: Exit if the folder already exists
if (Test-Path -Path $targetFolder) {
    Write-Host "`n[!] 'Lineage Justice' is already on your Desktop." -ForegroundColor Yellow
    Write-Host "Please remove the existing folder if you wish to reinstall."
    exit
}

# 3. DEFENDER EXCLUSION: Whitelist the correct Desktop
Write-Host "Whitelisting Desktop in Windows Defender..." -ForegroundColor Cyan
Add-MpPreference -ExclusionPath $desktopPath

# 4. DOWNLOAD
$url = "https://www.l1justice.com/static/Lineage_Justice.zip"
$destinationZip = Join-Path $env:TEMP "Lineage_Justice.zip"
if (Test-Path $destinationZip) { Remove-Item $destinationZip -Force }

Write-Host "Downloading game files..." -ForegroundColor Cyan
Start-BitsTransfer -Source $url -Destination $destinationZip

# 5. EXTRACTION
Write-Host "Extracting files to Desktop..." -ForegroundColor Cyan
Expand-Archive -Path $destinationZip -DestinationPath $desktopPath -Force
Remove-Item $destinationZip -Force

# B. FORCE UI REFRESH
[Console]::CursorVisible = $true
$type::UpdateWindow($hConsoleWindow)
Start-Sleep -Milliseconds 200

# 6. SET HIGH DPI SCALING (Now using the exact, correct path)
Write-Host "Applying High DPI compatibility settings..." -ForegroundColor Cyan
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
if (-not (Test-Path $registryPath)) { $null = New-Item -Path $registryPath -Force }
New-ItemProperty -Path $registryPath -Name $exePath -Value "~ DPIUNAWARE" -PropertyType String -Force | Out-Null

# 7. CREATE DESKTOP SHORTCUT
Write-Host "Creating Desktop shortcut..." -ForegroundColor Cyan
$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut((Join-Path $desktopPath "Lineage Justice.lnk"))
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = $targetFolder
$shortcut.IconLocation = $exePath
$shortcut.Save()

# 8. FINAL CONFIRMATION
Write-Host "`n[SUCCESS] Installation complete!" -ForegroundColor Green
$type::UpdateWindow($hConsoleWindow)
