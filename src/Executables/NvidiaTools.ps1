#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Status', 'Install', 'Shortcuts')] [string]$Mode = 'Status',
    [switch]$NoOpen
)

# The Control Panel ships as a Store app (DCH), so a playbook that removes the
# Store also removes the only easy way to get it back. The driver installer from
# nvidia.com always ships the Control Panel, and Microsoft's own Store listing
# can be installed with winget when the Store and its services are healthy.
$ErrorActionPreference = 'SilentlyContinue'
$appUrl = 'https://www.nvidia.com/en-us/software/nvidia-app/'
$driverUrl = 'https://www.nvidia.com/en-us/drivers/'
$panelProductId = '9NF8H0H7WMLT'
$panelStoreUri = 'ms-windows-store://pdp/?ProductId=9nf8h0h7wmlt'
$panelWinget = 'winget install "NVIDIA Control Panel" --id 9NF8H0H7WMLT -s msstore --accept-package-agreements --accept-source-agreements'
$panelExe = 'C:\Program Files\NVIDIA Corporation\Control Panel Client\nvcplui.exe'

function Get-NvidiaGpuName {
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like '*NVIDIA*' } | Select-Object -First 1
    if ($gpu) { $gpu.Name }
}

function Get-NvidiaDriverName {
    $driver = Get-CimInstance Win32_PnPSignedDriver |
        Where-Object { $_.DeviceClass -eq 'DISPLAY' -and $_.DeviceName -like '*NVIDIA*' } |
        Select-Object -First 1
    if (-not $driver) { return }
    if ($driver.DriverVersion) { "NVIDIA $($driver.DriverVersion)" } else { 'NVIDIA driver' }
}

function Get-NvidiaAppName {
    $roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $entry = Get-ItemProperty -Path $roots | Where-Object { $_.DisplayName -like 'NVIDIA App*' } | Select-Object -First 1
    if ($entry) { $entry.DisplayName }
}

function Test-NvidiaControlPanel {
    $appx = Get-AppxPackage -Name '*NVIDIAControlPanel*' | Select-Object -First 1
    if ($appx) { return $true }
    Test-Path -LiteralPath $panelExe
}

function Test-AstraStore {
    [bool](Get-AppxPackage -Name 'Microsoft.WindowsStore')
}

function Get-AstraServiceStart {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) { [string]$svc.StartType } else { 'not installed' }
}

function Get-AstraWingetPath {
    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($cmd) { $cmd.Source }
}

function Get-NvidiaState {
    $update = Get-AstraServiceStart 'wuauserv'
    $bits = Get-AstraServiceStart 'BITS'
    [pscustomobject]@{
        Adapter = Get-NvidiaGpuName
        Driver  = Get-NvidiaDriverName
        App     = Get-NvidiaAppName
        Panel   = [bool](Test-NvidiaControlPanel)
        Store   = [bool](Test-AstraStore)
        Update  = $update
        Bits    = $bits
        Winget  = [bool](Get-AstraWingetPath)
    }
}

function New-AstraUrlShortcut {
    param([string]$Directory, [string]$FileName, [string]$Url)
    $path = Join-Path $Directory $FileName
    $ws = New-Object -ComObject WScript.Shell
    $shortcut = $ws.CreateShortcut($path)
    $shortcut.TargetPath = $Url
    $shortcut.Save()
    $path
}

function Show-NvidiaStatus {
    $state = Get-NvidiaState
    "adapter: $(if ($state.Adapter) { $state.Adapter } else { 'none' })"
    "driver: $(if ($state.Driver) { $state.Driver } else { 'no NVIDIA display driver' })"
    "nvidia app: $(if ($state.App) { "present ($($state.App))" } else { 'not installed' })"
    "control panel: $(if ($state.Panel) { 'present' } else { 'missing' })"
    "microsoft store: $(if ($state.Store) { 'present' } else { 'missing' })"
    "winget: $(if ($state.Winget) { 'present' } else { 'missing' })"
    "wuauserv: $($state.Update)"
    "bits: $($state.Bits)"
}

switch ($Mode) {
    'Status' {
        Show-NvidiaStatus
    }
    'Install' {
        $state = Get-NvidiaState
        if (-not $state.Adapter) {
            'nvidia: no NVIDIA adapter detected; nothing to install'
            break
        }
        "nvidia: adapter $($state.Adapter)"
        if ($state.Panel) {
            'nvidia: the Control Panel is already installed; nothing to do'
            if (-not $state.App) {
                'nvidia: the NVIDIA App is not installed; its installer is at the NVIDIA App page'
                if (-not $NoOpen) { Start-Process -FilePath $appUrl }
            }
            break
        }

        $servicesDown = @($state.Update, $state.Bits) -contains 'Disabled'
        $canUseStore = $state.Store -and $state.Winget -and -not $servicesDown
        $step = 0

        'nvidia: the Control Panel is missing. Exact steps:'
        if ($servicesDown) {
            $step++
            "$step. Windows Update or BITS is Disabled, so the Store cannot install anything. Set post-install row 63 (Services Insane) to OFF, or run 'C:\AstraMax\Debloat.ps1 -Restore' as administrator, then reboot."
        }
        if (-not $state.Store) {
            $step++
            "$step. The Microsoft Store is missing. After the services are back, open PowerShell and run: wsreset -i   (wait about 30 seconds for the Store to reappear)"
        }
        if ($canUseStore) {
            $step++
            "$step. Installing the Control Panel from the Microsoft Store now ..."
            $output = @(& winget install 'NVIDIA Control Panel' --id $panelProductId -s msstore --accept-package-agreements --accept-source-agreements 2>&1)
            $output | ForEach-Object { "   winget: $_" }
            if (Test-NvidiaControlPanel) {
                'nvidia: the Control Panel is installed and registered'
            }
            else {
                "   If that did not finish, run it yourself: $panelWinget"
                "   Or open the Store page: $panelStoreUri"
            }
        }
        elseif ($state.Store -and -not $state.Winget) {
            $step++
            "$step. winget is missing. Install 'App Installer' from the Store, or open the Control Panel page: $panelStoreUri"
        }
        else {
            $step++
            "$step. Store route (after services and Store are back): $panelWinget"
            "   Store page: $panelStoreUri"
        }
        $step++
        "$step. Store-free route: install the newest driver from $driverUrl (pick your card, 'Game Ready Driver', custom install with 'NVIDIA Control Panel' included). The driver package always adds the Control Panel, even with no Store."
        $step++
        "$step. Reboot. The Control Panel then appears in the tray and in right-click on the desktop."
        if (-not $NoOpen) {
            Start-Process -FilePath $driverUrl
            'nvidia: opened the official driver download page'
        }
        'nvidia: no NVIDIA binary is downloaded by the playbook itself.'
    }
    'Shortcuts' {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $made = @()
        foreach ($dir in @($desktop, (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'))) {
            if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { continue }
            $made += New-AstraUrlShortcut -Directory $dir -FileName 'Get NVIDIA App.url' -Url $appUrl
            $made += New-AstraUrlShortcut -Directory $dir -FileName 'NVIDIA Drivers.url' -Url $driverUrl
        }
        foreach ($path in $made) { "nvidia: shortcut $path" }
        if ($made.Count -eq 0) { 'nvidia: no shortcut folder was writable' }
    }
}
