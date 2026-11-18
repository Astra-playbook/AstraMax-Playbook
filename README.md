# Astra Playbook (AME Wizard Beta)

An AME Wizard Beta `.apbx` playbook that combines:

- **Four cumulative tweak presets** â€” Light, Recommended, Extreme, Insane
- **Four-tier debloat** â€” Light, Moderate, Extreme or the warned Insane strip of preinstalled apps for every account, logged to `C:\AstraMax\Debloat\removed.json`
- **Four-tier service debloat** â€” independent Light, Moderate, Extreme (Caution) and warned Insane tiers that set background services to Disabled and delete their cache/report folders; the Insane tier also disables per-user service templates, clears stale per-user keys and merges svchost groups, with startup types snapshotted for exact restore
- **The bundled Astra tool** â€” `Astra-Max-Setup.exe` runs silently during the playbook
- **Astra Tweaks app** â€” the bundled Astra PC app (`Astra.exe`, v1.6.4) deployed with a Desktop and Start Menu shortcut; it keeps its own backups, tweak state and logs in `%LOCALAPPDATA%\AstraPC`
- **Power and interrupt tuning** â€” core parking off, MSI interrupts, optional interrupt spreading or core-0 pinning
- **Network stack, DNS and DoH presets** â€” balanced or low-latency stack, four resolver choices, optional encrypted DNS
- **Game profiles** — reversible GPU preferences for COD HQ/Warzone, Siege, Fortnite, Apex and CS2; existing Siege/Fortnite config keys only, no anti-cheat changes
- **Dedicated CPU/GPU options** — AC boost/EPP policies, HAGS requests and windowed game optimizations; no overclock or promised FPS gain
- **Astra wallpaper** — public abstract themes plus local personal static/live imports; the live option compiles a lightweight native host with masked hair sway and a red/blue glow pulse, with personal artwork excluded from the archive
- **Launch options** â€” optional Steam launch-option writer for Siege, a Ubisoft Connect `uplay://launch/635/0` desktop shortcut, and generated Epic instructions for Fortnite
- **Game runtime frameworks** â€” bundled installers for DirectX End-User Runtime June 2010, Visual C++ 2005-2022 All-in-One, .NET Framework 3.5 and .NET Desktop Runtime 8, so a fresh gaming install works offline
- **Astra Post Install** â€” one self-elevating exe that opens a themed control center with category sidebar, search and 100 tweaks with live state and ON/OFF per row, including the four debloat tiers and the NVIDIA app/Control Panel diagnostic that names the exact install steps
- **Quality-of-life tweaks** â€” classic right-click menu, dark mode, left-aligned taskbar, clock seconds, This PC, long paths, Start recommendations, clipboard history, plus optional background-apps-off, priority boost, sync-provider notifications off, Aero Shake off and a whole-OS animation toggle
- **Gaming shell extras** â€” notification pop-ups off, instant menus, accessibility shortcut keys off, hidden Ink button and Edge sidebar/shopping/widget policies
- **Privacy and nags** â€” optional lock screen Spotlight off, post-update setup prompts off and recently added apps list off, plus an NVIDIA telemetry service toggle in the post-install menu
- **Latency extras** â€” global timer resolution, network adapter power saving off, optional CPU idle-state and memory-compression off, plus AC-only PCIe ASPM off, disk idle timeout off and the experimental kernel dynamic-tick setting
- **Optional extras** â€” USB power saving off, OneDrive off, Edge background off, driver updates blocked
- **Defender and VBS choices** â€” explicit, both default to disabled in this build; the safer choice and the anti-cheat trade-off are called out in the UI
- **Security hardening** â€” a checked-by-default page turns SmartScreen on, disables LLMNR and disables AutoRun/AutoPlay per user, with previous values snapshotted under `ProgramData\AstraMax\Security`; a separate unchecked page turns SmartScreen and Security Center alerts off

Target: Windows 11 22H2/23H2/24H2/25H2/26H2 (22621, 22631, 26100, 26200, 26300), ISO injection or clean install. Version 1.3.6.

## Project layout

```
AstraMax-Playbook/
â”œâ”€ Astra-1.3.6.apbx                     # built artifact
â”œâ”€ src/
â”‚  â”œâ”€ playbook.conf                     # metadata, pages, options, requirements
â”‚  â”œâ”€ playbook.png
â”‚  â”œâ”€ Configuration/
â”‚  â”‚  â”œâ”€ main.yml
â”‚  â”‚  â””â”€ Tasks/
â”‚  â”‚     â”œâ”€ presets/light.yml
â”‚  â”‚     â”œâ”€ presets/recommended.yml     # includes light.yml
â”‚  â”‚     â”œâ”€ presets/extreme.yml         # includes recommended.yml
â”‚  â”‚     â”œâ”€ presets/insane.yml          # includes extreme.yml
â”‚  â”‚     â”œâ”€ debloat.yml                 # light / moderate / extreme / insane app removal
â”‚  â”‚     â”œâ”€ services.yml                # light / moderate / extreme / insane service tiers
â”‚  â”‚     â”œâ”€ extras.yml
â”‚  â”‚     â”œâ”€ power.yml                   # core parking
â”‚  â”‚     â”œâ”€ interrupts.yml              # MSI / spread / pinned
â”‚  â”‚     â”œâ”€ network.yml                 # network preset router
â”‚  â”‚     â”œâ”€ network/balanced.yml
â”‚  â”‚     â”œâ”€ network/lowlatency.yml      # includes balanced.yml
â”‚  â”‚     â”œâ”€ dns.yml                     # resolver selection
â”‚  â”‚     â”œâ”€ doh.yml                     # DNS over HTTPS
â”‚  â”‚     â”œâ”€ games/setup.yml
â”‚  â”‚     â”œâ”€ games/siege.yml
â”‚  â”‚     â”œâ”€ games/fortnite.yml
â”‚  â”‚     â”œâ”€ games/launch-options.yml
â”‚  â”‚     â”œâ”€ wallpaper.yml               # Astra wallpaper theme (blue or red/purple)
â”‚  â”‚     â”œâ”€ frameworks.yml
â”‚  â”‚     â”œâ”€ harden.yml                  # SmartScreen on, LLMNR off, AutoRun off (snapshotted)
â”‚  â”‚     â”œâ”€ security.yml                # optional SmartScreen/alerts off, Defender and VBS choices
â”‚  â”‚     â”œâ”€ extra-privacy.yml           # Spotlight, setup prompts, recent apps, cloud clipboard
â”‚  â”‚     â”œâ”€ astra-app.yml               # deploys Astra Tweaks, helpers and shortcuts
â”‚  â”‚     â”œâ”€ postinstall.yml             # deploys the Astra Post Install app
â”‚  â”‚     â”œâ”€ nvidia.yml                  # desktop/Start Menu NVIDIA App and driver shortcuts
â”‚  â”‚     â”œâ”€ qol.yml                     # Explorer/taskbar/Start preferences
â”‚  â”‚     â””â”€ tool.yml
â”‚  â””â”€ Executables/
â”‚     â”œâ”€ Astra-Max-Setup.exe
â”‚     â”œâ”€ AstraTweaks/Astra.exe          # bundled Astra PC app (v1.6.4)
â”‚     â”œâ”€ Executables/Redist/            # bundled offline runtimes (DirectX, VC++, .NET 8)
â”‚     â”œâ”€ Verify.ps1                     # read-only state report
â”‚     â”œâ”€ Restore.ps1                    # undo power, interrupts, DNS/DoH, Steam, capture, tweaks, QoL
â”‚     â”œâ”€ Cleanup.ps1                    # cache and temp cleanup
â”‚     â”œâ”€ Network.ps1                    # DNS + DoH helper used by tasks
â”‚     â”œâ”€ Tweaks.ps1                     # mouse, throttling, plan, startup, MMCSS, latency toggles
â”‚     â”œâ”€ QoL.ps1                        # Explorer, taskbar, clock, Start, clipboard and nag toggles
â”‚     â”œâ”€ Security.ps1                   # SmartScreen, LLMNR and AutoRun hardening with snapshots
â”‚     â”œâ”€ Debloat.ps1                    # four-tier app removal, service tiers with snapshots, Insane optional-feature strip, status, exact restore
â”‚     â”œâ”€ GameProfiles.ps1               # detect, patch, launch options
â”‚     â”œâ”€ Interrupts.ps1                 # MSI + affinity policy
â”‚     â”œâ”€ Wallpaper.ps1                  # copies and applies the selected wallpaper
â”‚     â”œâ”€ Astra-Wallpaper.png            # bundled 1792x1024 wallpaper (midnight blue)
â”‚     â”œâ”€ Astra-Wallpaper-RedPurple.png  # bundled 1792x1024 wallpaper (red/purple)
â”‚     â”œâ”€ PostInstall/
â”‚     â”‚  â”œâ”€ Astra-PostInstall.cmd       # console fallback (same toggles)
â”‚     â”‚  â”œâ”€ AstraMaxPostInstall.exe     # single-click launcher, self-elevating, no console
â”‚     â”‚  â”œâ”€ PostInstallGui.ps1          # themed control-center window
â”‚     â”‚  â”œâ”€ Catalog.ps1                 # single list of all 100 tweaks (number, group, note)
â”‚     â”‚  â”œâ”€ PostInstall.ps1             # console menu (numbers, A all on, D all off)
â”‚     â”‚  â””â”€ Modules/                    # one script per tweak + _Common.ps1
â”‚     â”‚     â”œâ”€ _Common.ps1
â”‚     â”‚     â”œâ”€ 01-PowerPlan.ps1 ... 100-Wsh.ps1
â”‚     â”œâ”€ LaunchOptions.json             # per-game option source
â””â”€ tools/
   â”œâ”€ 7zr.exe                           # portable 7-Zip console used for packaging
   â”œâ”€ build.ps1
   â””â”€ validate.ps1                      # XML, script, YAML quoting and task-reference checks
```

