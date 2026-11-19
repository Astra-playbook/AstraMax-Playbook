document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    const value = button.dataset.copy;
    let copied = false;

    try {
      await navigator.clipboard.writeText(value);
      copied = true;
    } catch {
      const field = document.createElement("textarea");
      field.value = value;
      field.setAttribute("readonly", "");
      field.style.position = "fixed";
      field.style.opacity = "0";
      document.body.appendChild(field);
      field.select();
      try {
        copied = document.execCommand("copy");
      } catch {
        copied = false;
      }
      field.remove();
    }

    if (!copied) {
      const target = button.closest(".hash-chip, .sha-box")?.querySelector("code");
      if (target) {
        const range = document.createRange();
        range.selectNodeContents(target);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
      }
    }

    const previous = button.textContent;
    button.textContent = copied ? "Copied" : "Select manually";
    button.classList.toggle("copied", copied);
    window.setTimeout(() => {
      button.textContent = previous;
      button.classList.remove("copied");
    }, 1800);
  });
});

const year = document.getElementById("year");
if (year) {
  year.textContent = new Date().getFullYear();
}

const PAGES = [
  {
    n: 1, title: "Tuning preset",
    prompt: "Choose how aggressively Astra tunes Windows. Tiers are cumulative: Recommended includes Light, Extreme includes Recommended, Insane includes Extreme.",
    options: [
      "Light — safe UI and input tweaks, no services touched",
      "Recommended — gaming optimizations, telemetry and lookup services off",
      "Extreme — maximum latency reduction, extra services and memory tweaks",
      "Insane — Extreme plus Store, push, SMB and Teredo hardening; expect breakage",
    ],
  },
  {
    n: 2, title: "App debloat",
    prompt: "Remove preinstalled Windows apps. Tiers are cumulative. Provisioned copies are removed for every account, so this is not a toggle: apps come back from the Store or winget, and Extreme removes the Store itself (restore with wsreset -i). Each removed package also loses its package-data folders and per-user AppModel registry keys; Extreme additionally cleans OneDrive install data and settings but never the user's synced files.",
    options: [
      "None — keep every preinstalled app",
      "Light — Clipchamp, news, weather, Bing search, Tips, Solitaire, People",
      "Moderate — Light plus Mail, Maps, Teams, Phone Link, Office hub, 3D/Print, Family, media and Alarms",
      "Extreme — Moderate plus Store, Photos, Camera, Xbox app, Copilot, OneDrive",
    ],
  },
  {
    n: 3, title: "Insane app strip",
    prompt: "INSANE APP STRIP (advanced). Adds the remaining non-gaming Microsoft apps on top of the selected tier: Calculator, Notepad, Snipping Tool, Paint, Sticky Notes, Get Help, OneNote, Wallet, Journal, Whiteboard, OneConnect, Raw Image Extension, Quick Assist, the Xbox speech overlay, Widgets and the web experience. This tier also removes 19 non-gaming Windows optional features (Fax, Work Folders, Simple TCP, Telnet, TFTP, SNMP, NFS, Remote Desktop client, SMB1, Windows Media Player and the printing extras). After each package is removed its per-user and shared package-data folders and per-user AppModel registry keys are deleted, so the app leaves no data behind. Edge, WebView2, media codecs, DirectX runtimes and Xbox identity/Game Services are kept because games and launchers need them. Choose this only for a nearly empty Windows that you can rebuild yourself.",
    options: ["Strip the remaining apps (Insane — irreversible)"],
  },
  {
    n: 4, title: "Service tier",
    prompt: "Set Windows background services to Disabled. Tiers are cumulative and independent of the preset: Light stops only services games never use, Moderate adds telemetry and maintenance, Extreme (Caution) also stops search indexing, printing, notifications and Store delivery.",
    options: [
      "None — leave every service at its Windows default",
      "Light — Maps, Fax, media sharing, telephony, Remote Registry, WAP push",
      "Moderate — Light plus telemetry, Superfetch, error reporting, Insider, location",
      "Extreme (Caution) — Moderate plus search index, print spooler, notifications, Store delivery, WinRM, ICS; search, printing and notifications stop",
    ],
  },
  {
    n: 5, title: "Insane process diet",
    prompt: "INSANE PROCESS DIET (advanced). On top of the selected tier this disables Windows Update and BITS, Remote Desktop host, Xbox/Game Pass, biometrics (Windows Hello), camera frame server, smart cards, diagnostics, UPnP discovery, VPN dialing, update orchestration, time sync, Security Center reporting, LAN file sharing and the per-user service templates that run one process per signed-in account. It also raises the service-host split threshold so Windows merges service hosts after a reboot. Every service disabled by any tier also loses its cache and report folders (update download cache, BITS jobs, WER queues, search index, offline maps, diagnostics staging, print queue and notification database) and stale per-user service keys are deleted, so the service leaves no data behind; each removal is recorded.",
    options: ["Strip the remaining services (Insane — restorable from the snapshot)"],
  },
  {
    n: 6, title: "Astra Toolbox and runtimes",
    prompt: "Install the new Gojo-themed Astra Toolbox and game runtimes. The toolbox replaces the old Astra Max interface and installer, retains all 228 original tweaks and their backups, and adds 38 reviewed settings for a total of 266. The frosted-glass/acrylic interface includes detailed System information, practical improvement checks and one-click Windows restore-point creation. It needs .NET Desktop Runtime 8 x64, installed from the bundled runtime if missing. The DirectX and Visual C++ installers are bundled for offline setup.",
    options: [
      "Astra Toolbox — Gojo UI, all tweaks and wallpaper gallery",
      "DirectX End-User Runtime June 2010 (bundled)",
      "Visual C++ 2005-2022 AIO, x86 + x64 (bundled)",
    ],
  },
  {
    n: 7, title: ".NET runtimes",
    prompt: "Older and newer .NET runtimes. .NET Desktop Runtime 8 is bundled and installs offline; .NET Framework 3.5 uses the Windows source and may need Windows Update.",
    options: [".NET Framework 3.5 (older games)", ".NET Desktop Runtime 8 (bundled x64)"],
  },
  {
    n: 8, title: "NVIDIA recovery",
    prompt: "NVIDIA recovery helpers. The NVIDIA Control Panel ships as a Store app and the Store is removed at Extreme, so it cannot be installed from there afterwards. Ticking this adds desktop and Start Menu shortcuts to the official NVIDIA App page and driver download page; installing a driver from nvidia.com restores the Control Panel without the Store, and the NVIDIA App is a normal desktop installer. NVIDIA packages are always excluded from app debloat and no NVIDIA installer is bundled or downloaded automatically. NvidiaTools.ps1 diagnoses the Control Panel, the NVIDIA App, the Store, winget, Windows Update and BITS later, names exactly what is missing, and installs the Control Panel from the Microsoft Store with winget when the Store and its services are healthy (falling back to exact wsreset/winget/driver steps).",
    options: ["Add NVIDIA app + Control Panel download shortcuts"],
  },
  {
    n: 9, title: "Core parking and interrupts",
    prompt: "CPU core parking and GPU/NIC interrupt handling. Balanced disables core parking and enables MSI interrupts where drivers support them. Aggressive also spreads interrupts; Pinned keeps them off core 0. Reboot required.",
    options: [
      "Leave Windows defaults",
      "Balanced — core parking off, MSI interrupts on",
      "Aggressive — Balanced plus GPU/NIC interrupts spread across all cores",
      "Pinned — Balanced plus GPU/NIC interrupts kept off core 0",
    ],
  },
  {
    n: 10, title: "Network stack",
    prompt: "Network stack tuning.",
    options: [
      "Leave Windows defaults",
      "Balanced — WPAD off, throttling off, TCP defaults verified",
      "Low latency — Balanced plus Nagle/NetBIOS/LLMNR off",
    ],
  },
  {
    n: 11, title: "DNS resolver",
    prompt: "DNS resolver for adapters with a default gateway. Static DNS is applied only to active adapters with a gateway. DHCP keeps your router's resolvers.",
    options: [
      "Use DHCP / automatic DNS",
      "Cloudflare — 1.1.1.1, 1.0.0.1",
      "Google — 8.8.8.8, 8.8.4.4",
      "Quad9 — 9.9.9.9, 149.112.112.112",
    ],
  },
  {
    n: 12, title: "DNS over HTTPS",
    prompt: "DNS over HTTPS (Windows 11).",
    options: ["Enable DNS over HTTPS"],
  },
  {
    n: 13, title: "Wallpaper",
    prompt: "The nine-image wallpaper pack is copied to Pictures\\Astra\\Wallpapers. Gojo is the default desktop theme; the toolbox can preview and apply the other supplied images later. Keep current only copies the gallery. Personal static/live imports remain local and need personal-wallpaper.png (plus hair-motion.json for the native live host). Static wallpaper changes save the previous background and fit for restore.",
    options: [
      "Gojo — Hollow Purple (bundled static wallpaper)",
      "Keep my current wallpaper; copy the gallery only",
      "Import my personal static wallpaper",
      "Apply my personal live wallpaper (lightweight native host)",
    ],
  },
  {
    n: 14, title: "Game profiles",
    prompt: "Game profiles save the Windows GPU preference and existing Siege/Fortnite config values. No game binaries, anti-cheat, fullscreen compatibility flags or global capture settings are changed. In-game Reflex, render mode and FPS caps remain manual; guides are included.",
    options: [
      "Rainbow Six Siege profile",
      "Fortnite profile",
      "Apply Siege launch options (Steam; requires Steam closed)",
      "Call of Duty HQ / Warzone GPU profile",
    ],
  },
  {
    n: 15, title: "Additional games",
    prompt: "Additional game profiles. Uses installed Steam manifests or a custom install directory. Absent games are skipped; run the profiles after installation. Originals can be restored with GameProfiles.ps1.",
    options: [
      "Apex Legends GPU profile and graphics guide",
      "Counter-Strike 2 GPU profile and graphics guide",
    ],
  },
  {
    n: 16, title: "Fortnite and extras",
    prompt: "Fortnite launch options and background system extras. These are optional and do not change game binaries or anti-cheat.",
    options: [
      "Write Fortnite launch option instructions (Epic)",
      "Disable USB device power saving (all devices)",
      "Disable OneDrive sync",
      "Disable Edge startup boost and background mode",
    ],
  },
  {
    n: 17, title: "Windows Update drivers",
    prompt: "Windows Update device drivers.",
    options: ["Block Windows Update driver installs"],
  },
  {
    n: 18, title: "Input and power",
    prompt: "Extra tweaks that save a few milliseconds and remove Windows smoothing. Each one can be reverted later from the Restore.ps1 helper in C:\\AstraMax.",
    options: [
      "Mouse acceleration off (1:1 input)",
      "Power throttling off",
      "Ultimate Performance power plan",
      "Fast startup off (clean driver load every boot)",
    ],
  },
  {
    n: 19, title: "CPU boost policies",
    prompt: "Dedicated CPU policies (AC power only). These are preferences, not an overclock. Firmware controls boost behavior; extra heat and power are possible. Benchmark frame times and leave these off on thermally limited systems.",
    options: [
      "CPU boost policy: Aggressive (PERFBOOSTMODE 2)",
      "CPU energy preference: performance (EPP 0)",
    ],
  },
  {
    n: 20, title: "GPU scheduling",
    prompt: "Dedicated GPU settings. Hardware-accelerated scheduling requires supported hardware/driver and a reboot. Windowed optimizations apply to compatible DX10/DX11 games. Neither is a guaranteed FPS improvement; originals are saved.",
    options: [
      "Request hardware-accelerated GPU scheduling (HAGS)",
      "Enable optimizations for windowed DX10/DX11 games",
    ],
  },
  {
    n: 21, title: "MMCSS priority",
    prompt: "CPU scheduling for games.",
    options: ["Raise MMCSS game task priority"],
  },
  {
    n: 22, title: "Explorer and taskbar",
    prompt: "Explorer, taskbar and Start quality-of-life options. Every one is per-user and reversible from the Restore.ps1 helper in C:\\AstraMax.",
    options: [
      "Classic right-click menu (Windows 10 style)",
      "Long path support (paths over 260 characters)",
      "Show seconds in the taskbar clock",
      "Open This PC instead of Home in Explorer",
    ],
  },
  {
    n: 23, title: "Privacy and nags",
    prompt: "Per-user privacy and nags, off by default. Lock screen Spotlight shows rotating pictures and tips; the post-update prompt asks you to finish setting up Windows after feature updates; the recently added apps list shows new installs in Start. All three only write registry values for the signed-in account and are reversible from Restore.ps1 -QoL.",
    options: [
      "Turn off lock screen Spotlight and its tips",
      "Turn off post-update setup prompts",
      "Hide the recently added apps list in Start",
      "Turn off cloud clipboard sync",
    ],
  },
  {
    n: 24, title: "Appearance and Start",
    prompt: "Appearance, Start and taskbar layout.",
    options: [
      "Dark mode for Windows and apps",
      "Hide Start menu recommendations",
      "Align taskbar icons to the left",
      "Enable clipboard history (Win+V)",
    ],
  },
  {
    n: 25, title: "Latency and memory",
    prompt: "Extra latency and memory tuning for desktops. Disabled CPU idle states run hotter and memory compression off wants 16 GB or more; leave both off on laptops.",
    options: [
      "Allow global timer resolution requests (Windows 11)",
      "Stop Windows powering down the network adapter",
      "Disable CPU idle states (runs hotter, lower latency)",
      "Disable memory compression (16 GB+ recommended)",
    ],
  },
  {
    n: 26, title: "Windows extras",
    prompt: "Windows extras for this release. All four are per-user, cosmetic or logon-speed only, and every one can be switched back from Restore.ps1 -QoL or the Astra app. The startup delay is the only one that changes boot feel; the rest remove tips, highlights and lists from the shell.",
    options: [
      "Remove the 10 second startup app delay",
      "Turn off search highlights",
      "Turn off lock screen tips and Windows suggestions",
      "Hide recent and frequent files in Explorer",
    ],
  },
  {
    n: 27, title: "Window animations",
    prompt: "Whole-OS animation toggle. Turns off window minimize/maximize fades and taskbar animations for the signed-in user; menus and transparency are handled by the visual-effects option. Sign out or restart Explorer to finish. Reversible from Restore.ps1 -QoL.",
    options: ["Turn off window and taskbar animations"],
  },
  {
    n: 28, title: "Optional shell toggles",
    prompt: "Four optional toggles, off by default. Every one is reversible from Restore.ps1 -QoL.",
    options: [
      "Stop background apps (sign out to apply)",
      "Foreground priority boost (Win32PrioritySeparation 38)",
      "Hide sync provider notifications in Explorer",
      "Turn off Aero Shake",
    ],
  },
  {
    n: 29, title: "PCIe, disk and tick",
    prompt: "Three AC-only latency extras from the Insane gaming layer. Originals are saved under %LOCALAPPDATA%\\AstraMax\\Backups and can be restored from Restore.ps1. Dynamic tick writes a BCD setting and needs a reboot; benchmark before keeping it.",
    options: [
      "Turn off PCIe link power saving (AC only)",
      "Disable the disk idle timeout (AC only)",
      "Disable the kernel dynamic tick (experimental, reboot)",
    ],
  },
  {
    n: 30, title: "Gaming shell extras",
    prompt: "Gaming shell extras, off by default. Toast pop-ups, the menu show delay and the accessibility shortcut keys are all per-user and reversible from Restore.ps1 -QoL. Do not turn off the accessibility shortcuts on a machine where someone relies on Sticky Keys or Toggle Keys.",
    options: [
      "Turn off notification pop-ups",
      "Remove the menu show delay (0 ms)",
      "Turn off accessibility shortcut keys",
    ],
  },
  {
    n: 31, title: "Ink and Edge strips",
    prompt: "Two more shell strips from the gaming layer, off by default. Both are reversible from Restore.ps1 -QoL. Hiding the Ink button is cosmetic; the Edge policies only hide the sidebar, shopping, widgets and first-run screens, they do not touch the browser engine games use for WebView2.",
    options: [
      "Hide the Windows Ink Workspace button",
      "Edge gaming policies (sidebar, shopping, widgets off)",
      "Turn off Game Bar startup tips",
    ],
  },
  {
    n: 32, title: "Taskbar End task",
    prompt: "Taskbar End task on Windows 11 23H2 or newer. Right-click a running application to terminate it without opening Task Manager. Unsaved work can be lost.",
    options: ["Enable the taskbar End task option"],
  },
  {
    n: 33, title: "Security hardening",
    prompt: "Security hardening, on by default. Turns SmartScreen on (Warn) with the policy enabled, disables LLMNR multicast name resolution and disables AutoPlay/AutoRun for every drive type. Previous values are saved under ProgramData\\AstraMax\\Security. Reversible from Restore.ps1 -Security.",
    options: [
      "Turn SmartScreen checks on",
      "Turn off LLMNR name resolution",
      "Turn off AutoRun for all drives",
    ],
  },
  {
    n: 34, title: "Disable security extras",
    prompt: "Disable security extras, off by default and a security trade-off. Turning SmartScreen off removes the checks and the policy; turning Security Center alerts off hides the Defender/Security toast notifications. If the hardening page above is also ticked, this page runs later and wins. Reversible from Restore.ps1 -Security.",
    options: ["Turn SmartScreen off", "Turn off Security Center toast alerts"],
  },
  {
    n: 35, title: "Windows Defender",
    prompt: "Windows Defender real-time protection.",
    options: ["Keep Defender enabled (scan throttling only)", "Disable Defender real-time protection"],
  },
  {
    n: 36, title: "Virtualization-Based Security",
    prompt: "Virtualization-Based Security.",
    options: ["Keep VBS enabled (required by some anti-cheats)", "Disable VBS (performance mode, no Vanguard/FACEIT)"],
  },
  {
    n: 37, title: "Capture and display extras",
    prompt: "Capture, display and network toggles ported from the Astra app, off by default. Game DVR stops background recording (manual Game Bar captures still work). Fullscreen optimizations off forces exclusive fullscreen; some overlays and alt-tab behaviour change. MPO off fixes flicker on some GPUs but can cost a little desktop smoothness and needs a sign-out. Releasing QoS reserved bandwidth removes the policy limit. Every value Astra writes is reproduced exactly and undone by Restore.ps1 -QoL.",
    options: [
      "Turn off Xbox Game DVR background recording",
      "Turn off fullscreen optimizations globally",
      "Disable the multiplane overlay (MPO)",
      "Release QoS reserved bandwidth",
    ],
  },
  {
    n: 38, title: "Search extras",
    prompt: "Start search and shell toggles, off by default. Keeping search local stops Bing web results; turning cloud search off stops Microsoft-account and work-account suggestions. Both make Start search lighter without touching the local index. Recall off blocks snapshots on Copilot+ PCs (no effect elsewhere). Hiding the Widgets button removes it from the taskbar. Reversible from Restore.ps1 -QoL.",
    options: [
      "Keep Start search local (no Bing web results)",
      "Turn off Start cloud search suggestions",
      "Turn off Recall snapshots (Copilot+ PCs)",
      "Hide the Widgets button",
    ],
  },
  {
    n: 39, title: "StartAllBack",
    prompt: "StartAllBack is a paid third-party Start menu and taskbar add-on with a per-user license (startallback.com). Ticking this downloads the official signed setup from startallback.com, installs it silently and adds an install shortcut to the desktop and Start menu. If the download or signature check fails, the shortcut opens the official page. Astra never redistributes the installer and does not cover StartAllBack in Restore.ps1. It changes the shell, not the search index: use the search options above to lighten Start search itself.",
    options: ["StartAllBack — download and install the official setup (paid add-on)"],
  },
  {
    n: 40, title: "Reviewed EXM Windows settings",
    prompt: "Reviewed EXM Windows settings, optional and reversible from Astra Toolbox or Restore.ps1 -Toolbox. Search history collection off does not erase existing history; silent notifications keep banners; automatic restart sign-on off may defer update setup until you sign in manually. These settings require the bundled .NET Desktop Runtime 8 when applied.",
    options: ["Do not collect device search history", "Silent notifications (keep banners)", "Disable automatic restart sign-on"],
  },
  {
    n: 41, title: "Chrome and wallpaper settings",
    prompt: "Reviewed EXM Chrome and wallpaper settings, all optional. Chrome background apps off stops background extensions after the last window closes; online spelling off keeps local spellcheck; location blocked breaks location-dependent websites. Restart Chrome and check chrome://policy. JPEG wallpaper quality 100 affects JPEG import only, not FPS. Original registry values are saved by the toolbox engine for exact restore; the bundled .NET Desktop Runtime 8 is required.",
    options: ["Stop Chrome background apps after closing Chrome", "Disable Chrome online spellcheck (keep local)", "Block Chrome website location by default", "JPEG wallpaper import quality 100"],
  },
  {
    n: 42, title: "Sign-in and Start preferences",
    prompt: "Optional Windows sign-in and Start preferences. Skip first-sign-in animation only affects new accounts and also suppresses Microsoft-account service opt-in prompts; hiding account details is not anonymity; hiding Recently added keeps applications installed. Policies may be ignored on Home or overridden by organization policy. Original values are saved for restore inside Astra System.",
    options: ["Skip the first-sign-in animation", "Hide additional account details at sign-in", "Hide recently installed apps in Start (restart required)"],
  },
  {
    n: 43, title: "Account and contacts permissions",
    prompt: "Optional Windows-app privacy restrictions. Account-information and contacts access are denied by default, which can break identity, personalization or contacts features. Per-app exceptions take precedence and arbitrary desktop programs are not universally covered. Pro, Enterprise, Education and IoT policies may be ignored on Home; organization policy can override them. Restart affected apps; original values can be restored inside Astra System.",
    options: ["Deny Windows-app account-information access", "Deny Windows-app contacts access"],
  },
  {
    n: 44, title: "Chrome privacy and notifications",
    prompt: "Optional Chrome privacy and notification choices. Online search suggestions off retains local history and bookmarks; speculative connections off may slow websites; blocking third-party cookies can break embedded sign-in; website alerts may be unavailable when notifications are blocked. Restart Chrome and check chrome://policy for acceptance. Existing site exceptions may still matter. Windows notifications and browser security checks remain unchanged; original registry values are saved.",
    options: ["Disable Chrome online search suggestions", "Disable Chrome speculative connections", "Block Chrome third-party cookies", "Block Chrome website notifications by default"],
  },
  {
    n: 45, title: "Chrome features and memory",
    prompt: "Optional Chrome features and memory preferences. Translation off removes the feature, not just prompts; asking where to save adds a dialog to every download; Google Cast off removes casting and requires restarting Chrome; Memory Saver discards eligible inactive tabs, which may reload when revisited (Chrome 108 or newer). Check chrome://policy for acceptance; Chrome may show managed settings. These are preferences, not guaranteed FPS gains, and their original registry values can be restored.",
    options: ["Disable Chrome built-in translation", "Ask where to save Chrome downloads", "Disable Google Cast in Chrome", "Enable Chrome Memory Saver"],
  },
  {
    n: 46, title: "Chrome Energy Saver",
    prompt: "Optional Chrome Energy Saver (Chrome 108 or newer). Activates on low battery and throttles browser frame rate to reduce power consumption; this is not a desktop-performance boost. Refresh Chrome policy or restart, and check chrome://policy for acceptance. Chrome may show managed settings. Original registry values are saved for restore inside Astra System.",
    options: ["Enable Chrome Energy Saver at low battery"],
  },
  {
    n: 47, title: "Settings, Store and message preferences",
    prompt: "Optional Windows Settings, Store and message preferences. Online tips off reduces online Settings help, not promotional tips; reopen Settings. Remote Store installation off keeps local installs and updates. Message cloud backup off only affects the applicable cellular-message feature, not general Phone Link, email or messaging. Pro, Enterprise, Education and IoT policies may be ignored on Home or overridden by organization policy. Original values are saved for restore inside Astra System.",
    options: ["Disable online tips in Windows Settings", "Block remote Microsoft Store app installation", "Disable cellular-message cloud backup and restore"],
  },
  {
    n: 48, title: "Chrome website device permissions",
    prompt: "Optional Chrome website device permissions, blocked by default when selected. Sensor-dependent sites and browser serial, Bluetooth or USB workflows can break; applicable site-policy exceptions may override defaults. Normal Windows sensors, COM ports, Bluetooth, headsets and USB hardware remain enabled. Minimum Chrome versions: sensors 88, Serial 86, Bluetooth 50, WebUSB 67. Restart Chrome and check chrome://policy for acceptance; Chrome may show managed settings. Original values are saved for restore inside Astra System.",
    options: ["Block Chrome website sensor access by default", "Block Chrome Web Serial requests by default", "Block Chrome Web Bluetooth requests by default", "Block Chrome WebUSB requests by default"],
  },
  {
    n: 49, title: "Chrome feedback and spellchecking",
    prompt: "Optional Chrome feedback and spelling preferences. Report an Issue off (Chrome 77+) removes the command and shortcut, not all browser metrics. All spellchecking off (Chrome 65+) loses local dictionaries, spelling suggestions and related accessibility assistance; choose the earlier online-only spellcheck option to keep local checking. Restart Chrome and check chrome://policy for acceptance; Chrome may show managed settings. No gaming gain is promised. Original values are saved for restore inside Astra System.",
    options: ["Hide Chrome's Report an Issue command", "Disable all Chrome spellchecking (including local)"],
  },
  {
    n: 50, title: "Windows-app personal-data permissions",
    prompt: "Optional Windows-app personal-data permissions, denied by default when selected. Calendar, mail, text/MMS and calling integrations can fail; existing calendar data and mail are not deleted and phone hardware stays enabled. These are AppPrivacy defaults, not direct ConsentStore edits; per-app policy exceptions override defaults and arbitrary Win32 apps are not universally covered. The corresponding user choices are locked while configured. Pro, Enterprise, Education and IoT policies may be ignored on Home or overridden by organization policy. Restart affected apps; original values are saved for restore inside Astra System.",
    options: ["Deny Windows-app calendar access by default", "Deny Windows-app email access by default", "Deny Windows-app text/MMS reading and sending by default", "Deny Windows-app phone-call access by default"],
  },
  {
    n: 51, title: "Windows-app diagnostics and history",
    prompt: "Optional Windows-app diagnostic, history, task and notification access restrictions. Other-app diagnostic, call-history, task-list and notification-reading integrations can fail. These do not disable Windows telemetry, error reporting, diagnostic services, scheduled tasks or ordinary notification banners/sounds; history and task lists are not erased. AppPrivacy defaults lock the corresponding user choices; per-app policy exceptions override defaults and arbitrary Win32 apps are not universally covered. Pro, Enterprise, Education and IoT policies may be ignored on Home or overridden by organization policy. Restart affected apps; original values are saved for restore inside Astra System.",
    options: ["Deny Windows-app access to other-app diagnostics", "Deny Windows-app call-history access by default", "Deny Windows-app task-data access by default", "Deny Windows-app notification-reading access"],
  },
  {
    n: 52, title: "Windows-app device and motion permissions",
    prompt: "Optional Windows-app device and motion permissions. Radio-control, unpaired wireless-device and motion-dependent integrations can fail; Wi-Fi/Bluetooth drivers and normal hardware stay enabled. Unpaired-device communication is not a trusted-devices policy. Motion access is a documented extra, not a proven equivalent of EXM's activity entry or Windows Activity History suppression. AppPrivacy defaults lock the corresponding user choices; per-app policy exceptions override defaults and arbitrary Win32 apps are not universally covered. Pro, Enterprise, Education and IoT policies may be ignored on Home or overridden by organization policy. Restart affected apps; original values are saved for restore inside Astra System.",
    options: ["Deny Windows-app control of radios", "Deny Windows-app unpaired-device communication", "Deny Windows-app motion-data access (documented extra)"],
  },
];

