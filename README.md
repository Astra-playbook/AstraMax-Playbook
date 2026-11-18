# Astra Playbook (AME Wizard Beta)

An AME Wizard Beta `.apbx` playbook that combines:

- **Four cumulative tweak presets** — Light, Recommended, Extreme, Insane
- **Four-tier debloat** — Light, Moderate, Extreme or the warned Insane strip of preinstalled apps for every account, logged to `C:\AstraMax\Debloat\removed.json`
- **Four-tier service debloat** — independent Light, Moderate, Extreme (Caution) and warned Insane tiers that set background services to Disabled and delete their cache/report folders; the Insane tier also disables per-user service templates, clears stale per-user keys and merges svchost groups, with startup types snapshotted for exact restore
- **Astra Max** — `Astra-Max-Setup.exe` (v1.6.4) runs silently during the playbook and installs the Astra Max suite the way its own installer does
- **Astra app** — the bundled Astra performance suite (`Astra.exe`, v1.6.4): 228 tweaks across 22 categories, four reversible power presets, a games library, cleaner, benchmark and Restore & safety, deployed with a Desktop and Start Menu shortcut; state and backups live in `%LOCALAPPDATA%\AstraPC`
- **Power and interrupt tuning** — core parking off, MSI interrupts, optional interrupt spreading or core-0 pinning
- **Network stack, DNS and DoH presets** — balanced or low-latency stack, four resolver choices, optional encrypted DNS
- **Game profiles** — reversible GPU preferences for COD HQ/Warzone, Siege, Fortnite, Apex and CS2; existing Siege/Fortnite config keys only, no anti-cheat changes
- **Dedicated CPU/GPU options** — AC boost/EPP policies, HAGS requests and windowed game optimizations; no overclock or promised FPS gain
- **Astra wallpaper** — public abstract themes plus local personal static/live imports; the live option compiles a lightweight native host with masked hair sway and a red/blue glow pulse, with personal artwork excluded from the archive
- **Launch options** — optional Steam launch-option writer for Siege, a Ubisoft Connect `uplay://launch/635/0` desktop shortcut, and generated Epic instructions for Fortnite
- **Game runtime frameworks** — bundled installers for DirectX End-User Runtime June 2010, Visual C++ 2005-2022 All-in-One, .NET Framework 3.5 and .NET Desktop Runtime 8, so a fresh gaming install works offline
- **Quality-of-life tweaks** — classic right-click menu, dark mode, left-aligned taskbar, clock seconds, This PC, long paths, Start recommendations, clipboard history, plus optional background-apps-off, priority boost, sync-provider notifications off, Aero Shake off and a whole-OS animation toggle
- **Gaming shell extras** — notification pop-ups off, instant menus, accessibility shortcut keys off, hidden Ink button and Edge sidebar/shopping/widget policies
- **Privacy and nags** — optional lock screen Spotlight off, post-update setup prompts off and recently added apps list off, plus NVIDIA controls in the Astra app
- **Latency extras** — global timer resolution, network adapter power saving off, optional CPU idle-state and memory-compression off, plus AC-only PCIe ASPM off, disk idle timeout off and the experimental kernel dynamic-tick setting
- **Optional extras** — USB power saving off, OneDrive off, Edge background off, driver updates blocked
- **Defender and VBS choices** — explicit, both default to disabled in this build; the safer choice and the anti-cheat trade-off are called out in the UI
- **Security hardening** — a checked-by-default page turns SmartScreen on, disables LLMNR and disables AutoRun/AutoPlay per user, with previous values snapshotted under `ProgramData\AstraMax\Security`; a separate unchecked page turns SmartScreen and Security Center alerts off
- **Astra capture and display extras** — the app's Game DVR, fullscreen-optimizations, MPO and QoS values reproduced exactly, all off by default and reversible from `Restore.ps1 -QoL`
- **Astra search extras** — local-only Start search, cloud search suggestions off, Recall snapshots off and the Widgets button hidden, off by default
- **StartAllBack** — optional shortcut/staging page for the paid third-party shell add-on; the playbook never installs it silently and the installer is not committed (see the licensing note below)

Target: Windows 11 22H2/23H2/24H2/25H2/26H2 (22621, 22631, 26100, 26200, 26300), ISO injection or clean install. Version 1.5.1.