Option names in `playbook.conf` gate actions in YAML through `option:`. Tier files are cumulative, so Insane applies Extreme, Recommended and Light first. Only one tier radio option can be selected. `tools/validate.ps1` fails the build if an `!task` path points at a missing file.

## Pages

1. Preset tier (radio, 4 tiers)
2. Debloat tier (radio: none, light default, moderate, extreme)
3. Insane app strip (checkbox, unchecked, warned)
4. Service tier (radio: none, light default, moderate, extreme caution)
5. Insane service strip (checkbox, unchecked, warned)
6. Tool, Astra Tweaks and game frameworks (checkboxes: Astra tool, Astra Tweaks app, DirectX, Visual C++)
7. .NET runtimes (checkboxes: .NET Framework 3.5, .NET Desktop Runtime 8)
8. NVIDIA tools (checkbox, unchecked: desktop/Start Menu shortcuts to the official NVIDIA App and driver pages, for restoring the Store-shipped Control Panel after debloat; post-install row 73 diagnoses the panel, Store, winget and update services and installs it from the Store when possible)
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
35. Post-install toolkit (checkbox: deploy the Astra Post Install app)
36. Defender (radio, disabled by default)
37. VBS (radio, disabled by default)

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
network, DNS, security) runs as `system`. Anything that touches the signed-in user â€” the
wallpaper, desktop shortcuts, game configs and Steam launch options, plus the bundled
installer â€” uses `currentUserElevated`, because as `system`/`TrustedInstaller` the `HKCU`
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
- Spectre/Meltdown mitigations are **not** touched â€” the usual â€œperformanceâ€ win there is a security regression.
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
  packages are protected from debloat; after install, post-install row 73 checks the adapter, driver,
  NVIDIA App, Control Panel, Store, winget, `wuauserv` and `BITS`, names exactly what is missing, and
  installs the panel with `winget install "NVIDIA Control Panel" --id 9NF8H0H7WMLT -s msstore` when
  the Store and its services are healthy. If the Insane service tier disabled `wuauserv`/`BITS`, run
  row 63 OFF or `Debloat.ps1 -Restore` and reboot first; if the Store is gone, `wsreset -i` restores
  it. A driver from nvidia.com always reinstalls the Control Panel without the Store.
- No anti-cheat component is touched (BattlEye, EAC, Vanguard are outside these packages).
- The engine was validated read-only on a machine that is already debloated; a stock image has not
  been run through it in this repo, so try the tier in a VM first.

Re-run or inspect later (the script is deployed to `C:\AstraMax` when Astra Tweaks is installed):

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

Three AC-only options on their own wizard page, mirrored as post-install rows 65-67 and implemented in
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

Four opt-in shell tweaks, also mirrored as post-install items 22â€“25:

| Option | Value |
| --- | --- |
| Startup app delay removed | `HKCU\...\Explorer\Serialize` `StartupDelayInMSec=0`; Off removes the value and Windows keeps its ~10 s delay |
| Search highlights off | `HKCU\...\SearchSettings` `IsDynamicSearchBoxEnabled=0` |
| Lock screen tips and suggestions off | `ContentDeliveryManager` `SubscribedContent-338387Enabled`, `-338388Enabled`, `-310093Enabled` = 0 |
| Recent and frequent files hidden | `Explorer` `ShowRecent=0`, `ShowFrequent=0` |

All four are per-user and reversed by `Tweaks.ps1 -AllOff` or by toggling the matching module.
`Verify.ps1` adds a `Windows extras` line that lists whichever are active.

## Optional toggles

Four more toggles, off by default, mirrored as post-install rows 58-61:

| Option | Value |
| --- | --- |
| Background apps off | `HKCU\...\BackgroundAccessApplications` `GlobalUserDisabled=1`, `BackgroundAppGlobalToggle=0`; sign out so every app honours it |
| Foreground priority boost | `HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl` `Win32PrioritySeparation=38` (Windows default `2`) |
| Sync provider notifications hidden | `HKCU\...\Explorer\Advanced` `ShowSyncProviderNotifications=0` |
| Aero Shake off | `HKCU\...\Explorer\Advanced` `NoWindowMinimizingShortcuts=1` |

All four are reversed by `QoL.ps1 -AllOff` / `Restore.ps1 -QoL` or the matching module. Background-app
OFF returns `GlobalUserDisabled=0` and removes the toggle value; the other OFF paths delete their
value. Priority separation is a scheduling preference, not an FPS promise.