const GROUPS = [
  { title: "Preset and debloat", from: 1, to: 3 },
  { title: "Services", from: 4, to: 5 },
  { title: "What gets installed", from: 6, to: 8 },
  { title: "Hardware and network", from: 9, to: 12 },
  { title: "Wallpaper", from: 13, to: 13 },
  { title: "Game profiles", from: 14, to: 16 },
  { title: "Drivers, CPU and GPU", from: 17, to: 21 },
  { title: "Shell and quality of life", from: 22, to: 32 },
  { title: "Security", from: 33, to: 36 },
  { title: "Astra extras", from: 37, to: 39 },
  { title: "Reviewed EXM settings", from: 40, to: 41 },
  { title: "Windows preferences", from: 42, to: 43 },
  { title: "Chrome preferences", from: 44, to: 46 },
  { title: "More reviewed settings", from: 47, to: 52 },
];

const pad = (n) => String(n).padStart(2, "0");

function renderPlaybook() {
  const host = document.getElementById("pb-pages");
  if (!host || host.childElementCount) return;

  for (const group of GROUPS) {
    const section = document.createElement("section");
    section.className = "pb-group";

    const head = document.createElement("div");
    head.className = "pb-group-head";
    const title = document.createElement("h2");
    title.textContent = group.title;
    const range = document.createElement("span");
    range.textContent = `${pad(group.from)}–${pad(group.to)}`;
    head.append(title, range);

    const cards = document.createElement("div");
    cards.className = "pb-cards";

    for (const page of PAGES.filter((p) => p.n >= group.from && p.n <= group.to)) {
      const card = document.createElement("article");
      card.className = "pb-card";
      card.dataset.search = `${page.title} ${page.prompt} ${page.options.join(" ")}`.toLowerCase();

      const cardHead = document.createElement("div");
      cardHead.className = "pb-card-head";
      const num = document.createElement("span");
      num.className = "pb-num";
      num.textContent = pad(page.n);
      const h3 = document.createElement("h3");
      h3.textContent = page.title;
      cardHead.append(num, h3);

      const prompt = document.createElement("p");
      prompt.textContent = page.prompt;

      const options = document.createElement("ul");
      options.className = "pb-options";
      for (const option of page.options) {
        const item = document.createElement("li");
        item.textContent = option;
        options.append(item);
      }

      card.append(cardHead, prompt, options);
      cards.append(card);
    }

    section.append(head, cards);
    host.append(section);
  }
}