**Website:** [astra-playbook.github.io/AstraMax-Playbook](https://astra-playbook.github.io/AstraMax-Playbook/)

## Download

- **[Astra-1.5.1.apbx](https://github.com/Astra-playbook/AstraMax-Playbook/raw/main/Astra-1.5.1.apbx)** - 340,648,530 bytes, AME Wizard Beta playbook with Astra Max Setup and the Astra app (7z/AES-256, password `malte`)
- **SHA256:** `FD134EFA29C5A22AFFAF3755B8B2BBD8ED1AE279AC12D8B59D3AEEE25324607B`

The playbook is stored with Git LFS, so use the link above instead of copying the repository pointer file. Verify the hash with `Get-FileHash .\Astra-1.5.1.apbx -Algorithm SHA256` before applying.

## Project layout

```
AstraMax-Playbook/
├─ Astra-1.5.1.apbx                     # built artifact
├─ src/
│  ├─ playbook.conf                     # metadata, pages, options, requirements
│  ├─ playbook.png
│  ├─ Configuration/
│  │  ├─ main.yml
│  │  └─ Tasks/
│  │     ├─ presets/light.yml
│  │     ├─ presets/recommended.yml     # includes light.yml
│  │     ├─ presets/extreme.yml         # includes recommended.yml
│  │     ├─ presets/insane.yml          # includes extreme.yml
│  │     ├─ debloat.yml                 # light / moderate / extreme / insane app removal
│  │     ├─ services.yml                # light / moderate / extreme / insane service tiers
│  │     ├─ extras.yml
│  │     ├─ power.yml                   # core parking
│  │     ├─ interrupts.yml              # MSI / spread / pinned
│  │     ├─ network.yml                 # network preset router
│  │     ├─ network/balanced.yml
│  │     ├─ network/lowlatency.yml      # includes balanced.yml
│  │     ├─ dns.yml                     # resolver selection
│  │     ├─ doh.yml                     # DNS over HTTPS
│  │     ├─ games/setup.yml
│  │     ├─ games/siege.yml
│  │     ├─ games/fortnite.yml
│  │     ├─ games/launch-options.yml
│  │     ├─ wallpaper.yml               # Astra wallpaper theme (blue or red/purple)
│  │     ├─ frameworks.yml
│  │     ├─ harden.yml                  # SmartScreen on, LLMNR off, AutoRun off (snapshotted)
│  │     ├─ security.yml                # optional SmartScreen/alerts off, Defender and VBS choices
│  │     ├─ extra-privacy.yml           # Spotlight, setup prompts, recent apps, cloud clipboard
│  │     ├─ astra-extras.yml            # Game DVR, FSO, MPO, QoS, search, Recall, Widgets
│  │     ├─ astra-app.yml               # deploys the Astra app, helpers and shortcuts
│  │     ├─ startallback.yml            # stages the paid add-on and adds an install shortcut
│  │     ├─ nvidia.yml                  # desktop/Start Menu NVIDIA App and driver shortcuts
│  │     ├─ qol.yml                     # Explorer/taskbar/Start preferences
│  │     └─ tool.yml
│  └─ Executables/
│     ├─ Astra-Max-Setup.exe
│     ├─ AstraTweaks/Astra.exe          # bundled Astra PC app (v1.6.4)
│     ├─ Redist/                        # bundled offline runtimes (DirectX, VC++, .NET 8)
│     ├─ Verify.ps1                     # read-only state report
│     ├─ Restore.ps1                    # undo power, interrupts, DNS/DoH, Steam, capture, tweaks, QoL
│     ├─ Cleanup.ps1                    # cache and temp cleanup
│     ├─ Network.ps1                    # DNS + DoH helper used by tasks
│     ├─ Tweaks.ps1                     # mouse, throttling, plan, startup, MMCSS, latency toggles
│     ├─ QoL.ps1                        # Explorer, taskbar, Start, search and capture extras
│     ├─ StartAllBack.ps1               # stages the optional add-on and adds the install shortcut
│     ├─ Security.ps1                   # SmartScreen, LLMNR and AutoRun hardening with snapshots
│     ├─ Debloat.ps1                    # four-tier app removal, service tiers with snapshots, Insane optional-feature strip, status, exact restore
│     ├─ GameProfiles.ps1               # detect, patch, launch options
│     ├─ Interrupts.ps1                 # MSI + affinity policy
│     ├─ Wallpaper.ps1                  # copies and applies the selected wallpaper
│     ├─ Astra-Wallpaper.png            # bundled 1792x1024 wallpaper (midnight blue)
│     ├─ Astra-Wallpaper-RedPurple.png  # bundled 1792x1024 wallpaper (red/purple)
│     ├─ LaunchOptions.json             # per-game option source
└─ tools/
   ├─ 7zr.exe                           # portable 7-Zip console used for packaging
   ├─ build.ps1
   └─ validate.ps1                      # XML, script, YAML quoting and task-reference checks
```

Option names in `playbook.conf` gate actions in YAML through `option:`. Tier files are cumulative, so Insane applies Extreme, Recommended and Light first. Only one tier radio option can be selected. `tools/validate.ps1` fails the build if an `!task` path points at a missing file.

## Pages

1. Preset tier (radio, 4 tiers)
2. Debloat tier (radio: none, light default, moderate, extreme)
3. Insane app strip (checkbox, unchecked, warned)
4. Service tier (radio: none, light default, moderate, extreme caution)
5. Insane service strip (checkbox, unchecked, warned)
6. Astra Max, Astra app and game frameworks (checkboxes: Astra Max Setup, Astra app, DirectX, Visual C++)
7. .NET runtimes (checkboxes: .NET Framework 3.5, .NET Desktop Runtime 8)
8. NVIDIA tools (checkbox, unchecked: desktop/Start Menu shortcuts to the official NVIDIA App and driver pages, for restoring the Store-shipped Control Panel after debloat; NvidiaTools.ps1 later diagnoses the panel, Store, winget and update services and installs it from the Store when possible)
9. Core parking and interrupts (radio)
10. Network stack (radio)
11. DNS resolver (radio)
12. DNS over HTTPS (checkbox)
13. Wallpaper (radio: personal live import default, personal static import, red/purple, midnight blue)
14. Game profiles (checkboxes: Siege, Fortnite, custom Siege launch options, COD HQ/Warzone)
15. Additional games (checkboxes: Apex, CS2)
16. Fortnite launch instructions and system extras (checkboxes)
17. Driver updates (checkbox)
18. Input and power tweaks (checkboxes: mouse acceleration, power throttling, Ultimate plan, fast startup)
19. Dedicated CPU policies (checkboxes: boost behavior, energy/performance preference; AC only)
20. Dedicated GPU settings (checkboxes: HAGS, windowed optimizations)
21. CPU scheduling tweak (checkbox: MMCSS game task)
22. Quality of life (checkboxes: classic menu, long paths, clock seconds, This PC)
23. Extra privacy and nags (checkboxes, unchecked: lock screen Spotlight off, post-update setup prompts off, recently added apps list off, cloud clipboard sync off)
24. Appearance and taskbar (checkboxes: dark mode, Start recommendations, taskbar left, clipboard history)
25. Latency extras (checkboxes: timer resolution, NIC power saving, CPU idle states, memory compression)
26. Windows extras (checkboxes: startup app delay, search highlights, lock screen tips, recent files)
27. Animations off (checkbox, unchecked: window fades and taskbar animations)
28. Optional toggles (checkboxes, unchecked: background apps, priority boost, sync notifications, Aero Shake)
29. Gaming latency extras (checkboxes, unchecked: PCIe ASPM off, disk idle timeout off, dynamic tick)
30. Gaming shell extras (checkboxes, unchecked: notification pop-ups, menu delay, accessibility shortcut keys)
31. Gaming shell tidy-up (checkboxes, unchecked: Ink button, Edge gaming policies, Game Bar startup tips)
32. Taskbar End task (checkbox; Windows 11 23H2+)
33. Security hardening (checkboxes, checked: SmartScreen on, LLMNR off, AutoRun off)
34. Disable security (checkboxes, unchecked: SmartScreen off, Security Center alerts off)
35. Defender (radio, disabled by default)
36. VBS (radio, disabled by default)
37. Capture and display extras (checkboxes, unchecked: Game DVR off, fullscreen optimizations off, MPO off, QoS reserved bandwidth released)
38. Search extras (checkboxes, unchecked: local-only Start search, cloud search off, Recall off, Widgets button hidden)
39. StartAllBack (checkbox, unchecked: stages the setup when bundled and adds an install shortcut; paid add-on, never installed silently)

Every radio page sets `IsRequired="true"` and `DefaultOption`, which AME requires for ISO
injection. Current AME builds also enforce layout limits: a page with a `TopLine` or
`BottomLine` may hold at most 3 options, a `CheckboxPage` at most 4, and a `RadioPage`
at most 4. Page limits are only enforced when AME loads the playbook, so keep new options
inside those limits.

Two YAML traps, both of which abort the run a couple of seconds after the playbook loads:

- Do not put a Windows path inside a double-quoted scalar. `command: "& '.\Interrupts.ps1'"`
  fails with *while scanning a quoted scalar, found unknown escape character*, because
  YAML treats `\I` as an escape. Use a block scalar instead.
- A PowerShell here-string terminator (`'@` / `"@`) must sit at column 0, which also ends
  the YAML block scalar early and breaks the rest of the file. Build the text from an array
  and join it instead.

`tools/validate.ps1` now fails on both patterns in addition to checking XML, parsing every
helper and verifying task references.

### Run context

`runas` picks the token a task runs under. Machine-wide work (presets, power, interrupts,
network, DNS, security) runs as `system`. Anything that touches the signed-in user — the
wallpaper, desktop shortcuts, game configs and Steam launch options, plus the bundled
installer — uses `currentUserElevated`, because as `system`/`TrustedInstaller` the `HKCU`
hive and the Desktop folder belong to the service account, not the user. The default is
`TrustedInstaller`, so `runas` is always stated explicitly on those actions. Registry
actions are different: `!registryValue` writes to every loaded user hive, so `HKCU\...`
paths apply to all accounts.

The debloat task also runs as `currentUserElevated`, not `system`: it removes the signed-in user's
packages and needs an admin token for `Remove-AppxPackage -AllUsers` and
`Remove-AppxProvisionedPackage -Online`. That covers other accounts without touching the service
account's empty `HKCU`.

## Presets

| Tier | What it changes |
| --- | --- |
| **Light** | Game Mode on, Game DVR/capture off, fullscreen optimizations off, mouse acceleration off, transparency off, taskbar widgets/chat/search box hidden, ads and suggestions off, Bing/Cortana web search off, sticky/toggle key hotkeys off, file extensions shown, High Performance plan. No services touched. |
| **Recommended** | Adds telemetry policy + `DiagTrack`/`dmwappushservice`/`SysMain` off, feedback/ads ID off, Delivery Optimization peer mode off, telemetry scheduled tasks off, hibernation off, Ultimate Performance plan, `Win32PrioritySeparation=26`, HAGS on, FTH off, NTFS last-access/8dot3 off, Copilot/Recall/consumer features off, activity history off, AutoPlay/autorun off, QoS reservation cleared, Defender sample submission off, MMCSS Games task tuned. |
| **Extreme** | Adds `WSearch`, `Spooler`, Xbox services, `WerSvc`, `NDU`, Fax, RemoteRegistry, WMP sharing and Maps off; power throttling off, core parking off, USB selective suspend off; prefetcher off; `LargeSystemCache` + `DisablePagingExecutive`; Nagle off per interface; WPAD/multicast DNS noise off; NetBIOS name resolution off. |
| **Insane** | Adds `DoSvc` and `WpnService` off, Store auto-download off, WU auto-reboot suppressed, WER policy off, Teredo and SMB1 disabled, location off, diagnostic log/dump collection limited. |

Tier notes:

- `Spooler` off breaks printing until re-enabled.
- Memory tweaks target 16 GB+ systems.
- Prefetcher off can hurt HDD-based systems; intended for SSD/NVMe.
- Insane stops toast notifications and Store auto-updates; expect breakage.
- Spectre/Meltdown mitigations are **not** touched — the usual “performance” win there is a security regression.
- Windows Update is not paused; Insane only prevents auto-reboot while a user is signed in.

## Debloat (apps, page 2)

Page 2 is a required radio with four choices; **Light** is the default. Tiers are cumulative, and
the same lists live in `Debloat.ps1` so a re-run after setup matches what the wizard did. Apps only:
services are a separate page. The **Insane** strip is a separate required checkbox page with its own
warning; it applies the cumulative Insane list when ticked.

| Tier | Apps removed |
| --- | --- |
| **None** | Nothing |
| **Light** | Clipchamp, Bing News, Bing Weather, Bing Search, Tips (`Microsoft.Getstarted`), Solitaire Collection, People |
| **Moderate** | Light plus Cortana, Office hub, Mixed Reality Portal, 3D Viewer (`Microsoft.3DViewer` and `Microsoft.Microsoft3DViewer`), Paint 3D, Print 3D, Family safety, Alarms, Maps, Media Player/Zune music and video, Phone Link (`YourPhone`, `CrossDevice`), Teams (both package names), Power Automate, Sound Recorder, Mail and Calendar, To Do, Skype, Feedback Hub |
| **Extreme** | Moderate plus Microsoft Store and its purchase app, Xbox app (`GamingApp`) and console app, Game Bar overlay, Photos (`Windows.Photos`), Camera (`WindowsCamera`), Outlook for Windows, Dev Home, Copilot (all package variants), the OneDrive installer (`/uninstall`) plus its install data and app settings (never the user's OneDrive folder) |
| **Insane (irreversible)** | Extreme plus the remaining non-gaming Microsoft apps: Calculator, Notepad, Snipping Tool, Paint, Sticky Notes, Get Help, OneNote, Wallet, Journal, Whiteboard, OneConnect, Raw Image Extension, Quick Assist, the Xbox speech overlay, Widgets and the web experience |

Insane also removes 19 non-gaming Windows optional features: Work Folders, Fax, the XPS/LPD/LPR/Internet printing extras, Simple TCP, Telnet, TFTP, SNMP, the NFS client/administration set, Remote Differential Compression, AD LDS, the Remote Desktop client, SMB1 and Windows Media Player. Their state is snapshotted to `feature-state.json` and `Debloat.ps1 -Restore` re-enables whichever were enabled. Edge, WebView2, media codecs, DirectX runtimes and Xbox identity/Game Services are deliberately kept because games and launchers need them.

Insane is **not reversible** for apps. Ticking it on its own page means a nearly empty Start menu with no
calculator, text editor, screenshot tool or image editor until you reinstall them. The Store is
already gone at Extreme; `winget` and its source stay protected so you can reinstall, and the exact
removed package names are logged. Skip it on any machine you cannot rebuild.

Every removal runs three ways: `Remove-AppxPackage` for the signed-in user, `-AllUsers` for other
accounts, and `Remove-AppxProvisionedPackage -Online` so new accounts do not get the app back.
After the package is gone, the engine also deletes that package's data folders
(`%LOCALAPPDATA%\Packages\<family>`, every other profile's `AppData\Local\Packages\<family>` when
elevated, and `C:\ProgramData\Packages\<family>`) and its per-user AppModel registry keys
(`Repository\Packages\<full package name>` and `SystemAppData\<family>`). It only deletes a data
folder when no copy of that package remains for that scope; a folder held open by a running app is
reported instead of forced. This is what removes the app's saved settings, caches and account
blobs rather than leaving an orphaned data directory behind.

Extreme also runs `OneDriveSetup.exe /uninstall` and then removes OneDrive's install data
(`%LOCALAPPDATA%\Microsoft\OneDrive`, `C:\ProgramData\Microsoft\OneDrive`, and any `Program Files`
copy) plus the `HKCU`/`HKLM` OneDrive app settings. The user's synced files in
`%USERPROFILE%\OneDrive` are deliberately never touched.

Kept on purpose, in every tier: `DesktopAppInstaller` (winget), `Winget.Source`, VCLibs/UI.Xaml/WindowsAppRuntime,
Shell and Start experience hosts, Windows Search *package*, Security UI, `GamingServices`,
`XboxIdentityProvider`, `Xbox.TCUI` and Windows Terminal.
That keeps Game Pass, Ubisoft/Steam titles that call Xbox identity, and `winget` working.

Each removal is appended to `C:\AstraMax\Debloat\removed.json` (time, tier, package, whether it was
user, all-users, provisioned, a data folder or a registry key) and a readable summary lands in
`debloat-report.txt` next to it. `Debloat.ps1 -Level Status` prints how many package-data folders
are still left for the tuned apps.

Honest limits:

- Provisioned removal is device-wide and not a toggle. Apps come back from the Store or `winget`;
  the Store itself comes back with `wsreset -i` in an elevated terminal.
- Insane app removal is irreversible by design; only the removal log remains and reinstall is manual.
- Deleted package data and per-user AppModel registry keys are not restored by `Debloat.ps1 -Restore`; reinstall the app to recreate them.
- OneDrive cleanup removes app data and settings, not synced files; reinstalling OneDrive recreates its settings but not any file you deleted yourself.
- Removing the Store means no new Store apps until you run `wsreset -i`; `winget` still works.
- The NVIDIA Control Panel is a Store app, so a removed Store also removes its installer. NVIDIA
  packages are protected from debloat; after install, `NvidiaTools.ps1` checks the adapter, driver,
  NVIDIA App, Control Panel, Store, winget, `wuauserv` and `BITS`, names exactly what is missing, and
  installs the panel with `winget install "NVIDIA Control Panel" --id 9NF8H0H7WMLT -s msstore` when
  the Store and its services are healthy. If the Insane service tier disabled `wuauserv`/`BITS`, run
  `Debloat.ps1 -Restore` and reboot first; if the Store is gone, `wsreset -i` restores
  it. A driver from nvidia.com always reinstalls the Control Panel without the Store.
- No anti-cheat component is touched (BattlEye, EAC, Vanguard are outside these packages).
- The engine was validated read-only on a machine that is already debloated; a stock image has not
  been run through it in this repo, so try the tier in a VM first.

Re-run or inspect later (the script is deployed to `C:\AstraMax` when the Astra app is installed):

```powershell
powershell -ExecutionPolicy Bypass -File C:\AstraMax\Debloat.ps1 -Level Status
powershell -ExecutionPolicy Bypass -File C:\AstraMax\Debloat.ps1 -Level Moderate
powershell -ExecutionPolicy Bypass -File C:\AstraMax\Debloat.ps1 -Level Insane
powershell -ExecutionPolicy Bypass -File C:\AstraMax\Debloat.ps1 -Restore
```

`-Restore` restores each service's exact saved startup type from the snapshot, re-enables the optional
features recorded in `feature-state.json`, and prints the reinstall steps from the removal log; it does
not reinstall packages by itself.

## Service tiers (page 3)

Page 3 is a required radio with four choices; **Light** is the default. Tiers are cumulative and
independent of the preset: the preset keeps its own service choices, and this page only ever sets
startup type to Disabled, so a lower tier never re-enables anything the preset turned off. The
**Insane** service strip is a separate required checkbox page and is restorable from the snapshot.

| Tier | Services set to Disabled |
| --- | --- |
| **None** | Nothing |
| **Light** | `MapsBroker`, `Fax`, `WMPNetworkSvc`, `RetailDemo`, `PhoneSvc`, `RemoteRegistry`, `RemoteAccess`, `dmwappushservice` |
| **Moderate** | Light plus `DiagTrack`, `SysMain`, `WerSvc`, `wisvc`, `lfsvc` |
| **Extreme (Caution)** | Moderate plus `WSearch`, `Spooler`, `DoSvc`, `WpnService`, `WinRM`, `SharedAccess` |
| **Insane (advanced)** | Extreme plus Windows Update (`wuauserv`), `BITS`, diagnostic services (`DPS`, `WdiServiceHost`, `WdiSystemHost`, `PcaSvc`, `Wecsvc`, `pla`), touch keyboard (`TabletInputService`), biometrics (`WbioSrvc`), camera (`FrameServer`), wallet and parental controls, smart cards (`SCardSvr`, `ScDeviceEnum`, `CertPropSvc`), NetBIOS helper (`lmhosts`), RDP host (`TermService`, `UmRdpService`, `SessionEnv`) and Xbox/Game Pass (`XblAuthManager`, `XblGameSave`, `XboxGipSvc`, `XboxNetApiSvc`) |

Light is the "nothing a game uses" set: maps, fax, media sharing, telephony, remote registry,
routing and remote access, WAP push. Moderate adds telemetry, Superfetch, error reporting, Windows
Insider and geolocation. Extreme is labelled **Caution** in the wizard because it stops things you
will notice:

- `WSearch` off means Start menu and Explorer search fall back to a slower path and Outlook search
  stops using the index.
- `Spooler` off means no printing until you re-enable it.
- `WpnService` off means no toast notifications; `DoSvc` off stops Store and Windows Update
  delivery-optimization downloads.
- `WinRM` and `SharedAccess` off stop remote PowerShell and Internet Connection Sharing/hotspot.

Insane is deliberately more brutal and is warned on its own page:

- **Windows Update stops** with `wuauserv` and `BITS` disabled; security updates wait until restore.
- **Remote Desktop host stops** (`TermService`, `UmRdpService`, `SessionEnv`).
- **Xbox/Game Pass services stop**; titles that depend on Xbox identity or save sync may fail while
  the services are disabled. `GamingServices` and the Xbox identity *packages* are still protected.
- **Windows Hello fingerprint, camera, smart cards, notifications and diagnostics stop working**.
- **Network discovery and VPN dialing stop** (`SSDPSRV`, `RasMan`, `SstpSvc`); UPnP discovery and
  SSTP/PPTP VPN clients may fail.
- **Update orchestration and the remaining UWP brokers stop** (`UsoSvc`, `NcbService`,
  `TimeBrokerSvc`, `InventorySvc`, `GraphicsPerfSvc`, `WSAIFabricSvc`), along with time sync,
  Security Center, hardware error reporting, storage settings, proxy discovery, IP Helper,
  file sharing, scanner and secondary-logon services (`w32time`, `wscsvc`, `whesvc`, `StorSvc`,
  `WinHttpAutoProxySvc`, `iphlpsvc`, `LanmanServer`, `stisvc`, `seclogon`). The Windows Security
  UI stops reporting and LAN file sharing stops until restore.
- **Per-user services stop for every account.** `CDPUserSvc`, `OneSyncSvc`, `UserDataSvc`,
  `UnistoreSvc`, `PimIndexMaintenanceSvc`, `WpnUserService`, `BcastDVRUserService`,
  `PrintWorkflowUserSvc`, `PenService` and `NPSMSvc` are templates: Windows starts one instance
  (`<Name>_<LUID>`) per signed-in account. Their template `Start` is set to 4 and running instances
  are stopped; sign out and back in to clear the current session's instances.
- **Service hosts merge after reboot.** `SvcHostSplitThresholdInKB` is set to `0xFFFFFFFF` so Windows
  packs more services into fewer `svchost.exe` processes. Windows reads this at boot, so nothing
  changes until restart.
- **Disabled services leave no data behind.** After a service is set to Disabled, its cache and
  report folders are deleted from a fixed table: Windows Update/BITS download cache
  (`SoftwareDistribution\Download`), BITS job store (`ProgramData\Microsoft\Network\Downloader`),
  WER queues and archives (machine and per-user), the search index (`ProgramData\Microsoft\Search\Data`),
  offline maps (`ProgramData\Microsoft\MapData`), telemetry staging (`ProgramData\Microsoft\Diagnosis`),
  WDI reports, the print queue (`spool\PRINTERS`) and the notification database. Deletion only runs
  once the service reports `Disabled`, is skipped while the folder is locked, and every removal is
  logged with kind `service-data`. At Insane, per-user instance keys (`<Template>_<LUID>`) that the
  service controller no longer knows are deleted too (kind `user-service-stale`); live instance keys
  stay until that account signs out. The service registration itself and the startup snapshots are
  never touched, so `-Restore` still works — but deleted caches are gone, and Windows only rebuilds
  them if the service runs again.
- Critical services are excluded even if an Insane list changes: RPC, DCOM, Group Policy, audio,
  networking (DHCP/DNS/NLA/SMB), power, Event Log, WMI, Defender, Installer, AppX deployment,
  Task Scheduler, UxSms/Themes and the Bluetooth/WLAN stacks. `Debloat.ps1` skips them and says so.

Before the first change, `Debloat.ps1` writes three snapshots: `service-state.json` (real `Start`
value, delayed-auto flag and whether each service was running), `user-service-state.json` (each
per-user template's original `Start`) and `kernel-state.json` (the previous
`SvcHostSplitThresholdInKB` value, or that it was absent). `-Restore` replays all three exactly and
starts services that were running before. Everything else is still logged to
`C:\AstraMax\Debloat\removed.json` with kind `service-off`/`service-on`:

```powershell
powershell -ExecutionPolicy Bypass -File C:\AstraMax\Debloat.ps1 -Level Moderate -Services
powershell -ExecutionPolicy Bypass -File C:\AstraMax\Debloat.ps1 -Level Insane -Services
powershell -ExecutionPolicy Bypass -File C:\AstraMax\Debloat.ps1 -Restore
```

`-Level Status` reports both sets (apps present per tier and services disabled per tier) plus the
per-user template count, whether service-host grouping is on, `service data leftovers` (cache folders
still present for disabled services) and how many stale per-user service keys remain.

An idle count of 50-60 processes is a target, not a guarantee. Each `svchost.exe` is one process
regardless of how many services it hosts, per-user services add a host per signed-in account, and
Defender, Edge, Steam, Ubisoft Connect or any installed launcher adds processes the playbook does
not control. Measure the result with `(Get-Process).Count` in Task Manager or PowerShell.

## Core parking and interrupts

Page 6 defaults to **Balanced**. It is independent of the tier, so Light can still unpark cores.

| Option | What it does |
| --- | --- |
| Leave Windows defaults | No power or device changes |
| **Balanced** | `CPMINCORES=100` on AC and DC, `CPMAXCORES=100`, plan re-applied; `MSISupported=1` only for GPU/NIC devices whose drivers already expose interrupt-management keys |
| **Aggressive** | Balanced plus `DevicePolicy=5` (spread interrupts across all processors) for GPU/NICs |
| **Pinned** | Balanced plus `DevicePolicy=4` with an all-cores-except-0 mask (`0xFE...`) for GPU/NICs |

Details that matter:

- **Reboot required** for interrupt changes.
- MSI is never forced on a device without the driver key; forcing it can hang boot on unsupported hardware.
- Pinned uses a 64-bit group-0 mask. On systems with more than 64 logical CPUs, only group 0 is covered.
- Affinity policy is applied to display and network class devices in `OK` state. Virtual adapters simply ignore keys they do not support.
- Laptops: core parking off on battery increases power draw and heat. The DC value is set too; choose defaults if that matters.

## Input and power tweaks

Pages 14, 15 and 18 expose the individual tweaks. The first six mirror values the presets also
set, so they can be applied or skipped on their own:

| Option | Value |
| --- | --- |
| Mouse acceleration off | `HKCU\Control Panel\Mouse` `MouseSpeed=0`, `MouseThreshold1/2=0`, then `SystemParametersInfo(SPI_SETMOUSE)` so it applies without a sign-out |
| Power throttling off | `HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling` `PowerThrottlingOff=1` |
| Ultimate Performance | `powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61`, duplicated first if the scheme is missing; off switches to Balanced |
| Fast startup off | `HiberbootEnabled=0` under `Session Manager\Power`, so every boot is a full shutdown |
| MMCSS game task | `SystemResponsiveness=10`, Games task `Priority=6`, `GPU Priority=8`, `Scheduling Category=High`, `SFIO Priority=High` |
| Global timer resolution | `GlobalTimerResolutionRequests=1` under `Session Manager\kernel`, so games can request 0.5 ms timers on Windows 11 |
| NIC power saving off | `Set-NetAdapterPowerManagement -AllowComputerToTurnOffDevice Disabled` on every present adapter, so Windows stops suspending the NIC to save power |
| CPU idle states off | `powercfg` `SUB_PROCESSOR` `IDLEDISABLE=1` on AC only; lower latency at the cost of idle power and heat |
| Memory compression off | `Disable-MMAgent -MemoryCompression`; intended for 16 GB+ systems that would rather spend CPU time elsewhere |

The first five live in `Tweaks.ps1` (`-Mouse On/Off`, and so on), and `Restore.ps1 -Tweaks` reverses
them: mouse back to `1/6/10`, throttling `0`, Balanced plan, `HiberbootEnabled=1`, and
`SystemResponsiveness=20` with `Priority=2` / `Medium` / `Normal`. Restoring the plan returns to
Balanced, not to whichever plan was active before the tweak. The four latency extras use the same
script (`-TimerResolution`, `-NicPower`, `-CpuIdle`, `-MemoryCompression`): off restores the
Windows default, re-enables idle states on AC and DC, re-enables compression, and lets Windows
power down adapters again.

`Verify.ps1` reports each of them, so `last-report.json` shows whether they are on.

### Gaming latency extras

Three AC-only options on their own wizard page, implemented in
`HardwareTweaks.ps1`:

| Option | Value |
| --- | --- |
| PCIe link power saving off | `powercfg /setacvalueindex` `SUB_PCIEXPRESS` `ASPM` (setting `ee12f906-d277-404b-b6da-e5fa1a576df5`) = `0`; the previous index is saved per active scheme |
| Disk idle timeout off | `powercfg /setacvalueindex` `SUB_DISK` `DISKIDLE` (setting `6738e2c4-e8a5-4a42-b16a-e040e769756e`) = `0` seconds |
| Kernel dynamic tick off | `bcdedit /set {current} disabledynamictick yes`; restore writes the saved value or deletes it when it was absent |

Each option saves its original to `%LOCALAPPDATA%\AstraMax\Backups` and OFF restores that exact value.
Dynamic tick needs elevation and a reboot, and is labelled experimental because it can change timer
behavior on some platforms; benchmark frame-time consistency before keeping it. PCIe ASPM and disk
idle are laptop-unfriendly on battery, which is why only the AC index changes.

## Quality of life

Page 16 and 17 cover Explorer, taskbar and Start preferences. All are per-user values, applied as
the signed-in user, and none touch games:

| Option | Value |
| --- | --- |
| Classic right-click menu | Creates `HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32` with an empty default value; restart Explorer or sign out to see it |
| Long path support | `HKLM\SYSTEM\CurrentControlSet\Control\FileSystem` `LongPathsEnabled=1` |
| Clock seconds | `ShowSecondsInSystemClock=1` under `Explorer\Advanced` |
| Open This PC | `LaunchTo=1` (Home is `2`) |
| Dark mode | `AppsUseLightTheme=0` and `SystemUsesLightTheme=0` under `Themes\Personalize` |
| Hide Start recommendations | `Start_IrisRecommendations=0` under `Explorer\Advanced` |
| Clipboard history | `HKCU\Software\Microsoft\Clipboard` `EnableClipboardHistory=1`, Win+V |
| Left-aligned taskbar | `TaskbarAl=0` (centered is `1`) |

They live in `QoL.ps1` (one `-Name On/Off` switch each) and `Restore.ps1 -QoL` calls
`QoL.ps1 -AllOff`, which removes the classic-menu CLSID key and restores every other value to the
Windows default. Restart Explorer after restoring the menu.

## Windows extras (page 19)

Four opt-in shell tweaks, also available in the Astra app:

| Option | Value |
| --- | --- |
| Startup app delay removed | `HKCU\...\Explorer\Serialize` `StartupDelayInMSec=0`; Off removes the value and Windows keeps its ~10 s delay |
| Search highlights off | `HKCU\...\SearchSettings` `IsDynamicSearchBoxEnabled=0` |
| Lock screen tips and suggestions off | `ContentDeliveryManager` `SubscribedContent-338387Enabled`, `-338388Enabled`, `-310093Enabled` = 0 |
| Recent and frequent files hidden | `Explorer` `ShowRecent=0`, `ShowFrequent=0` |

All four are per-user and reversed by `Tweaks.ps1 -AllOff` or by toggling the matching module.
`Verify.ps1` adds a `Windows extras` line that lists whichever are active.

## Optional toggles

Four more toggles, off by default, also available in the Astra app:

| Option | Value |
| --- | --- |
| Background apps off | `HKCU\...\BackgroundAccessApplications` `GlobalUserDisabled=1`, `BackgroundAppGlobalToggle=0`; sign out so every app honours it |
| Foreground priority boost | `HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl` `Win32PrioritySeparation=38` (Windows default `2`) |
| Sync provider notifications hidden | `HKCU\...\Explorer\Advanced` `ShowSyncProviderNotifications=0` |
| Aero Shake off | `HKCU\...\Explorer\Advanced` `NoWindowMinimizingShortcuts=1` |

All four are reversed by `QoL.ps1 -AllOff` / `Restore.ps1 -QoL` or the matching module. Background-app
OFF returns `GlobalUserDisabled=0` and removes the toggle value; the other OFF paths delete their
value. Priority separation is a scheduling preference, not an FPS promise.

A fifth, separate toggle on its own wizard page covers OS-wide animations:

| Option | Value |
| --- | --- |
| Animations off (whole OS) | `HKCU\Control Panel\Desktop\WindowMetrics` `MinAnimate=0` (window minimize/maximize fades) and `HKCU\...\Explorer\Advanced` `TaskbarAnimations=0`; OFF writes `1` back to both |

Menus and transparency stay with the visual-effects option. Sign out or restart Explorer to finish;
`QoL.ps1 -AllOff` / `Restore.ps1 -QoL` restores both defaults.

### Gaming shell extras

Five more opt-in shell strips on two wizard pages, also available in the Astra app:

| Option | Value |
| --- | --- |
| Notification pop-ups off | `HKCU\...\PushNotifications` `ToastEnabled=0`; OFF writes `1` |
| Menu show delay removed | `HKCU\Control Panel\Desktop` `MenuShowDelay='0'`; OFF writes `'400'` |
| Accessibility shortcut keys off | Sticky Keys `Flags=506`, Filter Keys `Flags=122`, Toggle Keys `Flags=58`, Narrator `WinEnterLaunchEnabled=0`; OFF writes the Windows defaults `510`, `126`, `62` and `1` |
| Ink Workspace button hidden | `HKCU\...\PenWorkspace` `PenWorkspaceButtonDesiredVisibility=0`; OFF writes `1` |
| Edge gaming policies | `HKCU\Software\Policies\Microsoft\Edge` `HubsSidebarEnabled=0`, `EdgeShoppingAssistantEnabled=0`, `WebWidgetAllowed=0`, `HideFirstRunExperience=1`; OFF deletes only those four values |

All five are per-user, reversed by `QoL.ps1 -AllOff` / `Restore.ps1 -QoL` or the matching module, and
listed under `Gaming shell extras` in `Verify.ps1`. Do not disable the accessibility shortcuts on a
machine where someone relies on Sticky Keys, Filter Keys or Toggle Keys. The Edge policies hide shell
surfaces only; they do not disable the browser engine or WebView2 used by games and launchers.

### Astra extras

Eight toggles on two unchecked pages (37-38), taken from the values the Astra app itself stores in
`%LOCALAPPDATA%\AstraPC\State\system-tweaks.json`. All are applied by `QoL.ps1` and reversed by
`QoL.ps1 -AllOff` / `Restore.ps1 -QoL`.

| Option | Value |
| --- | --- |
| Game DVR background recording off | `HKCU\System\GameConfigStore` `GameDVR_Enabled=0`, `HKCU\...\GameDVR` `AppCaptureEnabled=0`, `HKLM\Software\Policies\Microsoft\Windows\GameDVR` `AllowGameDVR=0`; OFF writes `1`, `1` and deletes the policy |
| Fullscreen optimizations off | `HKCU\System\GameConfigStore` `GameDVR_FSEBehaviorMode=2`, `GameDVR_HonorUserFSEBehaviorMode=1`, `GameDVR_DXGIHonorFSEWindowsCompatible=1`, `GameDVR_EFSEFeatureFlags=0`; OFF writes `0` to all four |
| MPO off | `HKLM\SOFTWARE\Microsoft\Windows\Dwm` `OverlayTestMode=5`; OFF deletes it; sign out to finish |
| QoS reserved bandwidth released | `HKLM\Software\Policies\Microsoft\Windows\Psched` `NonBestEffortLimit=0`; OFF deletes the policy |
| Local-only search | `HKCU\...\Search` `BingSearchEnabled=0`; OFF writes `1` |
| Cloud search off | `HKCU\...\SearchSettings` `IsMSACloudSearchEnabled=0`, `IsAADCloudSearchEnabled=0`; OFF deletes both |
| Recall off | `HKCU\Software\Policies\Microsoft\Windows\WindowsAI` `DisableAIDataAnalysis=1`; OFF deletes it; Copilot+ hardware only |
| Widgets button hidden | `HKCU\...\Explorer\Advanced` `TaskbarDa=0`; OFF writes `1` |

Game DVR off stops background recording; manual Game Bar captures still work. Fullscreen optimizations
off changes overlay and alt-tab behaviour in some games, and MPO off can cost a little desktop
smoothness, so both stay unchecked. The two search options are the ones that make Start search
lighter: they stop Bing and cloud suggestions while leaving the local index alone.

### StartAllBack (optional, paid)

StartAllBack is commercial, per-user licensed software from
[startallback.com](https://www.startallback.com/). It is not bundled in the public repository or the
published release, it is not installed silently, and `Restore.ps1` does not cover it. Page 39 stages
the setup when it is present in the build, writes `C:\AstraMax\Tools\StartAllBack.txt`, and adds an
"Install StartAllBack" shortcut to the desktop and Start menu; without the setup the same shortcut
opens the official page.

To include it in a local build, place your licensed `StartAllBack_setup.exe` in `src/Executables/`
before running `tools/build.ps1`. The file is gitignored and the build prints a redistribution
warning. Do not publish a build that contains it unless your license allows redistribution.
StartAllBack changes the Start menu and taskbar, not the search index; use the search extras above to
lighten Start search itself.

## Network stack presets

Page 7 defaults to **Balanced**.

| Option | What it does |
| --- | --- |
| Leave Windows defaults | No changes |
| **Balanced** | `autotuninglevel=normal`, RSS/RSC on, timestamps off, ECN off, WPAD auto-discovery off, `NetworkThrottlingIndex=0xFFFFFFFF`, DNS cache flushed |
| **Low latency** | Balanced plus Nagle off (`TcpAckFrequency=1`, `TCPNoDelay=1`, `TcpDelAckTicks=0`), NetBIOS/LLMNR off, `NDU` service off |

Autotuning is deliberately **not** disabled — restricting the receive window hurts throughput on anything above a few Mbps and is a common placebo tweak. Low latency is intended for wired connections; some Wi-Fi drivers behave worse with Nagle off.

Extreme and Insane already include several of these values, so selecting both is harmless but redundant.

## DNS and DoH

Page 8 sets the resolver on active adapters that have an IPv4 default gateway:

- DHCP / automatic (default)
- Cloudflare `1.1.1.1`, `1.0.0.1`
- Google `8.8.8.8`, `8.8.4.4`
- Quad9 `9.9.9.9`, `149.112.112.112`

Page 9 optionally enables **DNS over HTTPS** for whichever supported resolver is configured, using `Add-DnsClientDohServerAddress` with `-AllowFallbackToUdp $false`. Notes:

- DoH needs Windows 11; on older builds the cmdlet is missing and the action is skipped.
- If you keep DHCP DNS, DoH only applies when Windows detects a supported resolver from the router. Static provider selection is the reliable path.
- VPN and corporate networks may intercept DNS; leave DoH off there.
- Changing DNS does not change IP configuration or bypass captive portals.

## Game profiles

Siege, Fortnite and COD HQ/Warzone are selected by default; Apex and CS2 are optional. Profiles detect installed executables, save the original GPU preference, and request `GpuPreference=2` while preserving other preference tokens. No anti-cheat executable, AppCompat layer, global capture setting, process priority or game binary is changed.

Existing config keys are edited only in their matching section: Siege `[DISPLAY]` `VSync=0`; Fortnite `[/Script/FortniteGame.FortniteGameUserSettings]` `bUseVSync=False` and `bUseDynamicResolution=False`. Missing keys are not invented. COD/Apex/CS2 receive GPU preferences and graphics guides only; render workers, VRAM budgets, render mode, Reflex and FPS caps stay manual.

Use `GameProfiles.ps1 -Cod -Mode Status`, `-Mode Off` to restore saved values, or `-InstallDirectory "D:\Games\Call of Duty"` for a custom installation. Substitute `-Siege`, `-Fortnite`, `-Apex` or `-CS2`. Close the game before changing/restoring. Missing games are skipped and can be configured after installation. Missing config files during restoration retain their pending backup.

This changes display/GPU preferences and game config values — it does **not** touch game binaries or attempt to bypass Easy Anti-Cheat or BattlEye.

## Launch options

Two optional checkboxes on page 11:

- **Apply Siege launch options (Steam; requires Steam closed)**
- **Write Fortnite launch option instructions (Epic)**

Values come from `C:\AstraMax\LaunchOptions.json`, copied from `src/Executables/LaunchOptions.json`:

```json
{
  "Siege": { "AppId": "359550", "UbisoftGameId": "635", "Options": "" },
  "Fortnite": { "Options": "" }
}
```

How it applies:

- **Siege / Steam:** the helper locates `userdata\<id>\config\localconfig.vdf`, finds the `359550` app block, and inserts or replaces `LaunchOptions`. It does nothing unless the option string is non-empty, refuses to run while Steam is open, only touches the matching app block, and keeps a one-time `localconfig.vdf.astra-backup` before writing. Steam cloud sync can still overwrite the value later; the backup is the recovery path.
- **Siege / Ubisoft Connect:** Ubisoft keeps per-game arguments inside its own store, with no supported local file to patch, so set them in Ubisoft Connect → Games → Siege → Manage → Properties → Launch arguments. The generated `C:\AstraMax\LaunchOptions\Siege.txt` lists the exact steps and the configured value to paste.
- **Siege / Ubisoft shortcut:** `Set-UbisoftLaunchShortcut` writes `Rainbow Six Siege (Astra).url` to `C:\AstraMax\LaunchOptions` and to the Desktop. It opens `uplay://launch/635/0`, which starts Siege directly through Ubisoft Connect without the home screen; arguments configured in Properties still apply.
- **Fortnite / Epic:** Epic stores arguments per account in the launcher UI, not in a writable game or launcher config. The helper writes `C:\AstraMax\LaunchOptions\Fortnite.txt` with the steps: Settings → scroll to Fortnite → enable **Additional Command Line Arguments** → paste.

Both `Options` strings are empty by default. No undocumented launch, renderer or timer-related flags are supplied. Use in-game graphics/latency controls, and add only publisher-documented arguments supported by your installed version. Custom Siege arguments are applied only when non-empty and Steam is closed; the Ubisoft/Epic steps remain manual.

An **Astra - Launch Options** desktop shortcut opens the generated folder. To apply custom Siege flags, edit the JSON, close Steam, then run the Siege profile shortcut or:

```powershell
powershell -ExecutionPolicy Bypass -File C:\AstraMax\GameProfiles.ps1 -Siege -ApplyLaunchOptions
```

## Wallpaper

The wallpaper radio page has four choices. Personal live import is the default; personal files are never bundled. Two abstract themes remain available:

| Option | Image | Look |
| --- | --- | --- |
| `wp-astra-red-purple` | `Astra-Wallpaper-RedPurple.png` | crimson arc burning into magenta and violet dust |
| `wp-astra` | `Astra-Wallpaper.png` | cobalt arc into pale blue and violet |

- `Wallpaper.ps1 -Image <path>` copies the chosen file to
  `C:\Windows\Web\Wallpaper\Astra\astra-wallpaper.png`.
- It sets `HKCU\Control Panel\Desktop` values `Wallpaper`, `WallpaperStyle=10` (fill) and
  `TileWallpaper=0`, then calls `SystemParametersInfo(SPI_SETDESKWALLPAPER)` so the change
  shows immediately.
- It is per-user, like the game-profile settings: it applies to the account the playbook
  runs as (the OOBE user on an injected install). Other accounts keep their wallpaper.
- Personal static import reads `Pictures\Astra\personal-wallpaper.png` (or the personal Astra image).
- Personal live import builds `Pictures\Astra\Astra-Personal-Live` from a local image and `hair-motion.json`, then compiles `AstraLiveWallpaper.exe` from the bundled `AstraLive.cs` with the in-box .NET Framework compiler. No browser runtime, WebView2 or Lively install is used. The image and mask stay outside the public source/archive.
- Hair sway is a masked 24 fps bitmap shear, not an AI-generated video; heavy strands near the roots move most and the crown stays put. The red and blue glow pulse from coordinates and strengths in `hair-motion.json`, and the host pauses itself while a fullscreen app covers the primary screen.
- Personal wallpaper OFF restores the saved static background and fit; live OFF stops only the Astra host (matched by executable path), removes the Astra startup shortcut and leaves other Lively wallpapers untouched. Personal wallpaper rows are excluded from bulk actions.
- Missing personal files are reported and leave the current wallpaper unchanged. Fresh ISO imports need the personal files supplied locally; no copyrighted anime art is shipped.

CPU/GPU rows 47-50 request documented AC boost/EPP policies, HAGS and windowed DX10/DX11 optimizations. Originals are saved; HAGS requires supported hardware/driver and reboot. Configuration status is not proof that HAGS is running. Benchmark frame times and temperature; no overclock or FPS gain is promised.

## Bundled game runtimes

The three installers live in `src/Executables/Redist/` and are shipped inside the `.apbx`, so the
runtime page installs without internet access. Hashing was done on the exact files in this repo:

| File | Size | Authenticode | SHA256 |
| --- | --- | --- | --- |
| `directx_Jun2010_redist.exe` | 95.6 MB | Valid (Microsoft) | `053F76DCBB28802E23341B6A787E3B0791C0FA5C8D4D011B1044172DBF89C73B` |
| `windowsdesktop-runtime-8.0.34-win-x64.exe` | 55.7 MB | Valid (Microsoft) | `37AA8A02ACC1973DDD7E3DE993A02007CCEF26B48FA35B09D087FA8AB4602795` |
| `VisualCppRedist_AIO_x86_x64.exe` | 31.1 MB | **NotSigned** | `1990EBB978D80B7A2ABDD76FA6562F5969E39B775DC4A846CA9398A354D27B6B` |

How they run (`Tasks/frameworks.yml`):

- **DirectX June 2010:** extracts to `%TEMP%\AstraDX` with `/Q /T:<dir>`, then runs `DXSETUP.exe /silent`.
- **Visual C++:** the AIO with `/ai /gm2`, which installs the 2005-2022 x86 and x64 runtimes.
- **.NET Desktop Runtime 8:** `/install /quiet /norestart` (x64 only).
- **.NET Framework 3.5:** still `DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart`,
  because there is no standalone redistributable and it needs the Windows source or Windows Update.

**Redistribution note:** the Visual C++ AIO is the abbodi1406 community repack that wraps official
Microsoft payloads; it is not Microsoft-signed and its redistribution terms should be confirmed before
a public release, the same way the bundled unsigned `Astra.exe` is handled below. The DirectX and .NET 8
files are genuine Microsoft-signed installers.

Dark mode sets both Windows/app light-theme values to zero without recreating the existing registry key, then broadcasts a theme refresh. Row 46 adds taskbar End task on Windows 11 23H2+; terminating an app can lose unsaved work.

## Optional extras

- **USB power saving off** — clears `MSPower_DeviceEnable` for attached devices (helps mice/keyboards that drop out).
- **OneDrive sync off** — policy plus process stop.
- **Edge background off** — Startup Boost and Background Mode policies.
- **Driver updates blocked** — prevents Windows Update from replacing vendor GPU drivers.

## Bundled tool

`src/Executables/Astra-Max-Setup.exe` is the installer you provided. The playbook runs it with the NSIS silent switch:

```yaml
- !run: {exe: 'Astra-Max-Setup.exe', args: '/S', exeDir: true, wait: true, option: install-astra-max}
```

The components checkbox is enabled by default; clear it to skip the tool.

**Verify before distributing:**

- The installer is **not digitally signed** (Authenticode `NotSigned`).
- SHA256 of the bundled file: `96B7511A94655878645F140A6FB7A2A3640C1EF610ED30E6774E14998FC7004D`
- It runs elevated as the signed-in user (`runas: currentUserElevated`), so a per-user
  installer lands in that profile and not the service account. If it is repacked with
  Inno Setup, change the args to `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART`.
- Only redistribute the tool if its license allows it.

## Astra app

The Astra checkbox deploys the bundled **Astra** performance suite, the only control panel the
archive installs. `Tasks/astra-app.yml` copies `Astra.exe` (v1.6.4, 78 MB) to
`C:\AstraMax\AstraTweaks\`, copies the helper scripts (`Verify.ps1`, `Restore.ps1`, `Cleanup.ps1`,
`Network.ps1`, `Tweaks.ps1`, `QoL.ps1`) to `C:\AstraMax\`, and creates **Astra** shortcuts on the
Desktop and in the Start Menu with the working directory set to the app folder.

Captured from the real build (screenshots in `docs/assets`):

- **Dashboard** - health score and 11 checks, live CPU/GPU temperature and load, VRAM, the running
  Windows plan, and a Game Mode session that reverts at the next restart.
- **Tuning** - 228 tweaks across 22 categories (All, with Starter 34, Aggressive 28, Absolute 85 and
  Max 42 collections), hardware playbook chips for AMD/Intel CPU and GPU plus NVIDIA, a search box
  and a live state per row. Each change stores its original value.
- **Power presets** - four reversible plans on the Balanced template (Gaming, Light work, Ultimate,
  Absolute), each stating its processor range and what it cannot do.
- **Games** - a scanned library, a curated optimiser list with full profiles or in-game guides, and
  frame presets from Quality through Viral potato.
- **Cleaner** - curated temp and cache folders, GPU shader caches, then TRIM or defrag on the drive
  you pick.
- **Benchmark and latency lab** - local CPU, memory and disk scores plus DPC, interrupt and timer
  latency measured on this PC.
- **Restore & safety** - reverts a single tweak, a category or everything from the app's own
  backups; nothing is meant to be permanent.

The app is self-contained: settings live in `%LOCALAPPDATA%\AstraPC\settings.json`, applied
tweak backups in `State\*.json`, per-game config backups under `Backups\Games`, and run logs in
`Logs\astra.log`. A fresh Windows install therefore gets a working app without running an
installer, and reverting its tweaks uses the app's own backup data.

| Helper | What it does |
| --- | --- |
| `Verify.ps1` | Read-only report: power plan, core parking, MSI interrupts, affinity policy, DNS, DoH, autotuning, mouse, throttling, plan, fast startup, MMCSS, latency extras, quality of life, capture, services, runtimes |
| `Restore.ps1` | Prints a preview and changes nothing without `-Force`. Power, interrupts, DNS/DoH, Steam, capture, `-Tweaks`, `-QoL`, `-Security` |
| `Cleanup.ps1` | User/system temp, D3D/NVIDIA/AMD shader caches, crash dumps; recycle bin only when asked |
| `Network.ps1` | `-Dns Auto/Cloudflare/Google/Quad9`, `-Doh On/Off/Keep` |
| `Tweaks.ps1` | `-Mouse`, `-PowerThrottling`, `-UltimatePlan`, `-FastStartup`, `-Mmcss`, `-TimerResolution`, `-NicPower`, `-CpuIdle`, `-MemoryCompression`, `-StartupDelay`, `-SearchHighlights`, `-Suggestions`, `-ExplorerRecent`, `-WerUi`, each `On/Off/Keep`; `-AllOff` |
| `QoL.ps1` | `-ClassicMenu`, `-LongPaths`, `-ClockSeconds`, `-OpenThisPC`, `-DarkMode`, `-StartRecommendations`, `-ClipboardHistory`, `-TaskbarLeft`, `-EndTask`, `-Animations`, `-Notifications`, `-MenuDelay`, `-A11yKeys`, `-InkWorkspace`, `-EdgeGaming`, `-Spotlight`, `-Scoobe`, `-StartRecentApps`, `-SecurityNotifications`, `-CloudClipboard`, `-GameBarTips`, `-OnlineSpeech`, `-InkTyping`, `-LanguageList`, `-TailoredExperiences`, `-HiddenFiles`, `-FullPath`, `-TaskbarSmallIcons`, `-HoverDelay`, `-KeyboardRepeat`, `-AudioDucking`, `-RestartApps`, each `On/Off/Keep`; `-AllOff` |
| `Security.ps1` | `-SmartScreen`, `-Llmnr`, `-Autorun`, `-PagingExecutive`, `-Maintenance`, `-ClearPagefile`, `-Wsh`, each `On/Off/Keep`; `-AllOff`. ON snapshots the previous values to `ProgramData\AstraMax\Security`; OFF restores them or removes the values |
| `HardwareTweaks.ps1` | `-Feature CpuBoost/CpuEpp/PciePower/DiskIdle/DynamicTick/GpuScheduling/WindowedGaming -Mode On/Off/Status` |
| `GameProfiles.ps1` | Five games; `-Mode On/Off/Status`, `-Detect`, optional `-InstallDirectory` |
| `PersonalWallpaper.ps1` | Local static/live import; `-Live`, `-PrepareOnly`, `-Mode On/Off/Status`; compiles the native host on demand |

`Verify.ps1 -Json` prints the path of the report it wrote (`C:\AstraMax\last-report.json`), so it
stays usable from other tooling.

**Verify before distributing:**

- `Astra.exe` is **not digitally signed** (Authenticode `NotSigned`).
- SHA256 of the bundled build: `FE1B485143D4434F75B81E952D247EAF99E5ABCC70F06221125196EB0F542A76`
- It is shipped unmodified. Confirm you have the right to redistribute it, and that the copy
  in `src/Executables/AstraTweaks/` is the build you intend to ship.
- The deploy step only copies files and writes shortcuts. The app was launched on Windows 11
  during this release and its Dashboard, Tuning, Games, Power presets and Cleaner pages were
  captured with no tweak applied. It has not been launched from an AME-injected image; test it
  once on a clean VM.

The earlier PowerShell/WPF shell is kept in `legacy/AstraCenter.ps1` for reference. It is no
longer deployed or packaged.

## Build and validate

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate.ps1
powershell -ExecutionPolicy Bypass -File tools/build.ps1
```

`validate.ps1` parses `playbook.conf`, parses every PowerShell helper, and verifies that every `!task` include exists. `build.ps1` checks required files, packages `src/` with `playbook.conf` at the archive root, prints contents and SHA256, and writes `AstraMax.apbx` unless `-Output` is given. The 1.5.1 artifact built from this tree is `Astra-1.5.1.apbx`, SHA256 `FD134EFA29C5A22AFFAF3755B8B2BBD8ED1AE279AC12D8B59D3AEEE25324607B`. The build refuses an archive that still contains the retired `PostInstall` menu.

The repository tracks `Astra-1.5.1.apbx` and the bundled app `src/Executables/AstraTweaks/Astra.exe` through Git LFS (install Git LFS before cloning). Historical builds, `src/Executables/Astra-Max-Setup.exe`, the vendor installers in `src/Executables/Redist/`, `tools/7zr.exe` and the retired `legacy/` dashboard are excluded; supply those locally before running `build.ps1`, which fails its required-files check without them.

The `.apbx` must be a **7z archive, AES-256 encrypted with password `malte`, with the file list encrypted** (`-mhe=on`). That is AME Wizard's convention; a plain zip is rejected at load with *"Playbook must be encrypted using 'malte' as the password."* `build.ps1` does this through the portable `tools/7zr.exe` (download it from https://www.7-zip.org/a/7zr.exe if missing) using the equivalent of:

```powershell
7z a -t7z -p'malte' -mhe=on -mx=9 AstraMax.apbx playbook.conf playbook.png Configuration Executables
```

The script then re-lists the archive with the password, confirms `playbook.conf` is at the root, confirms the header list is *not* readable without the password, and runs an integrity test before printing the hash. If you rebuild with a stock 7-Zip install, use `pwsh tools/build.ps1 -Output <path>` with `7zr.exe` in `tools/`, or run the command above yourself.

## Apply

1. Download AME Wizard Beta and a clean Windows 11 ISO.
2. Drag the ISO into AME Wizard, then drop `Astra-1.5.1.apbx` in.
3. Pick preset, debloat tier, service tier, components, power/interrupts, network, DNS/DoH, game profiles/extras, input/power, quality-of-life and latency extras, Defender and VBS options.
4. Finish, write the image to USB (Rufus or built-in), and install — or apply to the running system if you drop the `FreshInstall` requirement.

If AME still refuses the file at load, check the message. `Playbook must be encrypted using 'malte' as the password` means the archive was repacked (for example re-zipped or re-saved by an editor) and lost its 7z/AES encryption — rebuild it with `tools/build.ps1`. A generic "invalid playbook" with this archive usually means the AME Beta build is older than the playbook schema; the public Atlas/NOVA playbooks are the reference for the currently supported action names.

## Verification status for 1.5.1

1.5.1 adds two Astra extras pages (37-38) with eight toggles whose registry values were read from the Astra app's own backup state in `%LOCALAPPDATA%\AstraPC\State\system-tweaks.json`, plus a StartAllBack staging page (39). It keeps 1.4.1's Astra branding and the 1.4.0 removal of the retired post-install menu. `tools/validate.ps1` passes: `playbook.conf` parses as XML, every option name is unique, page limits hold across all 39 pages, every helper script parses, YAML has no quoted-backslash or here-string hazards and every `!task` include exists. `tools/test-new-options.ps1` passes end to end against temporary registry keys, including both directions of all eight new toggles and static checks that the StartAllBack helper never runs an installer. `tools/build.ps1` re-lists the archive with the password, confirms `playbook.conf` at the root, `Astra-Max-Setup.exe`, `AstraTweaks\Astra.exe` and the new tasks inside, no `PostInstall` entry, no StartAllBack installer in the public build, unreadable headers without the password, and a clean integrity test.

The screenshots on the site were captured from Astra 1.6.4 running on Windows 11 on this PC (Dashboard, Tuning, Games, Power presets, Cleaner) and from the bundled Astra Max Setup before its Install step. No tweak was applied and the setup was cancelled before installing.

Not executed for 1.5.1: applying the archive through AME on a clean image or VM, the wizard's scripted changes from an injected image, the Astra app launched from an AME-deployed folder, the StartAllBack setup (never run, and not included in the public artifact), game benchmarks and any claim about FPS. Earlier fixture results for `QoL.ps1`, `Security.ps1`, `Tweaks.ps1`, `HardwareTweaks.ps1` and `Debloat.ps1` were unchanged by this release. These are release checks, not claimed successes.
## Smoke-test checklist (VM first)

1. Wizard shows 39 pages; preset defaults to Recommended, debloat/services to Light, wallpaper to personal live import, hardening to all three checked and Defender/VBS to disabled.
2. Light run changes registry only; no services change.
3. Recommended disables `DiagTrack`/`SysMain`; Extreme adds `WSearch`/`Spooler`; Insane adds `DoSvc`/`WpnService`.
4. Desktop wallpaper changes to the selected Astra theme and survives a sign-out; the file exists at `C:\Windows\Web\Wallpaper\Astra\astra-wallpaper.png`.
5. Balanced power page sets `CPMINCORES=100` on AC and DC; other plans are untouched.
6. Interrupt page logs GPU/NIC MSI hits; no device fails to boot after restart. Aggressive/Pinned set `DevicePolicy` 5/4 respectively.
7. Network balanced leaves autotuning at `normal`; low latency adds the Nagle/NetBIOS values. `ipconfig /all` still shows a valid lease.
8. DNS provider applies only to adapters with a gateway; DoH appears in `Get-DnsClientDohServerAddress` (Windows 11).
9. Astra Max Setup runs silently and installs after the preset steps.
10. The Astra shortcut opens `C:\AstraMax\AstraTweaks\Astra.exe` (v1.6.4); the dashboard reads the machine, Tuning lists 228 tweaks, a power preset applies and reverts, and Restore & safety is reachable. Log at `%LOCALAPPDATA%\AstraPC\Logs\astra.log`.
11. With the network cable pulled, DirectX, Visual C++ and .NET Desktop 8 install from the bundled `Redist` folder; `.NET 3.5` succeeds or is skipped cleanly when no source is available. `Get-ChildItem 'C:\Program Files\dotnet\shared\Microsoft.WindowsDesktop.App'` shows an 8.0.x folder.
12. Siege/Fortnite shortcuts appear; running one after install reports detected exe and config paths.
13. Game profiles preserve unrelated GPU tokens, skip absent games, refuse changes while the game is running, and restore original config values without touching anti-cheat or global capture.
14. Launch-options checkbox writes `Siege.txt`/`Fortnite.txt`; with Steam closed and a non-empty Siege string, only the `359550` block changes and a `.astra-backup` exists.
15. Defender defaults to disabled; choosing "keep" only throttles scans, "disable" turns off real-time protection (tamper protection may block it).
16. VBS defaults to disabled; that choice clears `hypervisorlaunchtype`, memory integrity and Credential Guard. Confirm on a system that does not need Vanguard/FACEIT.
17. Quality-of-life pages land: classic-menu CLSID key exists (restart Explorer to see the menu), `LongPathsEnabled=1`, `TaskbarAl=0`, `AppsUseLightTheme=0`, and `Verify.ps1` lists them. The optional toggles, animations, gaming shell and extra privacy pages write their documented values only when ticked; `QoL.ps1 -AllOff` or the Astra app's restore returns them.
18. Latency extras: `GlobalTimerResolutionRequests=1`, every adapter reports "Allow the computer to turn off this device" disabled, CPU idle shows disabled on AC only when selected, and `Get-MMAgent` matches the compression choice.
19. Windows extras page: with all four on, `StartupDelayInMSec=0`, `IsDynamicSearchBoxEnabled=0`, the three `SubscribedContent-*Enabled` values are 0 and `ShowRecent`/`ShowFrequent` are 0; `Verify.ps1` lists them under `Windows extras`.
20. Siege launch options: `SIEGE UBI ARGS` writes `C:\AstraMax\LaunchOptions\Siege.txt` and drops `Rainbow Six Siege (Astra).url` on the Desktop that opens `uplay://launch/635/0`.
21. Debloat Light removes Clipchamp/news/weather/Solitaire/People; `C:\AstraMax\Debloat\removed.json` lists each one. Extreme removes the Store and OneDrive; `wsreset -i` brings the Store back. Deleted package data is not restored.
22. Service tier: Light sets `MapsBroker`/`Fax`/`RemoteRegistry` to Disabled; Moderate also stops `DiagTrack`/`SysMain`; Extreme also stops `WSearch`/`Spooler`/`WpnService`; Insane adds the process diet. `Debloat.ps1 -Restore` replays `service-state.json` exactly.
23. Gaming latency extras (unchecked by default): PCIe ASPM off and disk idle off write AC index `0` and leave DC alone; `HardwareTweaks.ps1 -Mode Off` restores the saved indices; dynamic tick needs a reboot.
24. NVIDIA tools page (unchecked by default): ticking it adds the two desktop shortcuts; `NvidiaTools.ps1 -Mode Status` prints the diagnosis; no NVIDIA package is removed by debloat.
25. Security hardening page (all three ticked by default): `SmartScreenEnabled='Warn'`, policy `EnableSmartScreen=1`, `EnableMulticast=0` and `NoDriveTypeAutoRun=255` are written, with one snapshot per item under `ProgramData\AstraMax\Security`. `Security.ps1 -AllOff` or `Restore.ps1 -Security` reverses them.
26. Astra capture/display extras (unchecked): `GameDVR_Enabled=0`, `AppCaptureEnabled=0`, `AllowGameDVR=0`, the four `GameDVR_FSE*` values, `OverlayTestMode=5` and `NonBestEffortLimit=0` are written; `QoL.ps1 -AllOff` restores the Astra defaults (`1`/values deleted).
27. Astra search extras (unchecked): `BingSearchEnabled=0`, both `Is*CloudSearchEnabled=0`, `DisableAIDataAnalysis=1` and `TaskbarDa=0` are written; sign out and confirm Start shows no web results and the Widgets button is gone.
28. StartAllBack page (unchecked): ticking it adds "Install StartAllBack" to the desktop and Start menu and writes `C:\AstraMax\Tools\StartAllBack.txt`; nothing is installed or executed by the playbook.

Machine-wide changes run as `system`. Per-user values (wallpaper, shortcuts, game configs) run as the
signed-in user through `currentUserElevated`, and `!registryValue` `HKCU` writes land in every loaded
user hive, so they cover accounts other than the one that ran the wizard. If the wizard's action names
differ in your AME build, compare against the public Atlas/NOVA playbooks before shipping.
## Rollback

Run `Restore.ps1` for everything the playbook changed (or use `Astra.exe` for its own
backups). From a prompt:

- **Core parking:** `powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 0` (and `setdcvalueindex`), then `powercfg /setactive SCHEME_CURRENT`.
- **Interrupts:** Device Manager → device → Details → remove the `Affinity Policy` keys, or set `DevicePolicy=0`; reboot. Restoring `MSISupported=0` is only needed if a device misbehaves.
- **DNS:** adapter settings → Obtain DNS server address automatically.
- **DoH:** `Remove-DnsClientDohServerAddress -ServerAddress <ip> -Confirm:$false`.
- **Quality of life:** delete `HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}` for the classic menu; set `TaskbarAl=1`, `ShowSecondsInSystemClock=0`, `LaunchTo=2`, `AppsUseLightTheme=1`, `Start_IrisRecommendations=1`, `LongPathsEnabled=0` and `EnableClipboardHistory=0` for the rest; set `GlobalUserDisabled=0`, delete `BackgroundAppGlobalToggle` and `ShowSyncProviderNotifications`, set `Win32PrioritySeparation=2`, and delete `NoWindowMinimizingShortcuts` for the optional toggles. `Restore.ps1 -QoL` does all of it.
- **Latency extras:** set `GlobalTimerResolutionRequests=0`, re-enable adapter power saving in Device Manager, run `powercfg` `IDLEDISABLE=0` on AC/DC, and `Enable-MMAgent -MemoryCompression`. The gaming extras use `HardwareTweaks.ps1 -Feature PciePower|DiskIdle|DynamicTick -Mode Off` (each restores its saved index or BCD value); reboot after restoring dynamic tick.
- **Gaming shell extras:** set `ToastEnabled=1`, `MenuShowDelay='400'`, the accessibility `Flags` back to `510`/`126`/`58` with `WinEnterLaunchEnabled=1`, `PenWorkspaceButtonDesiredVisibility=1`, and delete `HubsSidebarEnabled`, `EdgeShoppingAssistantEnabled`, `WebWidgetAllowed` and `HideFirstRunExperience`. `QoL.ps1 -AllOff` covers all five.
- **Astra extras:** set `GameDVR_Enabled=1`, `AppCaptureEnabled=1`, zero the four `GameDVR_FSE*` values, delete `AllowGameDVR`, `OverlayTestMode`, `NonBestEffortLimit`, `IsMSACloudSearchEnabled`, `IsAADCloudSearchEnabled` and `DisableAIDataAnalysis`, set `BingSearchEnabled=1` and `TaskbarDa=1`. `Restore.ps1 -QoL` does all of it.
- **StartAllBack:** the playbook never installed it. If you installed it from the shortcut, uninstall it from Settings → Apps, then sign out.
- **Windows extras:** delete `StartupDelayInMSec`; set `IsDynamicSearchBoxEnabled=1`; set `SubscribedContent-338387Enabled`, `-338388Enabled`, `-310093Enabled`, `ShowRecent` and `ShowFrequent` to `1`. `Tweaks.ps1 -AllOff` covers all four.
- **Debloat:** `Debloat.ps1 -Restore` restores each service's exact snapshot startup type and prints the reinstall list; `wsreset -i` brings the Store back (Extreme). Apps are reinstalled from the Store, `winget`, or the exact package names in `C:\AstraMax\Debloat\removed.json` — for another account, install once and it becomes available to everyone. Removed provisioned copies are not restored automatically; a clean image is the only full reset.
- **Services:** `Debloat.ps1 -Restore` replays `service-state.json`: Automatic, delayed Automatic, Manual and Disabled are restored exactly, and services that were running are started again. It also restores the 10 per-user templates from `user-service-state.json` (sign out/in to start them) and the previous `SvcHostSplitThresholdInKB` value from `kernel-state.json` (reboot to apply), then re-enables any optional feature recorded in `feature-state.json`. Service cache/report folders and stale per-user keys deleted by the service tier are not restored; Windows rebuilds the caches and recreates instance keys only when the service runs again. A single service can also be set back in `services.msc`.
- **Steam launch options:** clear the field in Steam properties, or restore `localconfig.vdf.astra-backup` with Steam closed.
- **Anything after install:** open **Astra** and use Restore & safety to revert a tweak, a category or everything, or run `Restore.ps1`. For Defender alone, `Security.ps1` and the wizard page are the documented paths.
- **Game Bar capture:** Settings → Gaming → Captures → turn background recording back on.
- **Everything else:** this is an AME playbook; re-image is the supported reset path.

## Customizing

- **Swap the tool:** replace `src/Executables/Astra-Max-Setup.exe`, keep the name, or update `Tasks/tool.yml` and the required-files list in `tools/build.ps1`.
- **Change the bundled app:** drop a new `src/Executables/AstraTweaks/Astra.exe`, update the version/signature notes in this README, and rebuild. The deploy task copies whatever is in that folder.
- **Move tweaks between tiers:** edit `presets/*.yml`; keep the cumulative `!task` includes intact.
- **Add a quality-of-life toggle:** add a `CheckboxOption` to a QoL page, a switch to `QoL.ps1`, and a gated `!powerShell` block in `Tasks/qol.yml`; extend `-AllOff` so Restore still works.
- **Add a game profile:** copy `games/siege.yml`, add a `CheckboxOption` in `playbook.conf`, extend `GameProfiles.ps1` with a finder and config patcher.
- **Change a debloat tier:** edit the `$tiers` table in `Debloat.ps1`. Names are matched with `-like`, so a plain name is exact and a trailing `*` covers variants (`Microsoft.Bing*`). Keep anything Astra depends on out of the list; `$protected` refuses the Store stack, App Installer, winget source, VCLibs/UI.Xaml, Start menu, search host and gaming services even if you add them. The separate `debloat-insane` checkbox calls `-Level Insane`, and its warning text lives in that page's `Description`/`TopLine`. The optional-feature strip is the `$insaneFeatures` list; each removed feature is snapshotted to `feature-state.json` and re-enabled by `-Restore`.
- **Change a service tier:** edit `$svcTiers` in `Debloat.ps1` (service names, cumulative like the app tiers). `$protectedServices` refuses RPC, DCOM, audio, networking, power, Event Log, WMI, Defender, Installer, AppX deployment, Task Scheduler and theme services even if a list changes. Per-user services are separate: add template names to `$userServiceTemplates`, not `$svcTiers`, because their instances are named `<Name>_<LUID>` and only the template `Start` value is writable. Service-host grouping is the `SvcHostSplitThresholdInKB` write in `Set-SvcHostGrouping`. The Caution label is text in the `svc-extreme` option and the Insane warning in `svc-insane`; keep both in `playbook.conf` if you add services there.
- **Change launch options:** edit `LaunchOptions.json`; leave `Options` empty to disable a game's flags without unticking the page option.
- **Add a framework:** drop the installer in `src/Executables/Redist/`, add it to the required-files list in `tools/build.ps1`, add a `CheckboxOption`, then a gated `!powerShell` + `Start-Process` pair in `Tasks/frameworks.yml`. Keep the silent switches documented and record the file hash here.
- **Fork identity:** change `<Name>`, `<Title>`, `<UniqueId>` (new GUID), `<Username>`, and bump `<Version>`.

## Credits

Task schema and action patterns follow public AME Wizard playbooks (AtlasOS, NOVA). Registry/service values are standard community tweaks, not vendor recommendations.