A fifth, separate toggle on its own wizard page and post-install row 64 covers OS-wide animations:

| Option | Value |
| --- | --- |
| Animations off (whole OS) | `HKCU\Control Panel\Desktop\WindowMetrics` `MinAnimate=0` (window minimize/maximize fades) and `HKCU\...\Explorer\Advanced` `TaskbarAnimations=0`; OFF writes `1` back to both |

Menus and transparency stay with the visual-effects option. Sign out or restart Explorer to finish;
`QoL.ps1 -AllOff` / `Restore.ps1 -QoL` restores both defaults.

### Gaming shell extras

Five more opt-in shell strips on two wizard pages, mirrored as post-install rows 68-72:

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

## Network stack presets

Page 7 defaults to **Balanced**.

| Option | What it does |
| --- | --- |
| Leave Windows defaults | No changes |
| **Balanced** | `autotuninglevel=normal`, RSS/RSC on, timestamps off, ECN off, WPAD auto-discovery off, `NetworkThrottlingIndex=0xFFFFFFFF`, DNS cache flushed |
| **Low latency** | Balanced plus Nagle off (`TcpAckFrequency=1`, `TCPNoDelay=1`, `TcpDelAckTicks=0`), NetBIOS/LLMNR off, `NDU` service off |

Autotuning is deliberately **not** disabled â€” restricting the receive window hurts throughput on anything above a few Mbps and is a common placebo tweak. Low latency is intended for wired connections; some Wi-Fi drivers behave worse with Nagle off.

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

This changes display/GPU preferences and game config values â€” it does **not** touch game binaries or attempt to bypass Easy Anti-Cheat or BattlEye.

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
- **Siege / Ubisoft Connect:** Ubisoft keeps per-game arguments inside its own store, with no supported local file to patch, so set them in Ubisoft Connect â†’ Games â†’ Siege â†’ Manage â†’ Properties â†’ Launch arguments. The generated `C:\AstraMax\LaunchOptions\Siege.txt` lists the exact steps and the configured value to paste.
- **Siege / Ubisoft shortcut:** `Set-UbisoftLaunchShortcut` writes `Rainbow Six Siege (Astra).url` to `C:\AstraMax\LaunchOptions` and to the Desktop. It opens `uplay://launch/635/0`, which starts Siege directly through Ubisoft Connect without the home screen; arguments configured in Properties still apply.
- **Fortnite / Epic:** Epic stores arguments per account in the launcher UI, not in a writable game or launcher config. The helper writes `C:\AstraMax\LaunchOptions\Fortnite.txt` with the steps: Settings â†’ scroll to Fortnite â†’ enable **Additional Command Line Arguments** â†’ paste.

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

## Post-install control center