const siteView = document.getElementById("site-view");
const playbookView = document.getElementById("playbook-view");
const openButton = document.getElementById("open-playbook");
const backButton = document.getElementById("close-playbook");
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
let switching = false;
let savedScroll = 0;

function snapTargets(view) {
  if (view === siteView) {
    return view.querySelectorAll(":scope > header, :scope > main > section, :scope > footer");
  }
  return view.querySelectorAll(":scope > header, .pb-intro, .pb-group, .pb-footnote");
}

function dustBurst() {
  if (reduceMotion.matches) return;
  const layer = document.createElement("div");
  layer.className = "snap-layer";
  const colors = ["#b6e9ff", "#b9adff", "#d6f4ff", "#d6ccff", "#ffffff"];
  for (let i = 0; i < 150; i++) {
    const dot = document.createElement("i");
    const angle = Math.random() * Math.PI * 2;
    const distance = 60 + Math.random() * 340;
    dot.style.left = `${Math.random() * window.innerWidth}px`;
    dot.style.top = `${Math.random() * window.innerHeight}px`;
    dot.style.setProperty("--s", `${2 + Math.random() * 5}px`);
    dot.style.setProperty("--c", colors[i % colors.length]);
    dot.style.setProperty("--dx", `${Math.cos(angle) * distance}px`);
    dot.style.setProperty("--dy", `${Math.sin(angle) * distance - 70}px`);
    dot.style.setProperty("--d", `${0.8 + Math.random() * 0.9}s`);
    dot.style.setProperty("--delay", `${Math.random() * 0.4}s`);
    layer.append(dot);
  }
  document.body.append(layer);
  window.setTimeout(() => layer.remove(), 2400);
}

