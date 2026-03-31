@echo off
setlocal DisableDelayedExpansion

:: 1. Check for Admin rights and elevate if needed
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting Administrator permissions...
    powershell -Command "Start-Process -FilePath '%0' -Verb RunAs"
    exit /b
)

:: 2. Disable QuickEdit Mode (One-liner)
powershell -command "$code='[DllImport(\"kernel32.dll\")] public static extern IntPtr GetStdHandle(int n); [DllImport(\"kernel32.dll\")] public static extern bool GetConsoleMode(IntPtr h, out int m); [DllImport(\"kernel32.dll\")] public static extern bool SetConsoleMode(IntPtr h, int m);'; $t=Add-Type -MemberDefinition $code -Name 'Win32' -Namespace 'Console' -PassThru; $h=$t::GetStdHandle(-10); $m=0; [void]$t::GetConsoleMode($h, [ref]$m); [void]$t::SetConsoleMode($h, ($m -bor 0x0080) -band -bnot 0x0040)"

:: 3. Run PowerShell (Skipping 19 lines)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content '%~f0' | Select-Object -Skip 19 | Out-String | Invoke-Expression"
pause
exit /b

# --- POWERSHELL STARTS HERE ---

# A. DISABLE QUICKEDIT & FORCE UI REFRESH
$code = @"
using System;
using System.Runtime.InteropServices;
public class ConsoleMod {
    const int STD_INPUT_HANDLE = -10;
    const uint ENABLE_QUICK_EDIT_MODE = 0x0040;
    const uint ENABLE_EXTENDED_FLAGS = 0x0080;
    
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
    
    // Preserving the UI refresh functions from the original script
    [DllImport("user32.dll")]
    public static extern bool UpdateWindow(IntPtr hWnd);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    public static void DisableQuickEdit() {
        IntPtr consoleHandle = GetStdHandle(STD_INPUT_HANDLE);
        uint consoleMode;
        GetConsoleMode(consoleHandle, out consoleMode);
        consoleMode |= ENABLE_EXTENDED_FLAGS;
        consoleMode &= ~ENABLE_QUICK_EDIT_MODE;
        SetConsoleMode(consoleHandle, consoleMode);
    }
}
"@
Add-Type -TypeDefinition $code -Language CSharp
[ConsoleMod]::DisableQuickEdit()
$hConsoleWindow = [ConsoleMod]::GetConsoleWindow()

# 1. PATH SETUP
$desktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")
$targetFolder = Join-Path $desktopPath "Lineage Justice"
$exePath = Join-Path $targetFolder "jLauncher.exe"

Clear-Host
Write-Host "--- Lineage Justice Automated Installer ---" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "Initializing setup..." -ForegroundColor Gray

# 2. INITIAL CHECK: Exit if the folder already exists
if (Test-Path -Path $targetFolder) {
    Write-Host "`n[!] 'Lineage Justice' is already on your Desktop." -ForegroundColor Yellow
    Write-Host "Please remove the existing folder if you wish to reinstall."
    exit
}

# 3. DEFENDER EXCLUSION: Whitelist the entire Desktop
Write-Host "Whitelisting Desktop in Windows Defender..." -ForegroundColor Cyan
Add-MpPreference -ExclusionPath $desktopPath

# 4. DOWNLOAD
$url = "https://www.l1justice.com/static/Lineage_Justice.zip"
$destinationZip = Join-Path $env:TEMP "Lineage_Justice.zip"
if (Test-Path $destinationZip) { Remove-Item $destinationZip -Force }

Write-Host "Downloading game files..." -ForegroundColor Cyan
Start-BitsTransfer -Source $url -Destination $destinationZip

# 5. EXTRACTION: Extract directly to Desktop (creates the folder automatically)
Write-Host "Extracting files to Desktop..." -ForegroundColor Cyan
Expand-Archive -Path $destinationZip -DestinationPath $desktopPath -Force
Remove-Item $destinationZip -Force

# B. FORCE UI REFRESH
[Console]::CursorVisible = $true
Write-Host "Refreshing interface layout..." -ForegroundColor Gray
[void][ConsoleMod]::UpdateWindow($hConsoleWindow)
Start-Sleep -Milliseconds 200

# 6. SET HIGH DPI SCALING
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
Write-Host "Finalizing console UI..." -ForegroundColor Gray
[void][ConsoleMod]::UpdateWindow($hConsoleWindow)

# Open the new folder
# explorer.exe $targetFolder