The post-install toolkit page deploys one clickable file, **AstraMaxPostInstall.exe**, to `C:\AstraMax\PostInstall\`
with **Astra Post Install** shortcuts on the Desktop and in the Start Menu. Double-clicking it
needs no console and no manual "run as admin": the exe is compiled with a `requireAdministrator`
manifest and starts the GUI PowerShell hidden, so the window that appears is already elevated.

The window follows the Atlas/ReviOS toolbox layout:

- dark Astra header with the machine name and an **ELEVATED** / **READ ONLY** badge, plus a matching dark title bar;
- a category sidebar (All, Performance, CPU, GPU, Gaming, Network, Privacy, Shell, System, Input, Appearance, Security, Debloat) with a live tweak count per group and an accent marker on the active one;
- a search box that filters on name, group and note text (`Ctrl+F` focuses it, `Esc` closes the window);
- one row per tweak: number, name, group and a one-line note preview, a live `ON` / `OFF` / `MIXED` pill and **ON** / **OFF** buttons; risky notes are tinted;
- a right rail with **WHAT THIS DOES**, **LIVE STATE** (the module's own status text) and **ACTIVITY**, which logs every toggle with the module output;
- **ALL ON** / **ALL OFF** apply to the current category and search after confirmation, excluding the personal static/live wallpaper rows; OFF restores saved values only where supported;
- sidebar utilities: **OPEN INSTALL FOLDER**, **RUN VERIFY REPORT** (streams `C:\AstraMax\Verify.ps1`) and **SIEGE UBI LAUNCH ARGS** (profile plus the launch-option instructions and shortcut);
- risky rows (services, Defender real-time, spooler, debloat extreme, debloat Insane, services Insane) ask for confirmation before switching **on**; the two Insane rows are excluded from bulk actions;
- item **21** switches the wallpaper (ON red and purple, OFF midnight blue) from the deployed `Assets` folder, so the app never needs the playbook files again.

`Astra-PostInstall.cmd` and `PostInstall.ps1` stay as the console fallback with the same catalog:
numbers, `A`, `D`, `R`, `Q`, and `-Status` / `-All On|Off` / `-IncludeRisky`. `Catalog.ps1` is the
single source of truth for numbering, labels, groups, risk and notes, so the GUI and the console
never disagree, and `Modules\NN-*.ps1` still keeps one file per tweak (usually 30â€“50 lines on top
of `_Common.ps1`).

| # | Module | What it toggles |
| --- | --- | --- |
| 1 | `01-PowerPlan` | Ultimate vs Balanced plan |
| 2 | `02-CoreParking` | `CPMINCORES` / `CPMAXCORES` 100 vs 0 |
| 3 | `03-CpuIdle` | processor idle disable |
| 4 | `04-PowerThrottling` | `PowerThrottlingOff` |
| 5 | `05-FastStartup` | `HiberbootEnabled` |
| 6 | `06-Hibernation` | `powercfg /h on\|off` |
| 7 | `07-MemoryCompression` | `Enable/Disable-MMAgent` |
| 8 | `08-TimerResolution` | `GlobalTimerResolutionRequests` |
| 9 | `09-GameMode` | Game Mode, DVR, capture, FSE |
| 10 | `10-Mmcss` | MMCSS Games task |
| 11 | `11-NetworkLatency` | Nagle, NetBIOS, WPAD, multicast DNS |
| 12 | `12-Services` | DiagTrack, SysMain, WSearch, Xbox, NDU, WER (risky) |
| 13 | `13-Telemetry` | telemetry policy, ads ID, CEIP tasks |
| 14 | `14-Privacy` | web search, Cortana, activity history, location |
| 15 | `15-VisualEffects` | transparency, menu delay |
| 16 | `16-Explorer` | classic menu, This PC, clock seconds, extensions, clipboard, long paths |
| 17 | `17-Taskbar` | widgets, chat, task view, search box, alignment |
| 18 | `18-DriverUpdates` | Windows Update driver block |
| 19 | `19-OneDrive` | sync policy + process |
| 20 | `20-Defender` | real-time protection (risky) |
| 21 | `21-Wallpaper` | red/purple vs midnight blue theme (ON = red) |
| 22 | `22-StartupDelay` | `StartupDelayInMSec` 0 vs Windows default |
| 23 | `23-SearchHighlights` | `IsDynamicSearchBoxEnabled` |
| 24 | `24-Suggestions` | lock screen tips and Windows suggestion toasts |
| 25 | `25-ExplorerRecent` | `ShowRecent` / `ShowFrequent` |
| 26 | `26-MouseAcceleration` | `MouseSpeed` / thresholds (raw 1:1 input) |
| 27 | `27-EdgeBackground` | Edge startup boost, background mode, preloading policies |
| 28 | `28-UpdateAutoRestart` | `NoAutoRebootWithLoggedOnUsers` |
| 29 | `29-DeliveryOptimization` | peer upload/download policy |
| 30 | `30-UsbSelectiveSuspend` | USB selective suspend on AC/DC |
| 31 | `31-Copilot` | Copilot policy + taskbar button |
| 32 | `32-Recall` | Windows AI data analysis policy |
| 33 | `33-AutoPlay` | AutoPlay prompts |
| 34 | `34-RemoteAssistance` | Remote Assistance invitations |
| 35 | `35-QosReserved` | `NonBestEffortLimit` 20 vs 0 |
| 36 | `36-Prefetch` | Prefetcher / Superfetch |
| 37 | `37-NetworkThrottling` | `NetworkThrottlingIndex` |
| 38 | `38-ConsumerFeatures` | consumer content and suggested apps policy |
| 39 | `39-LockScreen` | `NoLockScreen` |
| 40 | `40-Spooler` | Print Spooler service (risky) |
| 41 | `41-StoreAutoUpdate` | `AutoDownload` for Store apps |
| 42 | `42-DebloatLight` | Light app tier (Clipchamp, Bing, Solitaire, People) |
| 43 | `43-DebloatModerate` | Moderate app tier (Mail, Teams, Maps, media) |
| 44 | `44-DebloatExtreme` | Extreme app tier (Store, Photos, Xbox, Copilot, OneDrive) plus data/AppModel cleanup (risky) |
| 45 | `45-DarkMode` | Windows and apps dark mode |
| 46 | `46-EndTask` | Taskbar End task (23H2+; unsaved work warning) |
| 47 | `47-CpuBoost` | AC boost policy; restores saved active-scheme index (risky) |
| 48 | `48-CpuEpp` | AC energy/performance preference; exact saved-index restore (risky) |
| 49 | `49-GpuScheduling` | HAGS request; supported hardware/driver and reboot required (risky) |
| 50 | `50-WindowedGaming` | Windowed DX10/DX11 optimizations; preserves other tokens |
| 51 | `51-SiegeProfile` | Siege GPU preference and existing VSync key |
| 52 | `52-FortniteProfile` | Fortnite GPU preference and existing VSync/dynamic-resolution keys |
| 53 | `53-CodProfile` | COD HQ/Warzone GPU preference and manual graphics guide |
| 54 | `54-ApexProfile` | Apex GPU preference and manual graphics guide |
| 55 | `55-CS2Profile` | CS2 GPU preference and manual graphics guide |
| 56 | `56-LiveWallpaper` | Private native live host (hair sway, glow pulse); excluded from bulk (risky) |
| 57 | `57-PersonalWallpaper` | Private static import; excluded from bulk |
| 58 | `58-BackgroundApps` | `GlobalUserDisabled=1`, `BackgroundAppGlobalToggle=0`; OFF restores the default |
| 59 | `59-PriorityBoost` | `Win32PrioritySeparation` 38 vs 2 |
| 60 | `60-SyncProviderAds` | `ShowSyncProviderNotifications=0`; OFF deletes the value |
| 61 | `61-AeroShake` | `NoWindowMinimizingShortcuts=1`; OFF deletes the value |
| 62 | `62-DebloatInsane` | Insane app strip (Calculator, Notepad, Snipping Tool, Paint, Sticky Notes, Get Help, OneNote, Wallet, Journal, Whiteboard, OneConnect, Raw Image Extension, Quick Assist, Widgets, web experience) plus 19 non-gaming optional features and deletion of each removed app's data folders and per-user AppModel keys; apps are irreversible, deleted data is permanent, excluded from bulk (risky) |
| 63 | `63-ServicesInsane` | Insane process diet (Update/BITS, RDP, Xbox, biometrics, camera, smart cards, diagnostics, UPnP, VPN, update orchestration, 10 per-user templates, service-host grouping) that also deletes disabled services' cache/report folders and stale per-user keys; OFF restores all three snapshots and re-enables optional features but not deleted caches, excluded from bulk (risky) |
| 64 | `64-Animations` | `MinAnimate=0` and `TaskbarAnimations=0` for the signed-in user; OFF restores both defaults. Sign out or restart Explorer |
| 65 | `65-PciePower` | AC PCIe ASPM index 0; OFF restores the saved active-scheme index |
| 66 | `66-DiskIdle` | AC disk idle timeout 0; OFF restores the saved index |
| 67 | `67-DynamicTick` | `bcdedit` `disabledynamictick yes`; OFF restores the saved value or deletes it; reboot required (risky) |
| 68 | `68-Notifications` | `ToastEnabled=0`; OFF writes `1` |
| 69 | `69-MenuDelay` | `MenuShowDelay='0'`; OFF writes `'400'` |
| 70 | `70-A11yKeys` | Sticky/Filter/Toggle Keys and Narrator shortcuts off; OFF writes the Windows defaults |
| 71 | `71-InkWorkspace` | `PenWorkspaceButtonDesiredVisibility=0`; OFF writes `1` |
| 72 | `72-EdgeGaming` | Edge sidebar, shopping, widgets and first-run off; OFF deletes only those four policy values |
| 73 | `73-NvidiaTools` | Diagnoses adapter, NVIDIA driver, NVIDIA App, Control Panel, Store, winget, wuauserv and BITS. ON prints a numbered fix plan and installs the Control Panel with `winget ... -s msstore --id 9NF8H0H7WMLT` when the Store and its services are healthy; otherwise it prints the exact `Debloat.ps1 -Restore`, `wsreset -i`, winget and nvidia.com/drivers steps and opens the driver page. No NVIDIA binary is bundled. OFF has nothing to undo |
| 74 | `74-NvidiaTelemetry` | Disables and stops `NvTelemetryContainer` when present; startup type is saved to `ProgramData\AstraMax\NvidiaTelemetry.json`; OFF restores it and starts the service if it was running |
| 75 | `75-Spotlight` | `RotatingLockScreenEnabled=0` and `RotatingLockScreenOverlayEnabled=0`; OFF deletes both values |
| 76 | `76-Scoobe` | `ScoobeSystemSettingEnabled=0`; OFF deletes the value |
| 77 | `77-StartRecent` | `Start_TrackProgs=0`; OFF deletes the value. Sign out to finish |
| 78 | `78-SmartScreen` | `SmartScreenEnabled='Warn'` plus policy `EnableSmartScreen=1`; ON snapshots the previous values under `ProgramData\AstraMax\Security`. OFF restores the snapshot, or writes `Off`/`0` when there is none |
| 79 | `79-Llmnr` | Policy `EnableMulticast=0` (LLMNR off); OFF restores the snapshotted value or deletes it |
| 80 | `80-Autorun` | Per-user `NoDriveTypeAutoRun=255`; OFF restores the snapshot or deletes the value |
| 81 | `81-SecurityNotifications` | `Windows.SystemToast.SecurityAndMaintenance` `Enabled=0`; OFF writes `1` |
| 82 | `82-CloudClipboard` | `CloudClipboardAutomaticUpload=0`; OFF deletes the value |
| 83 | `83-GameBarTips` | `ShowStartupPanel=0`; OFF writes `1` |
| 84 | `84-OnlineSpeech` | `OnlineSpeechPrivacy` `HasAccepted=0` (cloud speech declined); OFF removes the value |
| 85 | `85-InkTyping` | `RestrictImplicitTextCollection=1` and `RestrictImplicitInkCollection=1`; OFF removes both |
| 86 | `86-LanguageList` | `HttpAcceptLanguageOptOut=1`; OFF removes the value |
| 87 | `87-TailoredExperiences` | `TailoredExperiencesWithDiagnosticDataEnabled=0`; OFF removes the value |
| 88 | `88-StartRecommendations` | `Start_IrisRecommendations=0`; OFF removes the value |
| 89 | `89-HiddenFiles` | `Hidden=1` (protected system files stay hidden); OFF writes `0` |
| 90 | `90-FullPath` | `CabinetState` `FullPath=1`; OFF writes `0` |
| 91 | `91-TaskbarSmallIcons` | `TaskbarSmallIcons=1`; sign out or restart Explorer; OFF writes `0` |
| 92 | `92-HoverDelay` | `ExtendedUIHoverTime=0`; OFF removes the value |
| 93 | `93-KeyboardRepeat` | `KeyboardDelay='0'` and `KeyboardSpeed='31'`; OFF restores delay `1` |
| 94 | `94-AudioDucking` | `UserDuckingPreference=3`; OFF removes the value |
| 95 | `95-WerUi` | `DontShowUI=1`; reports still follow the WER policy; OFF removes the value |
| 96 | `96-PagingExecutive` | `DisablePagingExecutive=1`; reboot; ON snapshots the previous value under `ProgramData\AstraMax\Security`, OFF restores it or removes it |
| 97 | `97-Maintenance` | `MaintenanceDisabled=1`; ON snapshots the previous value, OFF restores it or removes it |
| 98 | `98-RestartApps` | `Winlogon` `RestartApps=0`; OFF removes the value |
| 99 | `99-ClearPagefile` | `ClearPageFileAtShutdown=1`; shutdown takes longer; ON snapshots the previous value, OFF restores it or removes it |
| 100 | `100-Wsh` | Windows Script Host `Enabled=0`; ON snapshots the previous value, OFF restores it or removes it. Breaks `.vbs`/`.js` scripts, so it is marked risky |

The five debloat rows run the same `Debloat.ps1` the wizard used, so the wizard and the app never
diverge. ON applies that tier (tiers are cumulative, so ON on 44 includes 42 and 43, and ON on 62
includes all of them). OFF cannot reinstall apps — the row reports where the removal log is instead
of pretending; the Store comes back with `wsreset -i` and the rest through the Store, `winget` or the
names in `removed.json`. Row 44 asks for confirmation because it takes the Store and OneDrive with
it; row 62 asks because it is irreversible; row 63's OFF restores the exact `Start` values saved in
`service-state.json`.

This is the "Atlas-style" after-install control surface. `Restore.ps1` still exists for a
scripted full rollback; the menu is for one change at a time without re-reading flags.

## Optional extras

- **USB power saving off** â€” clears `MSPower_DeviceEnable` for attached devices (helps mice/keyboards that drop out).
- **OneDrive sync off** â€” policy plus process stop.
- **Edge background off** â€” Startup Boost and Background Mode policies.
- **Driver updates blocked** â€” prevents Windows Update from replacing vendor GPU drivers.

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

## Astra Tweaks app

The second checkbox deploys the bundled **Astra PC** app instead of a hand-rolled shell.
`Tasks/astra-app.yml` copies `Astra.exe` (v1.6.4, 78 MB) to `C:\AstraMax\AstraTweaks\`, copies
the helper scripts (`Verify.ps1`, `Restore.ps1`, `Cleanup.ps1`, `Network.ps1`, `Tweaks.ps1`,
`QoL.ps1`) to `C:\AstraMax\`, and creates **Astra Tweaks** shortcuts on the Desktop and in the
Start Menu with the working directory set to the app folder.

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
- The deploy step only copies files and writes shortcuts. The app itself has not been launched
  from an AME-injected image; test it once on a clean VM.

The earlier PowerShell/WPF shell is kept in `legacy/AstraCenter.ps1` for reference. It is no
longer deployed or packaged.

## Build and validate

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate.ps1
powershell -ExecutionPolicy Bypass -File tools/build.ps1
```