function swapView(from, to, focusTarget) {
  if (switching || !from || !to) return;
  switching = true;

  const outgoing = [...snapTargets(from)];
  const motion = !reduceMotion.matches;
  if (from === siteView) savedScroll = window.scrollY;
  dustBurst();

  if (motion) {
    outgoing.forEach((el) => {
      el.style.setProperty("--delay", `${(Math.random() * 0.45).toFixed(2)}s`);
      el.style.setProperty("--dur", `${(0.55 + Math.random() * 0.35).toFixed(2)}s`);
      el.classList.add("snap-target");
    });
    document.body.classList.add("snap-flash");
  }

  window.setTimeout(() => {
    outgoing.forEach((el) => {
      el.classList.remove("snap-target");
      el.style.removeProperty("--delay");
      el.style.removeProperty("--dur");
    });
    from.hidden = true;
    to.hidden = false;
    window.scrollTo({ top: to === siteView ? savedScroll : 0, behavior: "instant" });

    if (motion) {
      [...snapTargets(to)].forEach((el) => {
        el.style.setProperty("--delay", `${(Math.random() * 0.4).toFixed(2)}s`);
        el.classList.add("snap-material");
      });
    }

    window.setTimeout(() => {
      to.querySelectorAll(".snap-material").forEach((el) => {
        el.classList.remove("snap-material");
        el.style.removeProperty("--delay");
      });
      document.body.classList.remove("snap-flash");
      switching = false;
    }, motion ? 950 : 0);

    if (focusTarget) {
      focusTarget.focus({ preventScroll: true });
    }
  }, motion ? 1000 : 0);
}