`validate.ps1` parses `playbook.conf`, parses every PowerShell helper, and verifies that every `!task` include exists. `build.ps1` checks required files, packages `src/` with `playbook.conf` at the archive root, prints contents and SHA256, and writes `AstraMax.apbx` unless `-Output` is given. The 1.3.6 artifact built from this tree is `Astra-1.3.6.apbx`, SHA256 `E591C71FDB8BF783DE8B896412ABE2164CAD34D470852E8E9059F2DB3FF4C75A`.

The repository tracks `Astra-1.3.6.apbx` and the bundled app `src/Executables/AstraTweaks/Astra.exe` through Git LFS (install Git LFS before cloning). Historical builds, `src/Executables/Astra-Max-Setup.exe`, the vendor installers in `src/Executables/Redist/`, `tools/7zr.exe` and the retired `legacy/` dashboard are excluded; supply those locally before running `build.ps1`, which fails its required-files check without them.

The `.apbx` must be a **7z archive, AES-256 encrypted with password `malte`, with the file list encrypted** (`-mhe=on`). That is AME Wizard's convention; a plain zip is rejected at load with *"Playbook must be encrypted using 'malte' as the password."* `build.ps1` does this through the portable `tools/7zr.exe` (download it from https://www.7-zip.org/a/7zr.exe if missing) using the equivalent of:

```powershell
7z a -t7z -p'malte' -mhe=on -mx=9 AstraMax.apbx playbook.conf playbook.png Configuration Executables
```

The script then re-lists the archive with the password, confirms `playbook.conf` is at the root, confirms the header list is *not* readable without the password, and runs an integrity test before printing the hash. If you rebuild with a stock 7-Zip install, use `pwsh tools/build.ps1 -Output <path>` with `7zr.exe` in `tools/`, or run the command above yourself.

## Apply

1. Download AME Wizard Beta and a clean Windows 11 ISO.
2. Drag the ISO into AME Wizard, then drop `AstraMax.apbx` in.
3. Pick preset, debloat tier, service tier, components, power/interrupts, network, DNS/DoH, game profiles/extras, input/power, quality-of-life and latency extras, Defender and VBS options.
4. Finish, write the image to USB (Rufus or built-in), and install â€” or apply to the running system if you drop the `FreshInstall` requirement.

If AME still refuses the file at load, check the message. `Playbook must be encrypted using 'malte' as the password` means the archive was repacked (for example re-zipped or re-saved by an editor) and lost its 7z/AES encryption â€” rebuild it with `tools/build.ps1`. A generic "invalid playbook" with this archive usually means the AME Beta build is older than the playbook schema; the public Atlas/NOVA playbooks are the reference for the currently supported action names.

## Verification status for 1.3.6

Safe fixture tests cover theme-key preservation, End task, the four optional toggles, the animation toggle, the five gaming shell toggles (including Edge policy write and delete-only-own-values), the three extra privacy toggles (Spotlight pair, setup-prompt value, recently added apps value; write and default restore), the NVIDIA diagnostic constants (Store id, PDP URI, winget command, `nvcplui.exe`, package family, `wuauserv`/`BITS`) and the MIXED status line, CPU/PCIe/disk AC-only writes and exact restoration, GPU tokens, dynamic-tick status parsing, game config/partial restoration, empty Lively layouts, the Insane service snapshot mapping, the per-user template and service-host snapshots, the optional-feature snapshot-once behavior, catalog rows 65-77, the new wizard pages and their task gates, and the bundled Redist paths. The service trace cleanup is fixture-tested: an orphaned cache folder is deleted, a live service's folder is refused, stale per-user instance keys are matched by template and removed while unrelated keys stay. The native host was verified on the development PC: its surface shows hair-only pixel movement plus red and blue glow deltas over time, the desktop capture shows the red pulse, and a fullscreen test window froze all three regions until it closed. Static/live restore paths and the startup shortcut were exercised. The image and mask data stay local.

The live `Set-Service` snapshot/restore round-trip on a real service was blocked by the action policy and is unexecuted; only the mapping and file format are fixture-tested. The same applies to the per-user template writes, the `SvcHostSplitThresholdInKB` write and their restore paths: the JSON formats are fixture-tested, but no live service template or host-grouping change was applied on this PC. The optional-feature disable/restore path, the `bcdedit` write/restore path (blocked by elevation in the fixture run) and the three bundled installers inside an AME-injected image were not executed; their arguments and file hashes are verified, nothing more. The package-data and AppModel trace cleanup is fixture-tested for family-folder discovery and static-checked; no live package data was deleted on this already-cleaned host, so the delete path remains VM-first. OneDrive install-data/settings cleanup is also static-checked only; no live OneDrive uninstall was run on this PC. Service cache-folder deletion was exercised only against temp folders, and stale per-user key removal only against a test registry key; no real WER, SoftwareDistribution, Search, MapData, Diagnosis, spool or notification path was deleted on this PC, so the real-path delete remains VM-first. The new per-user toggles were also exercised live on the development PC (`QoL.ps1 -Spotlight/-Scoobe/-StartRecentApps On` then `Off`), the prior values were restored afterwards, and module status/report paths were read. The NVIDIA tools page, its task gate, row 73 and the shortcut writer are static-checked and the page is validated as unchecked; this PC has no NVIDIA adapter, so the GPU/app/Control Panel detection ran only in its "no adapter" path, the diagnostic never reached its install branch, no `winget`/Store install was attempted, and no NVIDIA download page was opened or installer run. Module 74 ran only its "service not installed" path because this PC has no NVIDIA telemetry service, so its snapshot/restore JSON round-trip is static-checked, not executed. The control center was launched from source, non-elevated (read-only), so the sidebar and search could be inspected; applying rows from the GUI was not exercised. Reboot startup, fresh AME/ISO deployment, game benchmarks and the bundled app/debloat engine on an injected image remain untested. A 50-60 idle process count on 25H2/26H2 was not observed on a reference image and is not promised. These are release checks, not claimed successes.

New in 1.3.4, `Security.ps1` was fixture-tested with a temporary `ProgramData` and redirected registry paths: ON wrote `Warn` with policy `1`, `EnableMulticast=0` and `NoDriveTypeAutoRun=255`, and created one snapshot per item; OFF restored the prior AutoRun and SmartScreen values, removed the LLMNR value and deleted the snapshot; OFF without a snapshot wrote `Off`/`0`. The same harness covers the new `QoL.ps1` switches (`-SecurityNotifications`, `-CloudClipboard`, `-GameBarTips`) and catalog rows 78-83. The two new wizard pages, their default states and the harden/security task gates are static-checked. The hardening and disable-security actions were not executed live from an AME run, so they stay VM-first. Defender and VBS now default to disabled in the wizard; that changes only the default selection, the underlying `security.yml` actions are unchanged, and the live Defender, VBS and BCD writes remain unexecuted on this PC.

The 17 rows added in 1.3.5 (84-100) were fixture-tested the same way: each `QoL.ps1` toggle wrote its documented value and removed or restored it on OFF; `Tweaks.ps1 -WerUi` hid and restored the crash dialog; and `Security.ps1` snapshotted and restored `DisablePagingExecutive`, `MaintenanceDisabled`, `ClearPageFileAtShutdown` and Windows Script Host `Enabled` against temp registry paths, with the snapshot files created and cleared. The catalog is asserted at exactly 100 rows and rows 84-100 are read by the menu and GUI through `Catalog.ps1`. The four kernel-level toggles (paging executive, maintenance, pagefile, WSH) were not applied to the live machine, and the Start, taskbar, Explorer and privacy toggles were not applied from an AME run; the status logic was exercised against the fixture keys only. WSH off is the one new row marked risky because it stops `.vbs`/`.js` scripts that some installers use.

New in 1.3.6, the post-install window was rendered from source and inspected both offscreen and on-screen: all 13 categories fit the compact sidebar without scrolling at the default 1260x820 size, the list shows all 100 rows with working vertical scroll (row 100, "Windows Script Host off", renders at the bottom), no row control overflows its panel, and each category filter returned the expected count: Performance 16, CPU 3, GPU 4, Gaming 8, Network 5, Privacy 14, Shell 22, System 12, Input 3, Appearance 4, Security 5, Debloat 4. The probe deliberately skipped the live status rescan and applied no tweak; only row rendering and filter counts were verified from the GUI. A catalog-to-sidebar guard is now part of the test suite: every catalog group must have a sidebar entry and a description, and the catalog must stay at 100 rows.

## Smoke-test checklist (VM first)