if (siteView && playbookView && openButton && backButton) {
  renderPlaybook();

  const heading = playbookView.querySelector("h1");
  if (heading) heading.setAttribute("tabindex", "-1");

  openButton.addEventListener("click", () => swapView(siteView, playbookView, heading));
  backButton.addEventListener("click", () => swapView(playbookView, siteView, openButton));

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !playbookView.hidden) {
      swapView(playbookView, siteView, openButton);
    }
  });
  document.getElementById("explore-pages")?.addEventListener("click", () => openButton.click());
  document.getElementById("pb-home")?.addEventListener("click", (event) => {
    event.preventDefault();
    backButton.click();
  });
}

const screens = {
  overview: { file: "astra-glass-overview.png", alt: "Astra toolbox Overview in non-mutating preview mode.", caption: "Your workspace: the tweak library, System and the tools you actually use." },
  system: { file: "astra-glass-system.png", alt: "Astra System page with hardware details and Windows restore-point controls in preview mode.", caption: "System: hardware and Windows evidence, improvement checks, restore points and saved tweak backups." },
  tweaks: { file: "astra-glass-tweaks.png", alt: "The Astra tweak library with searchable, individually selectable settings and original-value snapshots.", caption: "The library: search, review the caveat, and choose an individual change. No blanket optimization button." },
  wallpapers: { file: "astra-glass-wallpapers.png", alt: "Astra's nine-wallpaper library and preview, with application disabled in preview mode.", caption: "Your backdrop: nine wallpapers, an actual preview and separate original-desktop restoration." },
};
const screenTabs = [...document.querySelectorAll("[data-screen]")];
function selectScreen(tab, focus = false) {
  const screen = screens[tab.dataset.screen];
  if (!screen) return;
  screenTabs.forEach((item) => {
    item.setAttribute("aria-selected", String(item === tab));
    item.tabIndex = item === tab ? 0 : -1;
  });
  const image = document.getElementById("screen-image");
  image.src = `assets/${screen.file}`;
  image.alt = screen.alt;
  document.getElementById("screen-caption").textContent = screen.caption;
  document.getElementById("screen-panel").setAttribute("aria-labelledby", tab.id);
  if (focus) tab.focus();
}
screenTabs.forEach((tab, index) => {
  tab.addEventListener("click", () => selectScreen(tab));
  tab.addEventListener("keydown", (event) => {
    let target;
    if (event.key === "ArrowRight") target = (index + 1) % screenTabs.length;
    if (event.key === "ArrowLeft") target = (index + screenTabs.length - 1) % screenTabs.length;
    if (event.key === "Home") target = 0;
    if (event.key === "End") target = screenTabs.length - 1;
    if (target === undefined) return;
    event.preventDefault();
    selectScreen(screenTabs[target], true);
  });
});

const pageSearch = document.getElementById("page-search");
function filterPages() {
  const query = pageSearch.value.trim().toLowerCase();
  let visible = 0;
  document.querySelectorAll(".pb-group").forEach((group) => {
    let count = 0;
    group.querySelectorAll(".pb-card").forEach((card) => {
      const matches = card.dataset.search.includes(query);
      card.hidden = !matches;
      if (matches) count++;
    });
    group.hidden = count === 0;
    visible += count;
  });
  document.getElementById("page-results").textContent = `${visible} of ${PAGES.length} pages`;
  document.getElementById("page-empty").hidden = visible !== 0;
}
if (pageSearch) {
  pageSearch.addEventListener("input", filterPages);
  filterPages();
}