1. Wizard shows 37 pages; preset defaults to Recommended, debloat/services to Light, wallpaper to personal live import, hardening to all three checked and Defender/VBS to disabled. Each radio page has at most four choices; both Insane strips are unchecked checkboxes on their own warned pages; the gaming latency and shell pages, the extra privacy page, the disable-security page and the NVIDIA tools page are unchecked.
2. Light run changes registry only; no services change.
3. Recommended disables `DiagTrack`/`SysMain`; Extreme adds `WSearch`/`Spooler`; Insane adds `DoSvc`/`WpnService`.
4. Desktop wallpaper changes to the selected Astra theme and survives a sign-out; the file exists at `C:\Windows\Web\Wallpaper\Astra\astra-wallpaper.png`.
5. Balanced power page sets `CPMINCORES=100` on AC and DC; other plans are untouched.
6. Interrupt page logs GPU/NIC MSI hits; no device fails to boot after restart. Aggressive/Pinned set `DevicePolicy` 5/4 respectively.
7. Network balanced leaves autotuning at `normal`; low latency adds the Nagle/NetBIOS values. `ipconfig /all` still shows a valid lease.
8. DNS provider applies only to adapters with a gateway; DoH appears in `Get-DnsClientDohServerAddress` (Windows 11).
9. Astra installer runs and installs after the preset steps.
10. Astra Tweaks opens from the Desktop or Start Menu shortcut; `C:\AstraMax\AstraTweaks\Astra.exe` reports v1.6.4 and its log at `%LOCALAPPDATA%\AstraPC\Logs\astra.log` shows a start line.
11. With the network cable pulled, DirectX, Visual C++ and .NET Desktop 8 install from the bundled `Redist` folder; `.NET 3.5` succeeds or is skipped cleanly when no source is available. `Get-ChildItem 'C:\Program Files\dotnet\shared\Microsoft.WindowsDesktop.App'` shows an 8.0.x folder.
12. Siege/Fortnite shortcuts appear; running one after install reports detected exe and config paths.
13. Game profiles preserve unrelated GPU tokens, skip absent games, refuse changes while the game is running, and restore original config values without touching anti-cheat or global capture.
14. Launch-options checkbox writes `Siege.txt`/`Fortnite.txt`; with Steam closed and a non-empty Siege string, only the `359550` block changes and a `.astra-backup` exists.
15. Defender defaults to disabled; choosing â€œkeepâ€ only throttles scans, â€œdisableâ€ turns off real-time protection (tamper protection may block it).
16. VBS defaults to disabled; that choice clears `hypervisorlaunchtype`, memory integrity and Credential Guard. Confirm on a system that does not need Vanguard/FACEIT.
17. Quality-of-life pages land: classic-menu CLSID key exists (restart Explorer to see the menu), `LongPathsEnabled=1`, `TaskbarAl=0`, `AppsUseLightTheme=0`, and `Verify.ps1` lists them. The optional toggles page (off by default) writes `GlobalUserDisabled=1`, `Win32PrioritySeparation=38`, `ShowSyncProviderNotifications=0` and `NoWindowMinimizingShortcuts=1` when ticked; post-install rows 58-61 flip each back. The separate animations page writes `MinAnimate=0` and `TaskbarAnimations=0`; row 64 or `QoL.ps1 -AllOff` restores both. The gaming shell pages (off by default) write `ToastEnabled=0`, `MenuShowDelay='0'`, the four accessibility values, `PenWorkspaceButtonDesiredVisibility=0` and the four Edge policies; rows 68-72 flip each back and `Verify.ps1` lists them under `Gaming shell extras`. The extra privacy page (off by default) writes `RotatingLockScreenEnabled=0`, `RotatingLockScreenOverlayEnabled=0`, `ScoobeSystemSettingEnabled=0`, `Start_TrackProgs=0` and `CloudClipboardAutomaticUpload=0`; rows 75-77 and 82 or `QoL.ps1 -AllOff` remove them again, and the Game Bar tips option writes `ShowStartupPanel=0` (row 83 writes it back).
18. Latency extras: `GlobalTimerResolutionRequests=1`, every adapter reports â€œAllow the computer to turn off this deviceâ€ disabled, CPU idle shows disabled on AC only when selected, and `Get-MMAgent` matches the compression choice.
19. Wallpaper page: picking "red and purple" writes `Astra-Wallpaper-RedPurple.png` to `C:\Windows\Web\Wallpaper\Astra\astra-wallpaper.png` and the desktop shows the crimson scene.
20. Post-install app: **Astra Post Install** opens the red/purple control center with no console window and all 100 rows showing a live state; the category sidebar (including **Debloat** and **GPU**), the search box and the ON/OFF buttons on rows 01 and 44 all work; ON on 42 removes the Light apps and the row flips to ON, ON on 44 asks for confirmation; ON on 62 asks for confirmation and is excluded from ALL; ON on 73 prints the adapter/driver/App/panel/Store/winget/`wuauserv`/`BITS` diagnosis and the numbered fix plan, installs the panel with winget when the Store and services are healthy, and otherwise prints the exact `Debloat.ps1 -Restore`, `wsreset -i`, winget and nvidia.com/drivers steps; ON on 74 disables `NvTelemetryContainer` only when it exists; rows 78-80 report the hardening values and restore them on OFF; items 81-83 toggle the Security Center toast, cloud clipboard upload and Game Bar startup tips; items 84-100 cover the privacy, Explorer, taskbar, keyboard, audio, crash-dialog, memory, maintenance and script-host toggles, with 100 marked risky; item 21 switches the wallpaper to red and purple and back to midnight blue; `PostInstall.ps1 -All Off` restores settings where supported (risky items skipped unless `-IncludeRisky`; personal wallpaper rows always excluded; removed apps still need reinstallation).
21. Windows extras page: with all four on, `StartupDelayInMSec=0`, `IsDynamicSearchBoxEnabled=0`, the three `SubscribedContent-*Enabled` values are 0 and `ShowRecent`/`ShowFrequent` are 0; `Verify.ps1` lists them under `Windows extras`.
22. Siege launch options: `SIEGE UBI ARGS` writes `C:\AstraMax\LaunchOptions\Siege.txt` and drops `Rainbow Six Siege (Astra).url` on the Desktop that opens `uplay://launch/635/0`; with a non-empty Siege string and Steam closed, the saved `LaunchOptions.json` value is also written into Steam's `359550` block.
23. Debloat Light removes Clipchamp/news/weather/Solitaire/People for the signed-in user, other accounts and as provisioned packages; `C:\AstraMax\Debloat\removed.json` lists each one with its full package name, and Moderate additionally drops Mail, Teams and Maps. Extreme removes the Store (`wsreset -i` brings it back) and takes OneDrive out with `OneDriveSetup.exe /uninstall`, then deletes its install data/settings while leaving `%USERPROFILE%\OneDrive` files alone. After each package is gone its `%LOCALAPPDATA%\Packages\<family>` and `C:\ProgramData\Packages\<family>` data folders and its HKCU AppModel repository/system-data keys are deleted; `Debloat.ps1 -Level Status` reports `app data leftovers : 0 folder(s) for tuned apps`. The separate Insane checkbox removes Calculator/Notepad/Snipping Tool/Paint/Sticky Notes plus Journal/Whiteboard/Widgets/Quick Assist, and disables the 19 non-gaming optional features into `feature-state.json`; it reports that apps and deleted data cannot be undone.
24. Service tier: Light sets `MapsBroker`/`Fax`/`RemoteRegistry` to Disabled and leaves `DiagTrack` alone; Moderate also stops `DiagTrack`/`SysMain`; Extreme also stops `WSearch`/`Spooler`/`WpnService`; the separate Insane process-diet checkbox also stops `wuauserv`/`BITS`, RDP, Xbox, biometrics, camera, smart cards, diagnostics, UPnP discovery, VPN dialing, update orchestration and 10 per-user templates, then raises `SvcHostSplitThresholdInKB` to `0xFFFFFFFF` (reboot). After each service reports Disabled its cache/report folders are deleted (`SoftwareDistribution\Download`, `ProgramData\Microsoft\Network\Downloader`, WER queues/archives, `ProgramData\Microsoft\Search\Data`, `MapData`, `Diagnosis`, WDI, `spool\PRINTERS`, the notification database) and every deletion lands in `removed.json` with kind `service-data`; Insane also removes stale `<Template>_<LUID>` keys (kind `user-service-stale`) while live instances stay until sign-out. Before the first change `service-state.json` records each real `Start` value, `user-service-state.json` records each template, and `kernel-state.json` records the previous host value or its absence; `Debloat.ps1 -Restore` replays all three exactly (Manual stays Manual, delayed auto stays delayed), starts services that were running and re-enables the optional features recorded by Insane, but deleted caches stay deleted. `-Level Status` reports "services Light : N of 8 disabled", the per-user template count, the host-grouping state, `service data leftovers` and the stale key count; `Verify.ps1` prints the total process and svchost counts.
25. Gaming latency extras (unchecked by default): ticking PCIe ASPM off and disk idle off writes AC index `0` and leaves the DC values alone; `powercfg /query` shows the new AC values and `HardwareTweaks.ps1 -Mode Off` restores the saved indices. Dynamic tick requires an elevated run, writes `disabledynamictick Yes`, and OFF restores the saved value or deletes it; reboot between checks.
26. NVIDIA tools page (unchecked by default): ticking it adds `Get NVIDIA App.url` and `NVIDIA Drivers.url` to the Desktop and Start Menu, and both open the official nvidia.com pages. `NvidiaTools.ps1 -Mode Status` prints the adapter, driver, NVIDIA App, Control Panel, Store, winget and `wuauserv`/`BITS` lines; `-Mode Install` prints the numbered fix plan, runs `winget install "NVIDIA Control Panel" --id 9NF8H0H7WMLT -s msstore` when the Store and its services are healthy, and otherwise names `Debloat.ps1 -Restore`, `wsreset -i`, the Store PDP URI and nvidia.com/drivers. Row 73 shows the result as ON, OFF (no adapter) or MIXED with the missing items and blockers. No NVIDIA package is ever removed by debloat.
27. Security hardening page (all three ticked by default): `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer` `SmartScreenEnabled='Warn'`, policy `EnableSmartScreen=1`, policy `EnableMulticast=0` and `HKCU\...\Policies\Explorer` `NoDriveTypeAutoRun=255` are written, and `ProgramData\AstraMax\Security` holds one snapshot per item. `Security.ps1 -AllOff` (or Restore.ps1 `-Security`) restores the previous values or deletes the ones that did not exist. The disable-security page (unchecked) runs later: it writes `SmartScreenEnabled='Off'` with policy `0` and `Windows.SystemToast.SecurityAndMaintenance` `Enabled=0`; the hardening page wins if both are ticked.
28. Rows 84-100: turning each on writes only its documented value (online speech `HasAccepted=0`, input restrictions, language opt-out, tailored experiences, Start recommendations, hidden files, full path, taskbar size and hover delay, keyboard repeat, audio ducking, `DontShowUI`, paging executive, maintenance, `RestartApps`, pagefile clearing, WSH). OFF restores the Windows default or the saved snapshot; the four kernel-level rows (96, 97, 99, 100) need a reboot to fully show, and row 100 stops `.vbs`/`.js` scripts until it is turned off.

Machine-wide changes run as `system`. Per-user values (wallpaper, shortcuts, game configs) run as the
signed-in user through `currentUserElevated`, and `!registryValue` `HKCU` writes land in every loaded
user hive, so they cover accounts other than the one that ran the wizard. If the wizard's action names
differ in your AME build, compare against the public Atlas/NOVA playbooks before shipping.

## Rollback

Run `Restore.ps1` for everything the playbook changed (or use `Astra.exe` for its own
backups). From a prompt:

- **Core parking:** `powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 0` (and `setdcvalueindex`), then `powercfg /setactive SCHEME_CURRENT`.
- **Interrupts:** Device Manager â†’ device â†’ Details â†’ remove the `Affinity Policy` keys, or set `DevicePolicy=0`; reboot. Restoring `MSISupported=0` is only needed if a device misbehaves.
- **DNS:** adapter settings â†’ Obtain DNS server address automatically.
- **DoH:** `Remove-DnsClientDohServerAddress -ServerAddress <ip> -Confirm:$false`.
- **Quality of life:** delete `HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}` for the classic menu; set `TaskbarAl=1`, `ShowSecondsInSystemClock=0`, `LaunchTo=2`, `AppsUseLightTheme=1`, `Start_IrisRecommendations=1`, `LongPathsEnabled=0` and `EnableClipboardHistory=0` for the rest; set `GlobalUserDisabled=0`, delete `BackgroundAppGlobalToggle` and `ShowSyncProviderNotifications`, set `Win32PrioritySeparation=2`, and delete `NoWindowMinimizingShortcuts` for the optional toggles. `Restore.ps1 -QoL` does all of it.
- **Latency extras:** set `GlobalTimerResolutionRequests=0`, re-enable adapter power saving in Device Manager, run `powercfg` `IDLEDISABLE=0` on AC/DC, and `Enable-MMAgent -MemoryCompression`. The gaming extras use `HardwareTweaks.ps1 -Feature PciePower|DiskIdle|DynamicTick -Mode Off` (each restores its saved index or BCD value); reboot after restoring dynamic tick.
- **Gaming shell extras:** set `ToastEnabled=1`, `MenuShowDelay='400'`, the accessibility `Flags` back to `510`/`126`/`58` with `WinEnterLaunchEnabled=1`, `PenWorkspaceButtonDesiredVisibility=1`, and delete `HubsSidebarEnabled`, `EdgeShoppingAssistantEnabled`, `WebWidgetAllowed` and `HideFirstRunExperience`. `QoL.ps1 -AllOff` covers all five.
- **Windows extras:** delete `StartupDelayInMSec`; set `IsDynamicSearchBoxEnabled=1`; set `SubscribedContent-338387Enabled`, `-338388Enabled`, `-310093Enabled`, `ShowRecent` and `ShowFrequent` to `1`. `Tweaks.ps1 -AllOff` covers all four.
- **Debloat:** `Debloat.ps1 -Restore` restores each service's exact snapshot startup type and prints the reinstall list; `wsreset -i` brings the Store back (Extreme). Apps are reinstalled from the Store, `winget`, or the exact package names in `C:\AstraMax\Debloat\removed.json` â€” for another account, install once and it becomes available to everyone. Removed provisioned copies are not restored automatically; a clean image is the only full reset.
- **Services:** `Debloat.ps1 -Restore` (or post-install row 63 OFF) replays `service-state.json`: Automatic, delayed Automatic, Manual and Disabled are restored exactly, and services that were running are started again. It also restores the 10 per-user templates from `user-service-state.json` (sign out/in to start them) and the previous `SvcHostSplitThresholdInKB` value from `kernel-state.json` (reboot to apply), then re-enables any optional feature recorded in `feature-state.json`. Service cache/report folders and stale per-user keys deleted by the service tier are not restored; Windows rebuilds the caches and recreates instance keys only when the service runs again. A single service can also be set back in `services.msc`.
- **Steam launch options:** clear the field in Steam properties, or restore `localconfig.vdf.astra-backup` with Steam closed.
- **Anything after install:** open the **Astra Post Install** app and press `ALL OFF` (or filter first; risky items ask or stay put), or run `PostInstall.ps1 -All Off`. On its own, module `20-Defender.ps1 -Mode Off` re-enables real-time protection.
- **Game Bar capture:** Settings â†’ Gaming â†’ Captures â†’ turn background recording back on.
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
