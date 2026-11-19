using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Automation;
using System.Windows.Interop;
using System.Windows.Markup;
using System.Windows.Media.Effects;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Astra.Core.Infrastructure;
using Astra.Core.Models;
using Astra.Core.Services;

namespace Astra.Toolbox
{
    internal sealed class Options
    {
        public bool Preview;
        public string Command = "ui";
        public string Value;
        public static Options Parse(string[] arguments)
        {
            var result = new Options();
            bool commandSeen = false;
            for (int i = 0; i < arguments.Length; i++)
            {
                string argument = arguments[i];
                if (argument == "--preview")
                {
                    if (result.Preview) throw new ArgumentException("Duplicate --preview.");
                    result.Preview = true;
                    continue;
                }
                if (commandSeen) throw new ArgumentException("Only one command is allowed.");
                commandSeen = true;
                switch (argument)
                {
                    case "--catalog": result.Command = "catalog"; break;
                    case "--apply": case "--revert": case "--apply-option": case "--revert-option": case "--self-test": case "--power": case "--clean": case "--wallpaper": case "--game": case "--restore-game":
                        result.Command = argument.Substring(2);
                        if (++i >= arguments.Length || arguments[i].StartsWith("--", StringComparison.Ordinal)) throw new ArgumentException("Missing value for " + argument);
                        result.Value = arguments[i];
                        break;
                    case "--restore-all": case "--restore-power": case "--restore-wallpaper": case "--restore-point":
                        result.Command = argument.Substring(2); break;
                    default: throw new ArgumentException("Unknown argument: " + argument);
                }
            }
            return result;
        }
    }

    internal sealed class WallpaperEntry
    {
        public string Id;
        public string Title;
        public string File;
        public string FullPath;
        public bool Available { get { return System.IO.File.Exists(FullPath); } }
    }

    internal sealed partial class ToolboxSession
    {
        public readonly List<TweakDefinition> Catalog;
        public readonly Dictionary<string, TweakDefinition> ById;
        public readonly Dictionary<string, TweakStatus> Statuses = new Dictionary<string, TweakStatus>(StringComparer.Ordinal);
        public readonly Dictionary<string, string> StatusErrors = new Dictionary<string, string>(StringComparer.Ordinal);
        public readonly LogService Log;
        public readonly AdminService Admin;
        public readonly TweakEngine Engine;
        public readonly PowerPresetService Power;
        public readonly CleanerService Cleaner;
        public readonly bool ReadOnly;
        public int MutationDispatches;
        public string StatusError;
        public static readonly string[] Games = new string[] { "Siege", "Fortnite", "Cod", "Apex", "CS2" };
        public static readonly string[] ReviewedOptions = new string[] {
            "qol.search-history-off", "exm-notification-sound-off", "exm-restart-sign-on-off", "abs.app.chrome-background-off", "exm-chrome-online-spelling-off", "exm-chrome-geolocation-off", "max.visual.wallpaper-full-quality",
            "sys-first-signin-animation-off", "sys-signin-account-details-off", "sys-start-recent-apps-off", "sys-app-account-info-off", "sys-app-contacts-off",
            "chrome-search-suggestions-off", "chrome-network-prediction-off", "chrome-third-party-cookies-off", "chrome-website-notifications-off", "chrome-translation-off", "chrome-download-location-prompt", "chrome-cast-off", "chrome-memory-saver-on", "chrome-low-battery-saver-on",
            "exm-settings-online-tips-off", "exm-store-push-install-off", "exm-message-cloud-sync-off", "exm-chrome-feedback-off", "exm-chrome-spellchecking-off", "exm-chrome-sensors-off", "exm-chrome-serial-off", "exm-chrome-bluetooth-off", "exm-chrome-webusb-off",
            "exm-app-diagnostics-off", "exm-app-calendar-off", "exm-app-email-off", "exm-app-messaging-off", "exm-app-phone-off", "exm-app-call-history-off", "exm-app-tasks-off", "exm-app-radio-control-off", "exm-app-notification-reading-off", "exm-app-unpaired-device-sync-off", "sys-app-motion-off"
        };

        public ToolboxSession(bool readOnly)
        {
            ReadOnly = readOnly;
            Catalog = FullCatalog();
            ById = Catalog.ToDictionary(delegate(TweakDefinition d) { return d.Id; }, StringComparer.Ordinal);
            Log = new LogService();
            Admin = new AdminService(Log);
            Engine = new TweakEngine(Log, Admin);
            Power = new PowerPresetService(Log, Admin);
            Cleaner = new CleanerService(Log, Admin);
        }

        public static List<TweakDefinition> FullCatalog()
        {
            if (TweakCatalog.All.Count != 228) throw new InvalidOperationException("The original 228-tweak backend is required. A reduced catalog is not supported.");
            var list = TweakCatalog.All.Concat(SupplementalCatalog.All).ToList();
            int expected = 228 + SupplementalCatalog.All.Count;
            if (list.Count != expected || list.Select(delegate(TweakDefinition d) { return d.Id; }).Distinct(StringComparer.Ordinal).Count() != expected)
                throw new InvalidOperationException("Catalog integrity check failed.");
            return list;
        }

        public async Task RefreshAsync()
        {
            Statuses.Clear();
            StatusErrors.Clear();
            StatusError = null;
            try
            {
                var original = await Engine.GetStatusesAsync(CancellationToken.None);
                foreach (var status in original) Statuses[status.Definition.Id] = status;
            }
            catch (Exception error) { StatusError = "Some original statuses could not be read: " + error.Message; }
            foreach (var definition in SupplementalCatalog.All)
            {
                try { Statuses[definition.Id] = SupplementalCatalog.ReadStatus(definition, Engine); }
                catch (Exception error) { StatusErrors[definition.Id] = error.Message; }
            }
        }

        public bool CanMutate() { return !ReadOnly; }
        public static bool RiskConfirmationRequired(TweakDefinition definition)
        {
            return definition.SecurityTradeOff || definition.Risk == TweakRisk.Medium || definition.Risk == TweakRisk.Major;
        }

        public async Task<TweakActionResult> ChangeTweakAsync(string id, bool restore, bool confirmed)
        {
            TweakDefinition definition;
            if (!ById.TryGetValue(id, out definition)) return new TweakActionResult(false, "Unknown tweak ID.", false, false);
            if (!CanMutate()) return new TweakActionResult(false, "Preview mode blocks all system changes and elevation.", false, false);
            if (!confirmed && RiskConfirmationRequired(definition) && !ConfirmDialog.Ask(null, restore ? "Restore tweak" : "Review tweak risk", TweakDetails(definition), restore ? "Restore original" : "Apply this tweak"))
                return new TweakActionResult(false, "Cancelled. Nothing changed.", false, false);
            if (definition.RequiresAdministrator && !Admin.IsAdministrator)
            {
                int exit = await ElevateAsync(new string[] { restore ? "--revert" : "--apply", definition.Id });
                return new TweakActionResult(exit == 0, exit == 0 ? "Elevated operation completed. Refreshing saved state." : "Elevated operation failed or was cancelled (exit " + exit + ").", false, definition.RequiresRestart && exit == 0);
            }
            MutationDispatches++;
            var result = restore ? await Engine.RevertAsync(definition, CancellationToken.None) : await Engine.ApplyAsync(definition, CancellationToken.None);
            if (result.RequiresElevation && !Admin.IsAdministrator)
            {
                int exit = await ElevateAsync(new string[] { restore ? "--revert" : "--apply", id });
                return new TweakActionResult(exit == 0, exit == 0 ? "Elevated operation completed." : "Elevation cancelled or operation failed (exit " + exit + ").", false, definition.RequiresRestart && exit == 0);
            }
            return result;
        }

        public async Task<string> RestoreAllAsync(bool confirmed)
        {
            RequireWritable();
            if (!confirmed && !ConfirmDialog.Ask(null, "Restore every saved tweak", "Restore saved supplemental snapshots first, then all original Astra snapshots. Settings with no backup are not reset. Power presets, game profiles and desktop wallpaper have separate restore controls.", "Restore saved tweaks"))
                throw new OperationCanceledException("Restore cancelled.");
            var backups = Engine.GetBackups();
            if (!Admin.IsAdministrator && backups.Any(delegate(TweakBackup backup)
            {
                TweakDefinition d;
                return !ById.TryGetValue(backup.TweakId, out d) || d.RequiresAdministrator;
            }))
            {
                int exit = await ElevateAsync(new string[] { "--restore-all" });
                if (exit != 0) throw new InvalidOperationException("Elevated restore failed or was cancelled (exit " + exit + ").");
                return "Elevated restore completed.";
            }
            var messages = new List<string>();
            // RevertAll resolves IDs through the original catalog, so supplemental backups must be reverted explicitly first.
            foreach (var definition in SupplementalCatalog.All)
            {
                if (!Engine.HasBackup(definition.Id)) continue;
                MutationDispatches++;
                var result = await Engine.RevertAsync(definition, CancellationToken.None);
                messages.Add(definition.Title + ": " + result.Message);
                if (!result.Success) throw new InvalidOperationException(String.Join("\n", messages));
            }
            MutationDispatches++;
            var originalResult = await Engine.RevertAllAsync(CancellationToken.None);
            messages.Add(originalResult.Message);
            if (!originalResult.Success || originalResult.RequiresElevation) throw new InvalidOperationException(String.Join("\n", messages));
            if (originalResult.RequiresRestart) messages.Add("Restart Windows to finish restoring affected settings.");
            return String.Join("\n", messages);
        }

        public async Task<string> ChangePowerAsync(string preset, bool restore, bool confirmed)
        {
            RequireWritable();
            PowerPresetKind kind = PowerPresetKind.Gaming;
            if (!restore && !TryPower(preset, out kind)) throw new ArgumentException("Unknown power preset.");
            if (!confirmed && !ConfirmDialog.Ask(null, restore ? "Restore previous power plan" : "Review power preset", restore ? "Restore the power plan saved by the original Astra power service." : PowerDetails(kind), restore ? "Restore power" : "Apply preset")) throw new OperationCanceledException("Cancelled.");
            if (!Admin.IsAdministrator)
            {
                int exit = await ElevateAsync(restore ? new string[] { "--restore-power" } : new string[] { "--power", kind.ToString() });
                if (exit != 0) throw new InvalidOperationException("Elevated power action failed or was cancelled (exit " + exit + ").");
                return "Elevated power action completed.";
            }
            MutationDispatches++;
            var result = restore ? await Power.RestoreAsync(CancellationToken.None) : await Power.ApplyAsync(kind, CancellationToken.None);
            if (!result.Success || result.RequiresElevation) throw new InvalidOperationException(result.Message);
            return result.Message;
        }

        public async Task<string> CleanAsync(CleanCategoryKind[] categories, bool confirmed)
        {
            RequireWritable();
            if (categories.Length == 0 || categories.Distinct().Count() != categories.Length || categories.Any(delegate(CleanCategoryKind c) { return !Enum.IsDefined(typeof(CleanCategoryKind), c); })) throw new ArgumentException("Select valid, distinct cleaner categories.");
            if (!confirmed && !ConfirmDialog.Ask(null, "Permanently delete selected caches", "Delete only: " + String.Join(", ", categories.Select(delegate(CleanCategoryKind c) { return c.ToString(); })) + ".\n\nClose applications first. Deleted files cannot be restored by Astra. Shader cache deletion can cause recompilation and temporary stutter. Locked files may be skipped.", "Delete selected files")) throw new OperationCanceledException("Cancelled.");
            if (!Admin.IsAdministrator && categories.Contains(CleanCategoryKind.WindowsTemp))
            {
                int exit = await ElevateAsync(new string[] { "--clean", String.Join(",", categories.Select(delegate(CleanCategoryKind c) { return c.ToString(); })) });
                if (exit != 0) throw new InvalidOperationException("Elevated cleanup failed or was cancelled (exit " + exit + ").");
                return "Elevated cleanup completed. Scan again for remaining files.";
            }
            MutationDispatches++;
            var result = await Cleaner.CleanAsync(categories, null, CancellationToken.None);
            if (PropertyFalse(result, "Success")) throw new InvalidOperationException(Describe(result));
            return Describe(result);
        }

        public async Task<string> WallpaperAsync(WallpaperEntry entry, bool restore, bool confirmed)
        {
            RequireWritable();
            if (!restore && (entry == null || !entry.Available)) throw new ArgumentException("Select an existing library wallpaper.");
            if (!confirmed && !ConfirmDialog.Ask(null, restore ? "Restore desktop wallpaper" : "Change desktop wallpaper", restore ? "Restore the desktop Wallpaper, WallpaperStyle and TileWallpaper values saved by the wallpaper helper." : "Set '" + entry.Title + "' as your Windows desktop wallpaper. Browsing this library never changes the desktop. Your previous desktop values are preserved by the wallpaper helper.", restore ? "Restore desktop" : "Apply wallpaper")) throw new OperationCanceledException("Cancelled.");
            MutationDispatches++;
            return await RunHelperAsync("Wallpaper.ps1", restore ? new string[] { "-Restore" } : new string[] { "-Image", entry.FullPath });
        }

        public async Task<string> GameAsync(string game, bool restore, bool confirmed)
        {
            RequireWritable();
            if (!Games.Contains(game, StringComparer.Ordinal)) throw new ArgumentException("Unknown game profile.");
            if (!confirmed && !ConfirmDialog.Ask(null, restore ? "Restore game profile" : "Review game profile", (restore ? "Restore the helper's saved profile for " : "Apply the AME helper's per-game profile for ") + game + ".\n\nThe helper detects installations and saves original GPU preferences / supported configuration values. Close the game first. Launch options are not automatically installed. No game or installation path is invented.", restore ? "Restore profile" : "Apply profile")) throw new OperationCanceledException("Cancelled.");
            MutationDispatches++;
            return await RunHelperAsync("GameProfiles.ps1", new string[] { "-" + game, "-Mode", restore ? "Off" : "On" });
        }

        public void RequireWritable()
        {
            if (!CanMutate()) throw new InvalidOperationException("Preview mode blocks all changes, helper execution and elevation.");
        }

        private async Task<int> ElevateAsync(string[] arguments, bool confirm = true)
        {
            RequireWritable();
            string launcher = Path.Combine(AppContext.BaseDirectory, "Astra-Toolbox.exe");
            if (!File.Exists(launcher)) throw new FileNotFoundException("The Astra-Toolbox.exe launcher is required for safe elevation.", launcher);
            if (confirm && !ConfirmDialog.Ask(null, "Administrator permission required", "Only the requested action will run elevated. The toolbox remains a normal-user application. Windows will show a UAC prompt next.", "Continue to UAC")) return 5;
            try
            {
                var info = new ProcessStartInfo(launcher, String.Join(" ", arguments.Select(QuoteArgument))) { UseShellExecute = true, Verb = "runas", WorkingDirectory = AppContext.BaseDirectory };
                using (var process = Process.Start(info))
                {
                    if (process == null) return 5;
                    await Task.Run(delegate { process.WaitForExit(); });
                    return process.ExitCode;
                }
            }
            catch (Win32Exception error)
            {
                if (error.NativeErrorCode == 1223) return 5;
                throw;
            }
        }

        private async Task<string> RunHelperAsync(string helper, string[] arguments)
        {
            RequireWritable();
            if (helper != "Wallpaper.ps1" && helper != "GameProfiles.ps1" && helper != "RestorePoint.ps1") throw new ArgumentException("Helper is not whitelisted.");
            string path = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", helper));
            if (!File.Exists(path)) throw new FileNotFoundException("The packaged helper is missing.", path);
            string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe");
            var info = new ProcessStartInfo(powershell, "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " + QuoteArgument(path) + " " + String.Join(" ", arguments.Select(QuoteArgument)))
            {
                UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true, WorkingDirectory = Path.GetDirectoryName(path)
            };
            if (helper == "RestorePoint.ps1") { info.StandardOutputEncoding = Encoding.UTF8; info.StandardErrorEncoding = Encoding.UTF8; }
            using (var process = Process.Start(info))
            {
                if (process == null) throw new InvalidOperationException("Could not start the packaged helper.");
                var output = process.StandardOutput.ReadToEndAsync();
                var errors = process.StandardError.ReadToEndAsync();
                await Task.Run(delegate { process.WaitForExit(); });
                string text = (await output).Trim();
                string error = (await errors).Trim();
                if (helper == "RestorePoint.ps1" && text.Length > 0)
                {
                    var response = JsonSerializer.Deserialize<RestorePointResponse>(text, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                    if (response == null) throw new InvalidDataException("Windows returned no readable restore-point result.");
                    if (process.ExitCode != 0 || !response.Success || !response.Created)
                        throw new InvalidOperationException(response.Message + (response.Issues.Count == 0 ? "" : "\n" + String.Join("\n", response.Issues)));
                    return response.Message + "\n" + response.Name + "  /  " + response.CreationTime;
                }
                if (process.ExitCode != 0) throw new InvalidOperationException("Helper failed (exit " + process.ExitCode + "): " + error + "\n" + text);
                if (helper == "RestorePoint.ps1") throw new InvalidDataException("Windows returned no restore-point verification. Creation is not confirmed.");
                return text.Length == 0 ? "Helper completed." : text;
            }
        }

        public static string QuoteArgument(string value)
        {
            if (value == null || value.IndexOf('\0') >= 0 || value.IndexOf('\r') >= 0 || value.IndexOf('\n') >= 0) throw new ArgumentException("Invalid process argument.");
            var builder = new StringBuilder("\"");
            int slashes = 0;
            foreach (char c in value)
            {
                if (c == '\\') { slashes++; continue; }
                if (c == '"') { builder.Append('\\', slashes * 2 + 1); builder.Append('"'); slashes = 0; continue; }
                builder.Append('\\', slashes); slashes = 0; builder.Append(c);
            }
            builder.Append('\\', slashes * 2); builder.Append('"');
            return builder.ToString();
        }

        public static bool TryPower(string name, out PowerPresetKind kind)
        {
            kind = PowerPresetKind.Gaming;
            return Enum.GetNames(typeof(PowerPresetKind)).Contains(name, StringComparer.Ordinal) && Enum.TryParse<PowerPresetKind>(name, false, out kind);
        }

        public static CleanCategoryKind[] ParseCategories(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) throw new ArgumentException("Missing cleaner categories.");
            var values = value.Split(',');
            var result = new List<CleanCategoryKind>();
            foreach (var name in values)
            {
                CleanCategoryKind category;
                if (!Enum.GetNames(typeof(CleanCategoryKind)).Contains(name, StringComparer.Ordinal) || !Enum.TryParse<CleanCategoryKind>(name, false, out category)) throw new ArgumentException("Unknown cleaner category: " + name);
                if (result.Contains(category)) throw new ArgumentException("Duplicate cleaner category.");
                result.Add(category);
            }
            return result.ToArray();
        }

        public static string TweakDetails(TweakDefinition d)
        {
            return d.Title + "\n\n" + d.Description + "\n\nRisk: " + d.Risk + (d.SecurityTradeOff ? " · SECURITY TRADE-OFF" : "") + (d.PerformanceUnproven ? " · Performance benefit unproven" : "") + "\n" + (d.RequiresAdministrator ? "Administrator permission required. " : "Current-user action. ") + (d.RequiresRestart ? "Restart Windows after applying/restoring.\n" : "\n") + (String.IsNullOrWhiteSpace(d.Caveat) ? "" : "Caveat: " + d.Caveat + "\n") + (String.IsNullOrWhiteSpace(d.Note) ? "" : "Note: " + d.Note + "\n") + "\nID: " + d.Id + "\nOriginal values are saved by Astra's snapshot engine. Restore requires a saved backup.";
        }

        public static string PowerDetails(PowerPresetKind kind)
        {
            var definition = PowerPresetCatalog.Get(kind);
            return definition.Title + "\n\n" + definition.Description + "\n\n" + String.Join("\n", definition.Highlights ?? new string[0]) + "\n\nPower presets modify the active plan and processor/device power settings. Higher-performance presets may increase power consumption, temperature and fan noise; no FPS gain is guaranteed. The original power service saves the previous plan for Restore.";
        }

        public static bool PropertyFalse(object value, string name)
        {
            if (value == null) return true;
            var property = value.GetType().GetProperty(name);
            return property != null && property.PropertyType == typeof(bool) && !(bool)property.GetValue(value, null);
        }

        public static string Describe(object value)
        {
            var lines = new List<string>();
            DescribeInto(value, "", 0, lines);
            return String.Join("\n", lines);
        }

        private static void DescribeInto(object value, string prefix, int depth, List<string> lines)
        {
            if (value == null || depth > 3 || lines.Count > 100) return;
            var type = value.GetType();
            if (value is string || type.IsPrimitive || type.IsEnum || value is decimal || value is DateTime) { lines.Add(prefix + Convert.ToString(value, CultureInfo.InvariantCulture)); return; }
            var enumerable = value as IEnumerable;
            if (enumerable != null) { foreach (var item in enumerable) DescribeInto(item, prefix, depth + 1, lines); return; }
            foreach (var property in type.GetProperties())
            {
                if (property.GetIndexParameters().Length != 0 || !property.CanRead) continue;
                try { DescribeInto(property.GetValue(value, null), prefix + property.Name + ": ", depth + 1, lines); }
                catch { }
            }
        }

        public static List<WallpaperEntry> LoadWallpapers()
        {
            string root = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "Wallpapers"));
            string manifest = Path.Combine(root, "catalog.json");
            if (!File.Exists(manifest)) throw new FileNotFoundException("Wallpaper library manifest is missing.", manifest);
            var entries = new List<WallpaperEntry>();
            var ids = new HashSet<string>(StringComparer.Ordinal);
            using (var document = JsonDocument.Parse(File.ReadAllText(manifest)))
            {
                if (document.RootElement.ValueKind != JsonValueKind.Array) throw new InvalidDataException("Wallpaper manifest must be an array.");
                foreach (var item in document.RootElement.EnumerateArray())
                {
                    string id = item.GetProperty("id").GetString();
                    string title = item.GetProperty("title").GetString();
                    string file = item.GetProperty("file").GetString();
                    if (String.IsNullOrWhiteSpace(id) || String.IsNullOrWhiteSpace(title) || String.IsNullOrWhiteSpace(file) || !ids.Add(id) || Path.IsPathRooted(file)) throw new InvalidDataException("Invalid or duplicate wallpaper entry.");
                    string path = Path.GetFullPath(Path.Combine(root, file));
                    string extension = Path.GetExtension(path).ToLowerInvariant();
                    if (!path.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || (extension != ".png" && extension != ".jpg" && extension != ".jpeg" && extension != ".bmp")) throw new InvalidDataException("Wallpaper path must remain in the library and use a supported image format.");
                    entries.Add(new WallpaperEntry { Id = id, Title = title, File = file, FullPath = path });
                }
            }
            return entries;
        }
    }

    internal sealed class TweakRow
    {
        public TweakDefinition Definition { get; private set; }
        public string Id { get { return Definition.Id; } }
        public string Title { get { return Definition.Title; } }
        public string Description { get { return Definition.Description; } }
        public string Caveat { get { return String.IsNullOrWhiteSpace(Definition.Caveat) ? Definition.Note ?? "" : "Caveat: " + Definition.Caveat + (String.IsNullOrWhiteSpace(Definition.Note) ? "" : "\n" + Definition.Note); } }
        public string Metadata { get { return Definition.Category + "  ·  " + Definition.Risk + (Definition.RequiresAdministrator ? "  ·  Admin" : "  ·  User") + (Definition.RequiresRestart ? "  ·  Restart Windows" : "") + (Definition.SecurityTradeOff ? "  ·  Security trade-off" : "") + (Definition.PerformanceUnproven ? "  ·  Benefit unproven" : ""); } }
        public string State { get; private set; }
        public bool HasBackup { get; private set; }
        public bool CanApply { get; private set; }
        public bool CanRestore { get; private set; }
        public TweakRow(TweakDefinition definition, ToolboxSession session)
        {
            Definition = definition;
            TweakStatus status;
            bool known = session.Statuses.TryGetValue(definition.Id, out status);
            HasBackup = known ? status.HasBackup : session.Engine.HasBackup(definition.Id);
            State = (known ? (status.IsApplied ? "Applied" : "Not applied") : "Status unknown") + (HasBackup ? "  ·  Backup saved" : "  ·  No backup");
            CanApply = !session.ReadOnly;
            CanRestore = !session.ReadOnly && HasBackup;
        }
    }

    internal sealed class ConfirmDialog : Window
    {
        public readonly Button Accept;
        public readonly Button Cancel;
        public readonly TextBlock Details;
        public ConfirmDialog(string title, string details, string action)
        {
            Title = "Astra Toolbox · " + title;
            Width = 580; MaxHeight = 700; SizeToContent = SizeToContent.Height; ResizeMode = ResizeMode.NoResize;
            WindowStartupLocation = WindowStartupLocation.CenterOwner;
            Theme.Apply(this);
            var panel = new StackPanel { Margin = new Thickness(28) };
            var label = Theme.Text("REVIEW BEFORE CHANGING", 10, Theme.Accent, FontWeights.SemiBold); label.Margin = new Thickness(0, 0, 0, 10); panel.Children.Add(label);
            panel.Children.Add(Theme.Text(title, 25, Theme.Ink, FontWeights.SemiBold));
            Details = Theme.Text(details, 14, Theme.Secondary, FontWeights.Normal); Details.Margin = new Thickness(0, 0, 8, 0);
            var detailsCard = Theme.Card(new ScrollViewer { Content = Details, MaxHeight = 410, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled });
            detailsCard.Margin = new Thickness(0, 20, 0, 18); detailsCard.Padding = new Thickness(18); panel.Children.Add(detailsCard);
            var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
            Cancel = Theme.Button("Cancel", false); Cancel.IsCancel = true; Cancel.IsDefault = true;
            Cancel.Click += delegate { DialogResult = false; };
            Accept = Theme.Button(action, true); Accept.Click += delegate { DialogResult = true; };
            buttons.Children.Add(Cancel); buttons.Children.Add(Accept); panel.Children.Add(buttons); Content = Theme.Stage(panel);
        }
        public static bool Ask(Window owner, string title, string details, string action)
        {
            var dialog = new ConfirmDialog(title, details, action);
            var candidate = owner ?? (Application.Current == null ? null : Application.Current.MainWindow);
            if (candidate != null && candidate.IsVisible) dialog.Owner = candidate;
            return dialog.ShowDialog() == true;
        }
    }

    internal static class Theme
    {
        public const string Background = "#B7C8D9";
        public const string Sidebar = "#A8D8E5EF";
        public const string Surface = "#B8E6EFF7";
        public const string Ink = "#172D46";
        public const string Secondary = "#455E77";
        public const string Accent = "#465DA8";
        public const string Blue = "#216BA6";
        public const string Line = "#B5FFFFFF";
        public const string White = "#FFFFFF";
        public const string Warning = "#80501F";
        public const string Error = "#963E42";
        public const string Success = "#1B626D";
        public static readonly FontFamily Font = new FontFamily("Segoe UI Variable, Segoe UI, Arial");

        public static SolidColorBrush Brush(string color)
        {
            var brush = new SolidColorBrush((Color)ColorConverter.ConvertFromString(color)); brush.Freeze(); return brush;
        }
        public static TextBlock Text(string text, double size, string color, FontWeight weight)
        {
            return new TextBlock { Text = text ?? "", FontSize = size, Foreground = Brush(color), FontFamily = Font, FontWeight = weight, TextWrapping = TextWrapping.Wrap };
        }
        public static void Apply(Window window)
        {
            window.Background = Brush(Background); window.Foreground = Brush(Ink); window.FontFamily = Font;
            window.UseLayoutRounding = true; window.SnapsToDevicePixels = true;
            TextOptions.SetTextFormattingMode(window, TextFormattingMode.Display);
            window.Resources.MergedDictionaries.Add(ControlResources());
            window.SourceInitialized += delegate
            {
                TryNativeSurface(window);
                var source = HwndSource.FromHwnd(new WindowInteropHelper(window).Handle);
                if (source == null) return;
                HwndSourceHook hook = delegate(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
                {
                    if (message == 0x001A || message == 0x031A || message == 0x031E)
                        window.Dispatcher.BeginInvoke(new Action(delegate { if (window.IsVisible) TryNativeSurface(window); }));
                    return IntPtr.Zero;
                };
                source.AddHook(hook);
                window.Closed += delegate { source.RemoveHook(hook); };
            };
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct FrameMargins { public int Left, Right, Top, Bottom; }
        [DllImport("dwmapi.dll", PreserveSig = true)]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
        [DllImport("dwmapi.dll", PreserveSig = true)]
        private static extern int DwmExtendFrameIntoClientArea(IntPtr hwnd, ref FrameMargins margins);

        private static bool TransparencyAllowed()
        {
            if (SystemParameters.HighContrast || (RenderCapability.Tier >> 16) == 0) return false;
            try
            {
                using (var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"))
                    return key == null || Convert.ToInt32(key.GetValue("EnableTransparency", 1), CultureInfo.InvariantCulture) != 0;
            }
            catch { return false; }
        }

        private static void TryNativeSurface(Window window)
        {
            IntPtr handle = new WindowInteropHelper(window).Handle;
            var source = HwndSource.FromHwnd(handle);
            bool acrylic = false;
            if (OperatingSystem.IsWindowsVersionAtLeast(10, 0, 22000))
            {
                try
                {
                    int light = 0, rounded = 2, caption = 0x00D9C8B7, text = 0x00462D17;
                    DwmSetWindowAttribute(handle, 20, ref light, sizeof(int));
                    DwmSetWindowAttribute(handle, 33, ref rounded, sizeof(int));
                    DwmSetWindowAttribute(handle, 35, ref caption, sizeof(int));
                    DwmSetWindowAttribute(handle, 36, ref text, sizeof(int));
                    if (OperatingSystem.IsWindowsVersionAtLeast(10, 0, 22621))
                    {
                        int backdrop = TransparencyAllowed() ? 3 : 1;
                        acrylic = backdrop == 3 && DwmSetWindowAttribute(handle, 38, ref backdrop, sizeof(int)) == 0;
                        // DWM needs an alpha client, not a layered window; the native caption stays intact.
                        var margins = new FrameMargins { Left = acrylic ? -1 : 0, Right = acrylic ? -1 : 0, Top = acrylic ? -1 : 0, Bottom = acrylic ? -1 : 0 };
                        if (DwmExtendFrameIntoClientArea(handle, ref margins) != 0)
                        {
                            acrylic = false; backdrop = 1;
                            DwmSetWindowAttribute(handle, 38, ref backdrop, sizeof(int));
                        }
                    }
                }
                catch (DllNotFoundException) { }
                catch (EntryPointNotFoundException) { }
            }
            window.Background = acrylic ? Brushes.Transparent : Brush(Background);
            if (source != null && source.CompositionTarget != null)
                source.CompositionTarget.BackgroundColor = acrylic ? Colors.Transparent : Brush(Background).Color;
        }

        public static LinearGradientBrush Frost(string tint = Surface)
        {
            var brush = new LinearGradientBrush { StartPoint = new Point(0, 0), EndPoint = new Point(0.65, 1) };
            brush.GradientStops.Add(new GradientStop(Brush("#CFF3F9FF").Color, 0));
            brush.GradientStops.Add(new GradientStop(Brush(tint).Color, 0.42));
            brush.GradientStops.Add(new GradientStop(Brush("#8AC7D9EB").Color, 1));
            brush.Freeze(); return brush;
        }
        public static LinearGradientBrush Rim()
        {
            var brush = new LinearGradientBrush { StartPoint = new Point(0, 0), EndPoint = new Point(0.6, 1) };
            brush.GradientStops.Add(new GradientStop(Brush("#FAFFFFFF").Color, 0));
            brush.GradientStops.Add(new GradientStop(Brush("#BEE9F9FF").Color, 0.45));
            brush.GradientStops.Add(new GradientStop(Brush("#707B9BB9").Color, 0.72));
            brush.GradientStops.Add(new GradientStop(Brush("#D0E8F9FF").Color, 1));
            brush.Freeze(); return brush;
        }
        public static Border Glass(UIElement child, Thickness padding, double radius = 16, bool depth = true)
        {
            return new Border { Child = child, Background = Frost(), BorderBrush = Rim(), BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(radius), Padding = padding,
                Effect = depth && !SystemParameters.HighContrast && (RenderCapability.Tier >> 16) > 0 ? new DropShadowEffect { Color = Color.FromRgb(43, 68, 100), BlurRadius = 16, ShadowDepth = 4, Opacity = 0.12, RenderingBias = RenderingBias.Performance } : null };
        }
        public static Grid Stage(UIElement child)
        {
            var stage = new Grid { ClipToBounds = true };
            var wash = new LinearGradientBrush { StartPoint = new Point(0, 0), EndPoint = new Point(1, 1) };
            wash.GradientStops.Add(new GradientStop(Brush("#95DDEBF5").Color, 0));
            wash.GradientStops.Add(new GradientStop(Brush("#60A8BBD3").Color, 0.5));
            wash.GradientStops.Add(new GradientStop(Brush("#90B5C8DF").Color, 1));
            wash.Freeze(); stage.Background = wash;
            var drawing = new DrawingGroup();
            var glow = new RadialGradientBrush(Brush("#70F3FCFF").Color, Colors.Transparent) { Center = new Point(0.4, 0.35), GradientOrigin = new Point(0.4, 0.35) }; glow.Freeze();
            drawing.Children.Add(new GeometryDrawing(glow, null, new EllipseGeometry(new Point(260, 150), 470, 340)));
            var violet = new RadialGradientBrush(Brush("#38918FCC").Color, Colors.Transparent); violet.Freeze();
            drawing.Children.Add(new GeometryDrawing(violet, null, new EllipseGeometry(new Point(1060, 630), 420, 360)));
            AddRibbon(drawing, "M -130,520 C 170,170 320,710 650,450 C 930,230 1080,300 1320,-60", "#30466EBC", "#75D9F7FF", 19);
            AddRibbon(drawing, "M 90,-80 C 380,60 380,330 760,180 C 1060,40 940,640 1350,580", "#277B70AE", "#60E6E0FF", 12);
            drawing.Freeze();
            var decoration = new System.Windows.Shapes.Rectangle { Fill = new DrawingBrush(drawing) { Stretch = Stretch.Fill }, IsHitTestVisible = false, Focusable = false };
            Panel.SetZIndex(decoration, -1); stage.Children.Add(decoration); stage.Children.Add(child); return stage;
        }
        private static void AddRibbon(DrawingGroup drawing, string path, string shade, string light, double width)
        {
            var geometry = Geometry.Parse(path); geometry.Freeze();
            var material = new LinearGradientBrush(Brush(shade).Color, Brush(light).Color, 90); material.Freeze();
            var pen = new Pen(material, width) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round }; pen.Freeze();
            drawing.Children.Add(new GeometryDrawing(null, pen, geometry));
            var highlight = new Pen(Brush("#65F1FBFF"), 1.5); highlight.Freeze();
            drawing.Children.Add(new GeometryDrawing(null, highlight, geometry));
        }

        private static ResourceDictionary ControlResources()
        {
            return (ResourceDictionary)XamlReader.Parse("""
                <ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
                  <LinearGradientBrush x:Key="FieldGlass" StartPoint="0,0" EndPoint="0,1">
                    <GradientStop Color="#D9F6FBFF" Offset="0"/><GradientStop Color="#ABE0EBF5" Offset="0.45"/><GradientStop Color="#B8D0E1F1" Offset="1"/>
                  </LinearGradientBrush>
                  <LinearGradientBrush x:Key="GlassRim" StartPoint="0,0" EndPoint="0.6,1">
                    <GradientStop Color="#FAFFFFFF" Offset="0"/><GradientStop Color="#BEE9F9FF" Offset="0.45"/><GradientStop Color="#707B9BB9" Offset="0.72"/><GradientStop Color="#D0E8F9FF" Offset="1"/>
                  </LinearGradientBrush>
                  <LinearGradientBrush x:Key="PopupGlass" StartPoint="0,0" EndPoint="0.5,1">
                    <GradientStop Color="#F6F4FAFF" Offset="0"/><GradientStop Color="#F6DCE8F5" Offset="1"/>
                  </LinearGradientBrush>
                  <Style TargetType="ToolTip">
                    <Setter Property="Background" Value="{StaticResource PopupGlass}"/><Setter Property="Foreground" Value="#172D46"/>
                    <Setter Property="BorderBrush" Value="{StaticResource GlassRim}"/><Setter Property="Padding" Value="12,8"/>
                    <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ToolTip">
                      <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="9" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border>
                    </ControlTemplate></Setter.Value></Setter>
                  </Style>
                  <Style x:Key="ScrollThumb" TargetType="Thumb">
                    <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Thumb">
                      <Border x:Name="Grip" Background="#879EB8" BorderBrush="#70F1FBFF" BorderThickness="0,1,0,0" CornerRadius="4" Margin="2"/>
                      <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Grip" Property="Background" Value="#506F92"/></Trigger><Trigger Property="IsDragging" Value="True"><Setter TargetName="Grip" Property="Background" Value="#216BA6"/></Trigger></ControlTemplate.Triggers>
                    </ControlTemplate></Setter.Value></Setter>
                  </Style>
                  <Style x:Key="ScrollPage" TargetType="RepeatButton">
                    <Setter Property="Focusable" Value="False"/>
                    <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate></Setter.Value></Setter>
                  </Style>
                  <Style TargetType="ScrollBar">
                    <Setter Property="Width" Value="10"/><Setter Property="MinWidth" Value="0"/><Setter Property="Background" Value="Transparent"/>
                    <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar">
                      <Grid Background="Transparent">
                        <Track x:Name="PART_Track" Orientation="{TemplateBinding Orientation}" IsDirectionReversed="True">
                          <Track.DecreaseRepeatButton><RepeatButton Style="{StaticResource ScrollPage}" Command="{x:Static ScrollBar.PageUpCommand}"/></Track.DecreaseRepeatButton>
                          <Track.Thumb><Thumb Style="{StaticResource ScrollThumb}" MinHeight="28"/></Track.Thumb>
                          <Track.IncreaseRepeatButton><RepeatButton Style="{StaticResource ScrollPage}" Command="{x:Static ScrollBar.PageDownCommand}"/></Track.IncreaseRepeatButton>
                        </Track>
                      </Grid>
                    </ControlTemplate></Setter.Value></Setter>
                    <Style.Triggers><Trigger Property="Orientation" Value="Horizontal">
                      <Setter Property="Width" Value="Auto"/><Setter Property="Height" Value="10"/>
                      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar">
                        <Track x:Name="PART_Track" Orientation="Horizontal" IsDirectionReversed="False">
                          <Track.DecreaseRepeatButton><RepeatButton Style="{StaticResource ScrollPage}" Command="{x:Static ScrollBar.PageLeftCommand}"/></Track.DecreaseRepeatButton>
                          <Track.Thumb><Thumb Style="{StaticResource ScrollThumb}" MinWidth="28"/></Track.Thumb>
                          <Track.IncreaseRepeatButton><RepeatButton Style="{StaticResource ScrollPage}" Command="{x:Static ScrollBar.PageRightCommand}"/></Track.IncreaseRepeatButton>
                        </Track>
                      </ControlTemplate></Setter.Value></Setter>
                    </Trigger></Style.Triggers>
                  </Style>
                  <Style x:Key="TweakItem" TargetType="ListBoxItem">
                    <Setter Property="HorizontalContentAlignment" Value="Stretch"/><Setter Property="Padding" Value="0"/>
                    <Setter Property="Background" Value="Transparent"/><Setter Property="BorderThickness" Value="0"/>
                    <Setter Property="Focusable" Value="False"/>
                    <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem"><ContentPresenter HorizontalAlignment="Stretch"/></ControlTemplate></Setter.Value></Setter>
                  </Style>
                  <Style TargetType="TextBox">
                    <Setter Property="Background" Value="{StaticResource FieldGlass}"/><Setter Property="Foreground" Value="#172D46"/>
                    <Setter Property="BorderBrush" Value="{StaticResource GlassRim}"/><Setter Property="BorderThickness" Value="1"/>
                    <Setter Property="CaretBrush" Value="#216BA6"/><Setter Property="SelectionBrush" Value="#8DAACBE8"/>
                    <Setter Property="Padding" Value="12,9"/><Setter Property="VerticalContentAlignment" Value="Center"/>
                    <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TextBox">
                      <Border x:Name="Field" CornerRadius="9" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
                        <Grid>
                          <Border BorderBrush="#50FFFFFF" BorderThickness="1,1,0,0" CornerRadius="8" Margin="1" IsHitTestVisible="False"/>
                          <TextBlock x:Name="Hint" Text="{TemplateBinding Tag}" Foreground="#455E77" Margin="{TemplateBinding Padding}" IsHitTestVisible="False" Visibility="Collapsed" VerticalAlignment="Center"/>
                          <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"/>
                        </Grid>
                      </Border>
                      <ControlTemplate.Triggers>
                        <Trigger Property="Text" Value=""><Setter TargetName="Hint" Property="Visibility" Value="Visible"/></Trigger>
                        <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Field" Property="BorderBrush" Value="#7D9BB9"/></Trigger>
                        <Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter TargetName="Field" Property="BorderBrush" Value="#216BA6"/><Setter TargetName="Field" Property="Background" Value="#E6F2F9FF"/></Trigger>
                        <Trigger Property="IsReadOnly" Value="True"><Setter TargetName="Field" Property="Background" Value="#8CBFCFDF"/></Trigger>
                        <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Field" Property="Opacity" Value="0.48"/></Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate></Setter.Value></Setter>
                  </Style>
                  <Style TargetType="ComboBoxItem">
                    <Setter Property="Padding" Value="12,9"/><Setter Property="Foreground" Value="#172D46"/>
                    <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                    <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBoxItem">
                      <Border x:Name="Item" Background="Transparent" BorderBrush="Transparent" BorderThickness="1" CornerRadius="6" Margin="3,1" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsSelected" Value="True"><Setter TargetName="Item" Property="Background" Value="#BCD1E3F4"/><Setter TargetName="Item" Property="BorderBrush" Value="#8198BC"/></Trigger>
                        <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Item" Property="Background" Value="#DFF3FAFF"/><Setter TargetName="Item" Property="BorderBrush" Value="#216BA6"/></Trigger>
                        <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.48"/></Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate></Setter.Value></Setter>
                  </Style>
                  <Style TargetType="ComboBox">
                    <Setter Property="Background" Value="{StaticResource FieldGlass}"/><Setter Property="Foreground" Value="#172D46"/>
                    <Setter Property="BorderBrush" Value="{StaticResource GlassRim}"/><Setter Property="BorderThickness" Value="1"/>
                    <Setter Property="Padding" Value="12,8"/><Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Disabled"/>
                    <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBox">
                      <Grid>
                        <ToggleButton x:Name="Drop" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" Focusable="False" IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}" ClickMode="Press">
                          <ToggleButton.Template><ControlTemplate TargetType="ToggleButton">
                            <Border x:Name="Field" CornerRadius="9" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1">
                              <Grid><Border BorderBrush="#50FFFFFF" BorderThickness="1,1,0,0" CornerRadius="8" Margin="1"/>
                                <Path Data="M 0,0 L 4,4 L 8,0" Stroke="#455E77" StrokeThickness="1.5" Width="8" Height="4" HorizontalAlignment="Right" Margin="0,0,13,0"/>
                              </Grid>
                            </Border>
                            <ControlTemplate.Triggers>
                              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Field" Property="BorderBrush" Value="#7D9BB9"/></Trigger>
                              <Trigger Property="IsChecked" Value="True"><Setter TargetName="Field" Property="BorderBrush" Value="#216BA6"/><Setter TargetName="Field" Property="Background" Value="#D9F1F8FF"/></Trigger>
                            </ControlTemplate.Triggers>
                          </ControlTemplate></ToggleButton.Template>
                        </ToggleButton>
                        <ContentPresenter Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}" Margin="12,0,30,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
                        <Border x:Name="FocusRing" CornerRadius="9" BorderThickness="2" BorderBrush="Transparent" IsHitTestVisible="False"/>
                        <Popup x:Name="PART_Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="None">
                          <Border Background="{StaticResource PopupGlass}" BorderBrush="{StaticResource GlassRim}" BorderThickness="1" CornerRadius="9" Padding="4" Margin="3,6,3,8" MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                            <Border.Effect><DropShadowEffect Color="#2B4464" BlurRadius="10" ShadowDepth="3" Opacity="0.16" RenderingBias="Performance"/></Border.Effect>
                            <ScrollViewer CanContentScroll="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/></ScrollViewer>
                          </Border>
                        </Popup>
                      </Grid>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter TargetName="FocusRing" Property="BorderBrush" Value="#216BA6"/></Trigger>
                        <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.48"/></Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate></Setter.Value></Setter>
                  </Style>
                  <Style TargetType="CheckBox">
                    <Setter Property="Foreground" Value="#172D46"/><Setter Property="Cursor" Value="Hand"/>
                    <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="CheckBox">
                      <Grid Background="Transparent"><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition/></Grid.ColumnDefinitions>
                        <Border x:Name="Box" Width="20" Height="20" CornerRadius="5" Background="{StaticResource FieldGlass}" BorderBrush="#809AB6" BorderThickness="1" VerticalAlignment="Center">
                          <Grid><Path x:Name="Tick" Data="M 0,4 L 3,7 L 9,0" Stroke="#FFFFFF" StrokeThickness="1.8" Width="9" Height="7" Visibility="Collapsed"/>
                            <Border x:Name="Mixed" Width="9" Height="2" Background="#FFFFFF" Visibility="Collapsed"/>
                          </Grid>
                        </Border>
                        <Border x:Name="CheckFocus" Width="26" Height="26" CornerRadius="7" BorderThickness="2" BorderBrush="Transparent" IsHitTestVisible="False"/>
                        <ContentPresenter Grid.Column="1" Margin="11,0,0,0" VerticalAlignment="Center" RecognizesAccessKey="True"/>
                      </Grid>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="#216BA6"/></Trigger>
                        <Trigger Property="IsChecked" Value="True"><Setter TargetName="Box" Property="Background" Value="#465DA8"/><Setter TargetName="Box" Property="BorderBrush" Value="#465DA8"/><Setter TargetName="Tick" Property="Visibility" Value="Visible"/></Trigger>
                        <Trigger Property="IsChecked" Value="{x:Null}"><Setter TargetName="Box" Property="Background" Value="#465DA8"/><Setter TargetName="Mixed" Property="Visibility" Value="Visible"/></Trigger>
                        <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="CheckFocus" Property="BorderBrush" Value="#216BA6"/></Trigger>
                        <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.48"/></Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate></Setter.Value></Setter>
                  </Style>
                  <Style TargetType="Expander">
                    <Setter Property="Foreground" Value="#172D46"/>
                    <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Expander">
                      <StackPanel>
                        <ToggleButton IsChecked="{Binding IsExpanded, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}" Content="{TemplateBinding Header}" HorizontalContentAlignment="Left" Cursor="Hand">
                          <ToggleButton.Template><ControlTemplate TargetType="ToggleButton">
                            <Border x:Name="HeaderGlass" Background="#20F3FAFF" BorderBrush="Transparent" BorderThickness="1" CornerRadius="7" Padding="7,8"><DockPanel>
                              <TextBlock x:Name="Arrow" Text="›" FontSize="22" Foreground="#465DA8" Width="24" RenderTransformOrigin="0.5,0.5"/>
                              <ContentPresenter VerticalAlignment="Center" RecognizesAccessKey="True"/>
                            </DockPanel></Border>
                            <ControlTemplate.Triggers>
                              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="HeaderGlass" Property="Background" Value="#70F3FAFF"/><Setter TargetName="HeaderGlass" Property="BorderBrush" Value="#A0FFFFFF"/></Trigger>
                              <Trigger Property="IsChecked" Value="True"><Setter TargetName="Arrow" Property="RenderTransform"><Setter.Value><RotateTransform Angle="90"/></Setter.Value></Setter><Setter TargetName="HeaderGlass" Property="Background" Value="#50D0E6F8"/></Trigger>
                              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="HeaderGlass" Property="BorderBrush" Value="#216BA6"/></Trigger>
                            </ControlTemplate.Triggers>
                          </ControlTemplate></ToggleButton.Template>
                        </ToggleButton>
                        <ContentPresenter x:Name="Body" ContentSource="Content" Visibility="Collapsed" Margin="0,12,0,0"/>
                      </StackPanel>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsExpanded" Value="True"><Setter TargetName="Body" Property="Visibility" Value="Visible"/></Trigger>
                        <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.48"/></Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate></Setter.Value></Setter>
                  </Style>
                </ResourceDictionary>
                """);
        }

        public static Brush ButtonFill(bool primary)
        {
            if (!primary) return Frost();
            var brush = new LinearGradientBrush(Brush("#3F5794").Color, Brush("#31447D").Color, 90); brush.Freeze(); return brush;
        }
        public static Button Button(string text, bool primary)
        {
            var button = new Button { Content = text, Padding = new Thickness(17, 10, 17, 10), Margin = new Thickness(0, 4, 8, 4), Cursor = Cursors.Hand, FontSize = 13, FontFamily = Font, HorizontalContentAlignment = HorizontalAlignment.Center, VerticalContentAlignment = VerticalAlignment.Center, FontWeight = FontWeights.SemiBold, Background = ButtonFill(primary), Foreground = Brush(primary ? White : Ink), BorderBrush = primary ? Brush("#97BDE6FF") : Rim(), BorderThickness = new Thickness(1), MinHeight = 40 };
            button.Tag = primary ? "PrimaryAction" : null; button.Template = ButtonTemplate(); AutomationProperties.SetName(button, text); return button;
        }
        private static ControlTemplate buttonTemplate;
        public static ControlTemplate ButtonTemplate()
        {
            return buttonTemplate ??= (ControlTemplate)XamlReader.Parse("""
                <ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
                  <Border x:Name="ButtonBorder" CornerRadius="9" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
                    <Grid>
                      <Border x:Name="Sheen" CornerRadius="8" BorderBrush="#40FFFFFF" BorderThickness="0,1,0,0" Margin="1" IsHitTestVisible="False"/>
                      <ContentPresenter Margin="{TemplateBinding Padding}" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="{TemplateBinding VerticalContentAlignment}" RecognizesAccessKey="True"/>
                      <Border x:Name="NavigationMarker" Width="3" CornerRadius="2" Background="#216BA6" HorizontalAlignment="Left" Margin="2,10,0,10" Visibility="Collapsed" IsHitTestVisible="False"/>
                      <Border x:Name="KeyboardRing" CornerRadius="8" BorderBrush="Transparent" BorderThickness="2" IsHitTestVisible="False"/>
                    </Grid>
                  </Border>
                  <ControlTemplate.Triggers>
                    <Trigger Property="Tag" Value="CurrentNavigation"><Setter TargetName="NavigationMarker" Property="Visibility" Value="Visible"/></Trigger>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Sheen" Property="Background" Value="#28FFFFFF"/><Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#E8FFFFFF"/></Trigger>
                    <Trigger Property="IsPressed" Value="True"><Setter TargetName="Sheen" Property="Background" Value="#20304970"/><Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#7394B5"/></Trigger>
                    <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="KeyboardRing" Property="BorderBrush" Value="#216BA6"/><Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#E8FFFFFF"/></Trigger>
                    <MultiTrigger><MultiTrigger.Conditions><Condition Property="Tag" Value="PrimaryAction"/><Condition Property="IsKeyboardFocused" Value="True"/></MultiTrigger.Conditions><Setter TargetName="KeyboardRing" Property="BorderBrush" Value="#FFFFFF"/></MultiTrigger>
                    <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.48"/></Trigger>
                  </ControlTemplate.Triggers>
                </ControlTemplate>
                """);
        }
        public static Border Card(UIElement child)
        {
            var card = Glass(child, new Thickness(22)); card.Margin = new Thickness(0, 0, 0, 16); return card;
        }
        public static BitmapImage Image(string path, int decodeWidth)
        {
            if (!File.Exists(path)) return null;
            try
            {
                var image = new BitmapImage(); image.BeginInit(); image.CacheOption = BitmapCacheOption.OnLoad; image.UriSource = new Uri(Path.GetFullPath(path));
                if (decodeWidth > 0) image.DecodePixelWidth = decodeWidth;
                image.EndInit(); image.Freeze(); return image;
            }
            catch { return null; }
        }
    }

    internal sealed partial class ToolboxWindow : Window
    {
        private readonly ToolboxSession session;
        private readonly Options options;
        private readonly ContentControl content = new ContentControl();
        private readonly Dictionary<string, Button> navigation = new Dictionary<string, Button>(StringComparer.Ordinal);
        private readonly TextBlock notification = Theme.Text("No changes run on startup. Choose a setting to review it.", 12, Theme.Secondary, FontWeights.Normal);
        private readonly TextBlock sectionLabel = Theme.Text("Overview", 13, Theme.Ink, FontWeights.SemiBold);
        private readonly TextBlock mode;
        private bool busy;
        private bool loaded;
        private string page;
        private TextBox search;
        private ComboBox category;
        private ComboBox collection;
        private ComboBox statusFilter;
        private ListBox tweaks;
        private TextBlock results;
        private TextBlock empty;
        private List<WallpaperEntry> wallpapers = new List<WallpaperEntry>();
        private string wallpaperError;
        private WallpaperEntry selectedWallpaper;
        private Image wallpaperPreview;
        private TextBlock wallpaperTitle;
        private Button wallpaperApply;
        private readonly Dictionary<string, Button> wallpaperButtons = new Dictionary<string, Button>(StringComparer.Ordinal);
        private readonly Dictionary<CleanCategoryKind, CheckBox> cleanSelection = new Dictionary<CleanCategoryKind, CheckBox>();
        private bool cleanerScanned;
        private string lastCleanScan = "Scan first to read actual cache findings. No files are selected by default.";
        private string powerStatus = "Active plan has not been read yet.";

        public ToolboxWindow(ToolboxSession state, Options arguments)
        {
            session = state; options = arguments;
            Title = "Astra Toolbox"; Width = 1160; Height = 800; MinWidth = 900; MinHeight = 650;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Theme.Apply(this);
            var icon = Theme.Image(Path.Combine(AppContext.BaseDirectory, "Assets", "gojo-icon.png"), 96); if (icon != null) Icon = icon;
            mode = Theme.Text(session.ReadOnly ? "Preview · read only" : (session.Admin.IsAdministrator ? "Elevated session" : "Standard user"), 11, Theme.Accent, FontWeights.SemiBold);
            try { wallpapers = ToolboxSession.LoadWallpapers(); }
            catch (Exception error) { wallpaperError = error.Message; }
            BuildShell(icon);
            Navigate("Overview");
            Closing += delegate(object sender, CancelEventArgs e)
            {
                if (busy) { e.Cancel = true; Notify("Wait for the requested operation to finish before closing.", false); }
            };
            Closed += delegate { session.CancelSystemRead(); };
            Loaded += async delegate
            {
                if (loaded) return; loaded = true;
                if (options.Command == "self-test")
                {
                    try { await SelfTestAsync(options.Value); Application.Current.Shutdown(0); }
                    catch (Exception error)
                    {
                        File.WriteAllText(Path.Combine(options.Value, "self-test-errors.txt"), error.ToString());
                        Console.Error.WriteLine(error); Application.Current.Shutdown(1);
                    }
                    return;
                }
                await RefreshReadOnlyAsync();
            };
        }

        private void BuildShell(BitmapImage avatar)
        {
            var shell = new Grid { Margin = new Thickness(12) };
            shell.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(204) }); shell.ColumnDefinitions.Add(new ColumnDefinition());
            var rail = new DockPanel { Margin = new Thickness(14, 20, 14, 16) };
            var brand = new Grid { Margin = new Thickness(5, 0, 0, 25) };
            brand.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto }); brand.ColumnDefinitions.Add(new ColumnDefinition());
            var badge = Theme.Glass(null, new Thickness(0), 12, false); badge.Width = 43; badge.Height = 43; badge.ClipToBounds = true;
            if (avatar != null)
            {
                badge.Child = new Image { Source = avatar, Stretch = Stretch.UniformToFill };
                badge.Clip = new RectangleGeometry(new Rect(0, 0, 43, 43), 14, 14);
            }
            else badge.Child = Theme.Text("A", 30, Theme.Accent, FontWeights.Bold);
            brand.Children.Add(badge);
            var wordmark = new StackPanel { Margin = new Thickness(11, 1, 0, 0), VerticalAlignment = VerticalAlignment.Center };
            wordmark.Children.Add(Theme.Text("Astra", 22, Theme.Ink, FontWeights.SemiBold));
            wordmark.Children.Add(Theme.Text("Gojo toolbox", 10, Theme.Secondary, FontWeights.Normal)); Grid.SetColumn(wordmark, 1); brand.Children.Add(wordmark);
            DockPanel.SetDock(brand, Dock.Top); rail.Children.Add(brand);
            var footer = new StackPanel { Margin = new Thickness(8, 17, 0, 0) };
            footer.Children.Add(mode);
            var inventory = Theme.Text("228 original + " + SupplementalCatalog.All.Count + " additional\nOriginal-value snapshots", 10, Theme.Secondary, FontWeights.Normal);
            inventory.Margin = new Thickness(0, 6, 0, 0); footer.Children.Add(inventory); DockPanel.SetDock(footer, Dock.Bottom); rail.Children.Add(footer);
            var nav = new StackPanel();
            string[] names = { "Overview", "Tweaks", "System", "Power", "Games", "Cleaner", "Wallpapers" };
            string[] glyphs = { "\uE80F", "\uE713", "\uE770", "\uE7E8", "\uE7FC", "\uE74D", "\uE91B" };
            for (int i = 0; i < names.Length; i++)
            {
                string destination = names[i];
                var button = Theme.Button(destination, false); button.Name = "Nav" + destination;
                button.HorizontalContentAlignment = HorizontalAlignment.Left; button.Margin = new Thickness(0, 0, 0, 6); button.Height = 43; button.Padding = new Thickness(12, 8, 12, 8);
                var label = new StackPanel { Orientation = Orientation.Horizontal };
                label.Children.Add(new TextBlock { Text = glyphs[i], FontFamily = new FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets"), FontSize = 16, Width = 29, VerticalAlignment = VerticalAlignment.Center });
                label.Children.Add(new TextBlock { Text = destination, FontSize = 13, VerticalAlignment = VerticalAlignment.Center });
                button.Content = label; AutomationProperties.SetName(button, destination);
                button.Click += delegate { Navigate(destination); }; navigation.Add(destination, button); nav.Children.Add(button);
            }
            rail.Children.Add(Scroll(nav));
            var railBackground = Theme.Glass(rail, new Thickness(0), 18); railBackground.Background = Theme.Frost(Theme.Sidebar);
            shell.Children.Add(railBackground);
            var main = new Grid { Margin = new Thickness(26, 3, 12, 4) }; Grid.SetColumn(main, 1);
            main.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); main.RowDefinitions.Add(new RowDefinition()); main.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var top = new DockPanel { Margin = new Thickness(0, 0, 0, 17) };
            var refresh = Theme.Button("Refresh state", false); refresh.Margin = new Thickness(0); refresh.Padding = new Thickness(13, 8, 13, 8); refresh.MinHeight = 36; DockPanel.SetDock(refresh, Dock.Right);
            refresh.Click += async delegate { await RefreshReadOnlyAsync(); };
            top.Children.Add(refresh);
            var breadcrumb = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
            breadcrumb.Children.Add(Theme.Text("Workspace", 12, Theme.Secondary, FontWeights.Normal));
            var slash = Theme.Text(" / ", 12, "#A4ADBE", FontWeights.Normal); slash.Margin = new Thickness(8, 0, 8, 0); breadcrumb.Children.Add(slash); breadcrumb.Children.Add(sectionLabel);
            top.Children.Add(breadcrumb); main.Children.Add(top);
            Grid.SetRow(content, 1); main.Children.Add(content);
            notification.MaxHeight = 42; notification.TextTrimming = TextTrimming.CharacterEllipsis;
            var statusBar = Theme.Glass(notification, new Thickness(13, 9, 13, 9), 9, false); statusBar.Margin = new Thickness(0, 12, 0, 0);
            Grid.SetRow(statusBar, 2); main.Children.Add(statusBar);
            shell.Children.Add(main); Content = Theme.Stage(shell);
        }

        private void Navigate(string destination)
        {
            if (busy) return;
            page = destination; sectionLabel.Text = destination;
            foreach (var entry in navigation)
            {
                bool selected = entry.Key == destination;
                entry.Value.Background = selected ? Theme.Frost("#C7D5E9FA") : Brushes.Transparent;
                entry.Value.BorderBrush = selected ? Theme.Rim() : Brushes.Transparent;
                entry.Value.Foreground = Theme.Brush(selected ? Theme.Blue : Theme.Ink);
                entry.Value.Tag = selected ? "CurrentNavigation" : null;
                AutomationProperties.SetHelpText(entry.Value, selected ? "Current page" : "Open " + entry.Key);
            }
            switch (destination)
            {
                case "Overview": content.Content = BuildOverview(); break;
                case "Tweaks": content.Content = BuildTweaks(); break;
                case "Power": content.Content = BuildPower(); break;
                case "Games": content.Content = BuildGames(); break;
                case "Cleaner": content.Content = BuildCleaner(); break;
                case "Wallpapers": content.Content = BuildWallpapers(); break;
                case "System": content.Content = BuildSystem(); break;
                default: throw new ArgumentException("Unknown navigation destination.");
            }
        }

        private StackPanel Heading(string title, string subtitle)
        {
            var panel = new StackPanel { Margin = new Thickness(0, 0, 0, 19) };
            panel.Children.Add(Theme.Text(title, 29, Theme.Ink, FontWeights.SemiBold));
            var sub = Theme.Text(subtitle, 13, Theme.Secondary, FontWeights.Normal); sub.Margin = new Thickness(0, 7, 0, 0); panel.Children.Add(sub); return panel;
        }

        private ScrollViewer Scroll(UIElement child) { return new ScrollViewer { Content = child, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }; }

        private UIElement BuildOverview()
        {
            var panel = new StackPanel { Margin = new Thickness(0, 0, 8, 0) };
            panel.Children.Add(Heading("Your workspace, refined.", "A little more control. A lot less guesswork."));
            var hero = new Grid { Height = 238, Background = Theme.Frost(), ClipToBounds = true };
            var artwork = Theme.Image(Path.Combine(AppContext.BaseDirectory, "Assets", "gojo-wallpaper.png"), 1300);
            hero.Children.Add(new Image { Source = artwork, Stretch = Stretch.UniformToFill });
            var gradient = new LinearGradientBrush { StartPoint = new Point(0, 0.5), EndPoint = new Point(1, 0.5) };
            gradient.GradientStops.Add(new GradientStop(Theme.Brush("#DDE2EFFA").Color, 0));
            gradient.GradientStops.Add(new GradientStop(Theme.Brush("#ADC8DCF1").Color, 0.42));
            gradient.GradientStops.Add(new GradientStop(Theme.Brush("#20D7EAFA").Color, 0.75));
            gradient.GradientStops.Add(new GradientStop(Theme.Brush("#08D7EAFA").Color, 1)); gradient.Freeze();
            hero.Children.Add(new Border { Background = gradient });
            var words = new StackPanel();
            words.Children.Add(Theme.Text("GOJO EDITION  /  BUILT FOR WINDOWS", 10, Theme.Accent, FontWeights.SemiBold));
            var title = Theme.Text("Your system.\nYour own rhythm.", 26, Theme.Ink, FontWeights.SemiBold); title.Margin = new Thickness(0, 10, 0, 8); words.Children.Add(title);
            words.Children.Add(Theme.Text("Thoughtful changes. Original-value backups.\nNothing runs until you choose.", 12, Theme.Secondary, FontWeights.Normal));
            var browse = Theme.Button("Explore the library  →", true); browse.HorizontalAlignment = HorizontalAlignment.Left; browse.MinHeight = 36; browse.Padding = new Thickness(14, 8, 14, 8); browse.Margin = new Thickness(0, 14, 0, 0);
            browse.Click += delegate { Navigate("Tweaks"); }; words.Children.Add(browse);
            var heroCopy = Theme.Glass(words, new Thickness(18, 14, 18, 14), 12, false); heroCopy.Background = Theme.Frost("#DDE6EFF8"); heroCopy.Margin = new Thickness(14); heroCopy.MaxWidth = 350; heroCopy.HorizontalAlignment = HorizontalAlignment.Left; heroCopy.VerticalAlignment = VerticalAlignment.Center; hero.Children.Add(heroCopy);
            hero.SizeChanged += delegate { hero.Clip = new RectangleGeometry(new Rect(0, 0, hero.ActualWidth, hero.ActualHeight), 15, 15); };
            var heroBorder = Theme.Card(hero); heroBorder.Padding = new Thickness(0); panel.Children.Add(heroBorder);
            var metrics = new UniformGrid { Columns = 4 };
            metrics.Children.Add(Metric(session.Catalog.Count.ToString(), "Available tweaks"));
            metrics.Children.Add(Metric(session.Catalog.Select(delegate(TweakDefinition d) { return d.Category; }).Distinct(StringComparer.Ordinal).Count().ToString(), "Categories"));
            metrics.Children.Add(Metric(session.Statuses.Count == 0 ? "—" : session.Statuses.Values.Count(delegate(TweakStatus s) { return s.IsApplied; }).ToString(), "Matching values"));
            metrics.Children.Add(Metric(session.Engine.GetBackups().Count.ToString(), "Saved snapshots"));
            var statsCard = Theme.Card(metrics); statsCard.Padding = new Thickness(18, 14, 18, 14); panel.Children.Add(statsCard);
            var quickLabel = Theme.Text("Where would you like to start?", 18, Theme.Ink, FontWeights.SemiBold); quickLabel.Margin = new Thickness(0, 3, 0, 12); panel.Children.Add(quickLabel);
            var quick = new Grid(); quick.ColumnDefinitions.Add(new ColumnDefinition()); quick.ColumnDefinitions.Add(new ColumnDefinition());
            quick.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); quick.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var system = QuickAction("System", "Know your PC", "Hardware inventory, improvement tips and a Windows restore point.", "\uE770"); system.Margin = new Thickness(0, 0, 7, 14); quick.Children.Add(system);
            var library = QuickAction("Tweaks", "Fine-tune Windows", session.Catalog.Count + " individually selectable tweaks, with searchable risks and saved state.", "\uE713"); library.Margin = new Thickness(7, 0, 0, 14); Grid.SetColumn(library, 1); quick.Children.Add(library);
            var power = QuickAction("Power", "Find your balance", "Explore original power presets. Review the trade-offs before applying.", "\uE7E8"); power.Margin = new Thickness(0, 0, 7, 14); Grid.SetRow(power, 1); quick.Children.Add(power);
            var desktop = QuickAction("Wallpapers", "Set the atmosphere", "A curated wallpaper library. Preview here before changing your desktop.", "\uE91B"); desktop.Margin = new Thickness(7, 0, 0, 14); Grid.SetRow(desktop, 1); Grid.SetColumn(desktop, 1); quick.Children.Add(desktop); panel.Children.Add(quick);
            var preview = Theme.Button("Browse Safe Recommended  →", false); preview.HorizontalAlignment = HorizontalAlignment.Left;
            preview.Click += delegate { Navigate("Tweaks"); collection.SelectedItem = "Safe Recommended"; }; panel.Children.Add(preview);
            var note = Theme.Text(session.Statuses.Count + "/" + session.Catalog.Count + " states read. Matching values do not mean Astra changed them. Restoring requires a saved snapshot. No scores, promised FPS gains or bulk security shortcuts.", 11, Theme.Secondary, FontWeights.Normal);
            note.Margin = new Thickness(0, 8, 0, 4); panel.Children.Add(note); return Scroll(panel);
        }

        private UIElement Metric(string value, string label)
        {
            var panel = new StackPanel { Margin = new Thickness(3, 0, 8, 0) };
            panel.Children.Add(Theme.Text(value, 25, Theme.Ink, FontWeights.SemiBold)); panel.Children.Add(Theme.Text(label, 11, Theme.Secondary, FontWeights.Normal)); return panel;
        }

        private Button QuickAction(string destination, string title, string description, string glyph)
        {
            var button = Theme.Button("Open " + destination, false); button.HorizontalContentAlignment = HorizontalAlignment.Stretch;
            button.Padding = new Thickness(19); button.MinHeight = 150;
            var panel = new StackPanel();
            var top = new DockPanel { Margin = new Thickness(0, 0, 0, 12) };
            var arrow = Theme.Text("↗", 17, Theme.Secondary, FontWeights.Normal); arrow.VerticalAlignment = VerticalAlignment.Center; DockPanel.SetDock(arrow, Dock.Right); top.Children.Add(arrow);
            var symbol = Theme.Glass(new TextBlock { Text = glyph, FontFamily = new FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets"), FontSize = 18, Foreground = Theme.Brush(Theme.Blue), HorizontalAlignment = HorizontalAlignment.Center }, new Thickness(8), 8, false);
            symbol.Width = 36; symbol.HorizontalAlignment = HorizontalAlignment.Left; top.Children.Add(symbol); panel.Children.Add(top);
            panel.Children.Add(Theme.Text(title, 17, Theme.Ink, FontWeights.SemiBold));
            var details = Theme.Text(description, 12, Theme.Secondary, FontWeights.Normal); details.Margin = new Thickness(0, 7, 0, 0); panel.Children.Add(details);
            button.Content = panel; button.ToolTip = "Open " + destination + ". No system changes."; button.Click += delegate { Navigate(destination); }; return button;
        }

        private ComboBox Choice(IEnumerable<string> items)
        {
            var combo = new ComboBox { MinWidth = 135, Height = 38, Margin = new Thickness(0, 0, 9, 7), FontSize = 12, Padding = new Thickness(12, 8, 12, 8), Background = Theme.Frost(), Foreground = Theme.Brush(Theme.Ink), BorderBrush = Theme.Rim(), MaxDropDownHeight = 330 };
            foreach (string item in items) combo.Items.Add(item);
            combo.SelectedIndex = 0; return combo;
        }

        private UIElement BuildTweaks()
        {
            var grid = new Grid();
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); grid.RowDefinitions.Add(new RowDefinition());
            grid.Children.Add(Heading("Tweak library", "228 original + " + SupplementalCatalog.All.Count + " additional · review one change at a time, keep original-value snapshots."));
            var filters = new Grid { Margin = new Thickness(0, 0, 0, 12) }; filters.ColumnDefinitions.Add(new ColumnDefinition()); filters.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            search = new TextBox { Name = "TweakSearch", Tag = "Search tweaks, IDs or descriptions", Height = 41, Padding = new Thickness(37, 9, 12, 9), FontSize = 13, Background = Theme.Frost(), Foreground = Theme.Brush(Theme.Ink), BorderBrush = Theme.Rim(), CaretBrush = Theme.Brush(Theme.Blue), Margin = new Thickness(0, 0, 10, 0), ToolTip = "Search all titles, IDs, categories, descriptions and caveats" };
            AutomationProperties.SetName(search, "Search tweaks"); filters.Children.Add(search);
            filters.Children.Add(new TextBlock { Text = "\uE721", FontFamily = new FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets"), FontSize = 15, Foreground = Theme.Brush(Theme.Secondary), Margin = new Thickness(13, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center, IsHitTestVisible = false });
            var clear = Theme.Button("Clear search", false); clear.Margin = new Thickness(0); clear.Click += delegate { search.Clear(); }; Grid.SetColumn(clear, 1); filters.Children.Add(clear); Grid.SetRow(filters, 1); grid.Children.Add(filters);
            var selections = new WrapPanel { Margin = new Thickness(0, 0, 0, 9) };
            category = Choice(new string[] { "All categories" }.Concat(session.Catalog.Select(delegate(TweakDefinition d) { return d.Category; }).Distinct(StringComparer.Ordinal).OrderBy(delegate(string s) { return s; }))); category.Name = "CategoryFilter";
            collection = Choice(new string[] { "All collections", "Safe Recommended", "Recommended", "Aggressive", "Absolute", "Max" }); collection.Name = "CollectionFilter";
            statusFilter = Choice(new string[] { "Any status", "Applied", "Not applied", "Backed up", "Unknown" }); statusFilter.Name = "StatusFilter";
            AutomationProperties.SetName(category, "Category filter"); AutomationProperties.SetName(collection, "Collection filter"); AutomationProperties.SetName(statusFilter, "Status filter");
            selections.Children.Add(category); selections.Children.Add(collection); selections.Children.Add(statusFilter); Grid.SetRow(selections, 2); grid.Children.Add(selections);
            results = Theme.Text("", 12, Theme.Secondary, FontWeights.Normal); results.Margin = new Thickness(0, 0, 0, 10); Grid.SetRow(results, 3); grid.Children.Add(results);
            var body = new Grid();
            tweaks = new ListBox { Name = "TweakList", Background = Brushes.Transparent, BorderThickness = new Thickness(0), HorizontalContentAlignment = HorizontalAlignment.Stretch, ItemTemplate = TweakTemplate(), Padding = new Thickness(0) };
            VirtualizingPanel.SetIsVirtualizing(tweaks, true); VirtualizingPanel.SetVirtualizationMode(tweaks, VirtualizationMode.Recycling); ScrollViewer.SetCanContentScroll(tweaks, true);
            ScrollViewer.SetHorizontalScrollBarVisibility(tweaks, ScrollBarVisibility.Disabled); ScrollViewer.SetVerticalScrollBarVisibility(tweaks, ScrollBarVisibility.Auto);
            tweaks.ItemContainerStyle = (Style)FindResource("TweakItem");
            body.Children.Add(tweaks);
            empty = Theme.Text("No matching tweaks.\nTry another search or clear your filters.", 20, Theme.Secondary, FontWeights.Normal); empty.Name = "NoResults"; empty.HorizontalAlignment = HorizontalAlignment.Center; empty.VerticalAlignment = VerticalAlignment.Center; body.Children.Add(empty); Grid.SetRow(body, 4); grid.Children.Add(body);
            search.TextChanged += delegate { FilterTweaks(); }; category.SelectionChanged += delegate { FilterTweaks(); }; collection.SelectionChanged += delegate { FilterTweaks(); }; statusFilter.SelectionChanged += delegate { FilterTweaks(); };
            FilterTweaks(); return grid;
        }

        private void FilterTweaks()
        {
            if (tweaks == null || category == null || collection == null || statusFilter == null) return;
            string query = (search.Text ?? "").Trim(); string cat = Convert.ToString(category.SelectedItem); string group = Convert.ToString(collection.SelectedItem); string filter = Convert.ToString(statusFilter.SelectedItem);
            var rows = new List<TweakRow>();
            foreach (var d in session.Catalog)
            {
                if (cat != "All categories" && d.Category != cat) continue;
                if (query.Length > 0 && (d.Id + " " + d.Title + " " + d.Category + " " + d.Description + " " + d.Caveat + " " + d.Note).IndexOf(query, StringComparison.OrdinalIgnoreCase) < 0) continue;
                if (group == "Recommended" && !d.Recommended || group == "Aggressive" && !d.Aggressive || group == "Absolute" && !d.Absolute || group == "Max" && !d.Max) continue;
                if (group == "Safe Recommended" && (!d.Recommended || d.Risk != TweakRisk.Low || d.SecurityTradeOff || d.PerformanceUnproven)) continue;
                TweakStatus state; bool known = session.Statuses.TryGetValue(d.Id, out state);
                if (filter == "Applied" && (!known || !state.IsApplied) || filter == "Not applied" && (!known || state.IsApplied) || filter == "Unknown" && known) continue;
                var row = new TweakRow(d, session); if (filter == "Backed up" && !row.HasBackup) continue; rows.Add(row);
            }
            tweaks.ItemsSource = rows;
            empty.Visibility = rows.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
            results.Text = rows.Count + " of " + session.Catalog.Count + " tweaks  ·  " + session.Statuses.Values.Count(delegate(TweakStatus s) { return s.IsApplied; }) + " currently applied  ·  " + session.Engine.GetBackups().Count + " saved backups" + (group == "Safe Recommended" ? "\nPreview list only: low risk, no security trade-off, no unproven benefit. Choose each tweak explicitly." : "");
        }

        private DataTemplate TweakTemplate()
        {
            var template = new DataTemplate(typeof(TweakRow));
            var card = new FrameworkElementFactory(typeof(Border)); card.Name = "TweakCard"; card.SetValue(Border.BackgroundProperty, Theme.Frost()); card.SetValue(Border.BorderBrushProperty, Theme.Rim()); card.SetValue(Border.BorderThicknessProperty, new Thickness(1)); card.SetValue(Border.CornerRadiusProperty, new CornerRadius(14)); card.SetValue(Border.PaddingProperty, new Thickness(21)); card.SetValue(Border.MarginProperty, new Thickness(0, 0, 8, 13));
            var stack = new FrameworkElementFactory(typeof(StackPanel));
            stack.AppendChild(BoundText("Title", 18, Theme.Ink, true)); stack.AppendChild(BoundText("Metadata", 11, Theme.Accent, false)); stack.AppendChild(BoundText("Description", 13, Theme.Secondary, false)); stack.AppendChild(BoundText("Caveat", 12, Theme.Warning, false)); stack.AppendChild(BoundText("State", 11, Theme.Success, false));
            var buttons = new FrameworkElementFactory(typeof(StackPanel)); buttons.SetValue(StackPanel.OrientationProperty, Orientation.Horizontal); buttons.SetValue(FrameworkElement.MarginProperty, new Thickness(0, 7, 0, 0));
            buttons.AppendChild(TweakActionButton("Review & apply", false)); buttons.AppendChild(TweakActionButton("Restore", true)); stack.AppendChild(buttons); card.AppendChild(stack); template.VisualTree = card;
            var hover = new Trigger { SourceName = "TweakCard", Property = UIElement.IsMouseOverProperty, Value = true }; hover.Setters.Add(new Setter(Border.BorderBrushProperty, Theme.Brush("#8AAECE"), "TweakCard")); hover.Setters.Add(new Setter(Border.BackgroundProperty, Theme.Frost("#D0EAF4FC"), "TweakCard")); template.Triggers.Add(hover); return template;
        }

        private FrameworkElementFactory BoundText(string property, double size, string color, bool bold)
        {
            var element = new FrameworkElementFactory(typeof(TextBlock)); element.SetBinding(TextBlock.TextProperty, new Binding(property)); element.SetValue(TextBlock.FontSizeProperty, size); element.SetValue(TextBlock.ForegroundProperty, Theme.Brush(color)); element.SetValue(TextBlock.TextWrappingProperty, TextWrapping.Wrap); element.SetValue(FrameworkElement.MarginProperty, new Thickness(0, 0, 0, 6)); if (bold) element.SetValue(TextBlock.FontWeightProperty, FontWeights.SemiBold); return element;
        }

        private FrameworkElementFactory TweakActionButton(string title, bool restore)
        {
            var element = new FrameworkElementFactory(typeof(Button)); element.SetValue(ContentControl.ContentProperty, title); element.SetValue(Control.TemplateProperty, Theme.ButtonTemplate()); element.SetValue(Control.PaddingProperty, new Thickness(15, 9, 15, 9)); element.SetValue(Control.BackgroundProperty, Theme.ButtonFill(!restore)); element.SetValue(Control.ForegroundProperty, Theme.Brush(restore ? Theme.Ink : Theme.White)); element.SetValue(Control.BorderBrushProperty, Theme.Rim()); element.SetValue(Control.BorderThicknessProperty, new Thickness(1)); element.SetValue(Control.FontWeightProperty, FontWeights.SemiBold); element.SetValue(Control.HorizontalContentAlignmentProperty, HorizontalAlignment.Center); element.SetValue(Control.VerticalContentAlignmentProperty, VerticalAlignment.Center); element.SetValue(AutomationProperties.NameProperty, title); element.SetValue(FrameworkElement.MarginProperty, new Thickness(0, 0, 8, 0)); element.SetValue(FrameworkElement.CursorProperty, Cursors.Hand); element.SetBinding(UIElement.IsEnabledProperty, new Binding(restore ? "CanRestore" : "CanApply"));
            if (!restore) element.SetValue(FrameworkElement.TagProperty, "PrimaryAction");
            element.AddHandler(ButtonBase.ClickEvent, new RoutedEventHandler(async delegate(object sender, RoutedEventArgs e)
            {
                var row = ((FrameworkElement)sender).DataContext as TweakRow; if (row == null || busy || !session.CanMutate()) return;
                if (!ConfirmDialog.Ask(this, restore ? "Restore original values" : "Review this tweak", ToolboxSession.TweakDetails(row.Definition), restore ? "Restore this tweak" : "Apply this tweak")) return;
                await RunAsync(async delegate
                {
                    var result = await session.ChangeTweakAsync(row.Id, restore, true);
                    await session.RefreshAsync();
                    if (!result.Success) throw new InvalidOperationException(result.Message);
                    return result.Message + (result.RequiresRestart ? " Restart Windows when ready; Astra will not restart it automatically." : "");
                });
                if (!busy) Navigate("Tweaks");
            }));
            return element;
        }

        private UIElement BuildPower()
        {
            var panel = new StackPanel(); panel.Children.Add(Heading("Power presets", Enum.GetValues(typeof(PowerPresetKind)).Length + " original presets · keep a saved previous plan · no automatic tuning."));
            var current = Theme.Text(powerStatus, 14, Theme.Success, FontWeights.Normal); panel.Children.Add(Theme.Card(current));
            var read = Theme.Button("Read active power plan", false); read.HorizontalAlignment = HorizontalAlignment.Left;
            read.Click += async delegate { await RunAsync(async delegate { var status = await session.Power.GetStatusAsync(CancellationToken.None); powerStatus = status.ActivePlanName + "\n" + status.ActivePlanGuid + (status.HasProcessorRange ? "\n" + status.ProcessorRangeLabel : "") + (status.IsAstraActive ? "\nAstra preset: " + status.AstraPresetName : ""); current.Text = powerStatus; return "Power plan read. No settings changed."; }); }; panel.Children.Add(read);
            foreach (PowerPresetKind kind in Enum.GetValues(typeof(PowerPresetKind)))
            {
                PowerPresetKind selected = kind; var definition = PowerPresetCatalog.Get(kind); var card = new StackPanel();
                card.Children.Add(Theme.Text(definition.Title, 21, Theme.Ink, FontWeights.SemiBold));
                var description = Theme.Text(definition.Description, 13, Theme.Secondary, FontWeights.Normal); description.Margin = new Thickness(0, 7, 0, 10); card.Children.Add(description);
                card.Children.Add(Theme.Text(String.Join("  ·  ", definition.Highlights ?? new string[0]), 12, Theme.Accent, FontWeights.Normal));
                var apply = Theme.Button("Review preset", true); apply.IsEnabled = !session.ReadOnly; apply.HorizontalAlignment = HorizontalAlignment.Left;
                apply.Click += async delegate { if (!ConfirmDialog.Ask(this, "Review power preset", ToolboxSession.PowerDetails(selected), "Apply " + selected)) return; await RunAsync(delegate { return session.ChangePowerAsync(selected.ToString(), false, true); }); }; card.Children.Add(apply); panel.Children.Add(Theme.Card(card));
            }
            var restore = Theme.Button("Restore saved power plan", false); restore.IsEnabled = !session.ReadOnly;
            restore.Click += async delegate { await RunAsync(delegate { return session.ChangePowerAsync(null, true, false); }); }; panel.Children.Add(restore); return Scroll(panel);
        }

        private UIElement BuildGames()
        {
            var panel = new StackPanel(); panel.Children.Add(Heading("Game profiles", ToolboxSession.Games.Length + " AME helper profiles · detected installations only · independent backups."));
            panel.Children.Add(Theme.Card(Theme.Text("These are per-game profiles, not a universal performance preset. Close your game before applying. The bundled helper manages its own backups; launch options are never applied automatically.", 13, Theme.Secondary, FontWeights.Normal)));
            foreach (string game in ToolboxSession.Games)
            {
                string selected = game; var card = new StackPanel();
                string title = game == "Cod" ? "Call of Duty" : game == "Siege" ? "Rainbow Six Siege" : game == "CS2" ? "Counter-Strike 2" : game;
                card.Children.Add(Theme.Text(title, 21, Theme.Ink, FontWeights.SemiBold));
                var description = Theme.Text("Original helper: per-game GPU preferences and supported configuration changes. Installation detection and backup/restore are handled by GameProfiles.ps1.", 13, Theme.Secondary, FontWeights.Normal); description.Margin = new Thickness(0, 8, 0, 12); card.Children.Add(description);
                var controls = new StackPanel { Orientation = Orientation.Horizontal };
                var apply = Theme.Button("Review profile", true); apply.IsEnabled = !session.ReadOnly; apply.Click += async delegate { await RunAsync(delegate { return session.GameAsync(selected, false, false); }); };
                var restore = Theme.Button("Restore profile", false); restore.IsEnabled = !session.ReadOnly; restore.Click += async delegate { await RunAsync(delegate { return session.GameAsync(selected, true, false); }); };
                controls.Children.Add(apply); controls.Children.Add(restore); card.Children.Add(controls); panel.Children.Add(Theme.Card(card));
            }
            return Scroll(panel);
        }

        private UIElement BuildCleaner()
        {
            var panel = new StackPanel(); panel.Children.Add(Heading("Storage cleanup", "Scan first. Choose categories. Deletion is never automatic and cannot be undone."));
            var findings = Theme.Text(lastCleanScan, 12, Theme.Secondary, FontWeights.Normal); var findingsCard = Theme.Card(Scroll(findings)); findingsCard.MaxHeight = 240; panel.Children.Add(findingsCard);
            var scan = Theme.Button("Scan caches · read only", false); scan.HorizontalAlignment = HorizontalAlignment.Left;
            scan.Click += async delegate { await RunAsync(async delegate { var result = await session.Cleaner.ScanAsync(null, CancellationToken.None); lastCleanScan = ToolboxSession.Describe(result); findings.Text = lastCleanScan; cleanerScanned = true; return "Scan completed. No files deleted. Choose categories below."; }); }; panel.Children.Add(scan);
            var selections = new StackPanel(); cleanSelection.Clear();
            foreach (CleanCategoryKind kind in Enum.GetValues(typeof(CleanCategoryKind)))
            {
                var box = new CheckBox { Content = CleanLabel(kind), Foreground = Theme.Brush(Theme.Ink), Margin = new Thickness(0, 9, 0, 9), FontSize = 13, IsChecked = false }; cleanSelection.Add(kind, box); selections.Children.Add(box);
            }
            panel.Children.Add(Theme.Card(selections)); panel.Children.Add(Theme.Text("Close applications first. Shader caches rebuild and can cause temporary stutter. Error reports and crash dumps may be useful for troubleshooting. Locked files can be skipped; space savings are read from the service, never estimated by this UI.", 12, Theme.Warning, FontWeights.Normal));
            var clean = Theme.Button("Review selected deletion", true); clean.IsEnabled = !session.ReadOnly; clean.HorizontalAlignment = HorizontalAlignment.Left;
            clean.Click += async delegate
            {
                if (!cleanerScanned) { Notify("Scan caches before cleaning.", false); return; }
                var chosen = cleanSelection.Where(delegate(KeyValuePair<CleanCategoryKind, CheckBox> item) { return item.Value.IsChecked == true; }).Select(delegate(KeyValuePair<CleanCategoryKind, CheckBox> item) { return item.Key; }).ToArray();
                if (chosen.Length == 0) { Notify("Select at least one category. Nothing has been deleted.", false); return; }
                await RunAsync(async delegate { var result = await session.CleanAsync(chosen, false); cleanerScanned = false; return result; });
            }; panel.Children.Add(clean); return Scroll(panel);
        }

        private string CleanLabel(CleanCategoryKind kind)
        {
            switch (kind)
            {
                case CleanCategoryKind.UserTemp: return "User temporary files";
                case CleanCategoryKind.WindowsTemp: return "Windows temporary files · administrator permission";
                case CleanCategoryKind.CrashDumps: return "Crash dumps · removes diagnostic evidence";
                case CleanCategoryKind.ErrorReports: return "Windows error reports · removes diagnostic evidence";
                case CleanCategoryKind.ShaderCaches: return "GPU shader caches · shaders will recompile";
                case CleanCategoryKind.SteamShaderCache: return "Steam shader cache · shaders will recompile";
                default: return kind.ToString();
            }
        }

        private UIElement BuildWallpapers()
        {
            var panel = new StackPanel(); panel.Children.Add(Heading("Wallpaper studio", "Browse, preview, then decide. Your Windows desktop changes only when you choose Apply."));
            if (wallpaperError != null) { panel.Children.Add(Theme.Card(Theme.Text(wallpaperError, 14, Theme.Error, FontWeights.Normal))); return Scroll(panel); }
            var preview = new Grid { Height = 235, Background = Theme.Frost("#7CB9CFE4"), ClipToBounds = true };
            wallpaperPreview = new Image { Name = "WallpaperPreview", Stretch = Stretch.Uniform }; AutomationProperties.SetName(wallpaperPreview, "Selected wallpaper preview"); preview.Children.Add(wallpaperPreview);
            var previewCard = Theme.Card(preview); previewCard.Padding = new Thickness(9); panel.Children.Add(previewCard);
            wallpaperTitle = Theme.Text("Select a wallpaper", 19, Theme.Ink, FontWeights.SemiBold); panel.Children.Add(wallpaperTitle);
            var actions = new WrapPanel { Margin = new Thickness(0, 6, 0, 15) };
            wallpaperApply = Theme.Button("Apply to Windows desktop", true); wallpaperApply.Name = "ApplyWallpaper";
            wallpaperApply.Click += async delegate { await RunAsync(delegate { return session.WallpaperAsync(selectedWallpaper, false, false); }); }; actions.Children.Add(wallpaperApply);
            var restore = Theme.Button("Restore previous desktop", false); restore.IsEnabled = !session.ReadOnly; restore.Click += async delegate { await RunAsync(delegate { return session.WallpaperAsync(null, true, false); }); }; actions.Children.Add(restore); panel.Children.Add(actions);
            var library = new WrapPanel(); wallpaperButtons.Clear();
            foreach (var item in wallpapers)
            {
                var entry = item; var thumb = new StackPanel { Width = 174 };
                var image = Theme.Image(entry.FullPath, 360);
                var thumbnail = new Image { Source = image, Width = 174, Height = 95, Stretch = Stretch.UniformToFill, Clip = new RectangleGeometry(new Rect(0, 0, 174, 95), 8, 8) }; thumb.Children.Add(thumbnail);
                var label = Theme.Text(entry.Title + (entry.Available ? "" : " · Missing asset"), 12, Theme.Ink, FontWeights.Normal); label.Margin = new Thickness(1, 10, 1, 3); thumb.Children.Add(label);
                var button = Theme.Button("Preview " + entry.Title, false); button.Content = thumb; button.Padding = new Thickness(8); button.Margin = new Thickness(0, 0, 12, 12); button.ToolTip = "Preview " + entry.Title; button.Click += delegate { SelectWallpaper(entry); }; wallpaperButtons.Add(entry.Id, button); library.Children.Add(button);
            }
            panel.Children.Add(library); panel.Children.Add(Theme.Text(wallpapers.Count + " wallpapers in the packaged library. Desktop changes are delegated only to the whitelisted Wallpaper.ps1 helper, with saved desktop values for Restore.", 12, Theme.Secondary, FontWeights.Normal));
            if (selectedWallpaper == null && wallpapers.Count > 0) selectedWallpaper = wallpapers[0]; SelectWallpaper(selectedWallpaper); return Scroll(panel);
        }

        private void SelectWallpaper(WallpaperEntry entry)
        {
            selectedWallpaper = entry;
            if (wallpaperPreview == null) return;
            wallpaperPreview.Source = entry == null ? null : Theme.Image(entry.FullPath, 1200);
            wallpaperTitle.Text = entry == null ? "Select a wallpaper" : entry.Title + (entry.Available ? " · Preview only" : " · Asset missing");
            wallpaperApply.IsEnabled = !session.ReadOnly && entry != null && entry.Available;
            foreach (var item in wallpaperButtons)
            {
                bool selected = entry != null && item.Key == entry.Id;
                item.Value.BorderBrush = selected ? Theme.Brush(Theme.Blue) : Theme.Rim();
                item.Value.Background = Theme.Frost(selected ? "#D0CDE5F8" : Theme.Surface);
            }
        }

        private UIElement BuildRestore()
        {
            var panel = new StackPanel();
            var intro = new StackPanel(); intro.Children.Add(Theme.Text(session.Engine.GetBackups().Count + " saved tweak snapshots", 20, Theme.Ink, FontWeights.SemiBold));
            var explanation = Theme.Text("Restore saved original values, never settings Astra did not back up. The original AstraPC backup location is preserved, so all 228 original tweaks retain their existing snapshots. Matching values without a backup do not imply a reversible Astra change.", 13, Theme.Secondary, FontWeights.Normal);
            explanation.Margin = new Thickness(0, 8, 0, 12); intro.Children.Add(explanation);
            var restore = Theme.Button("Review restore of all saved tweaks", false); restore.IsEnabled = !session.ReadOnly; restore.HorizontalAlignment = HorizontalAlignment.Left;
            restore.Click += async delegate { await RunAsync(async delegate { string text = await session.RestoreAllAsync(false); await session.RefreshAsync(); return text; }); Navigate("System"); }; intro.Children.Add(restore); panel.Children.Add(intro);
            var snapshots = new StackPanel();
            foreach (var backup in session.Engine.GetBackups().OrderByDescending(delegate(TweakBackup b) { return b.AppliedAt; }))
            {
                TweakDefinition definition; string title = session.ById.TryGetValue(backup.TweakId, out definition) ? definition.Title : backup.TweakId + " · original catalog restore only";
                var row = Theme.Text(title + "\n" + backup.TweakId + "  ·  " + backup.AppliedAt.ToString("g", CultureInfo.CurrentCulture), 12, Theme.Secondary, FontWeights.Normal); row.Margin = new Thickness(0, 0, 0, 12); snapshots.Children.Add(row);
            }
            if (snapshots.Children.Count == 0) snapshots.Children.Add(Theme.Text("No saved tweak snapshots in this state root.", 13, Theme.Secondary, FontWeights.Normal));
            var snapshotCard = Theme.Card(Scroll(snapshots)); snapshotCard.Background = Theme.Frost("#80BED1E5"); snapshotCard.Effect = null; snapshotCard.MaxHeight = 260; snapshotCard.Margin = new Thickness(0, 14, 0, 16); snapshotCard.Padding = new Thickness(16); panel.Children.Add(snapshotCard);
            panel.Children.Add(Theme.Text("Separate restore controls", 16, Theme.Ink, FontWeights.SemiBold));
            var separate = new WrapPanel { Margin = new Thickness(0, 9, 0, 12) };
            foreach (string destination in new string[] { "Power", "Games", "Wallpapers" })
            {
                string selected = destination; var button = Theme.Button("Open " + destination, false); button.ToolTip = "Open " + destination + " restore controls"; button.Click += delegate { Navigate(selected); }; separate.Children.Add(button);
            }
            panel.Children.Add(separate);
            panel.Children.Add(Theme.Text("Deleted cleaner files cannot be restored. Astra does not restart Windows, disable security in bulk, or run every Max tweak. Review individual risks in the tweak library.", 12, Theme.Warning, FontWeights.Normal));
            var expander = new Expander { Name = "SavedBackups", Header = Theme.Text("Saved original-value backups", 17, Theme.Ink, FontWeights.SemiBold), Content = panel, IsExpanded = false };
            AutomationProperties.SetName(expander, "Saved Astra snapshots and restore controls"); return Theme.Card(expander);
        }

        private void Notify(string message, bool success)
        {
            notification.Text = message; notification.Foreground = Theme.Brush(success ? Theme.Success : Theme.Error); notification.ToolTip = message;
        }

        private async Task RunAsync(Func<Task<string>> operation)
        {
            if (busy) return;
            busy = true; content.IsEnabled = false; foreach (var button in navigation.Values) button.IsEnabled = false;
            try { Notify("Working on the requested operation…", true); string message = await operation(); Notify(message, true); }
            catch (OperationCanceledException) { Notify("Cancelled. No further action was taken.", false); }
            catch (Exception error) { Notify(error.Message, false); }
            finally { busy = false; content.IsEnabled = true; foreach (var button in navigation.Values) button.IsEnabled = true; Navigate(page); }
        }

        private async Task SelfTestAsync(string outputDirectory)
        {
            var assertions = new List<string>();
            Action<bool, string> check = delegate(bool value, string label) { if (!value) throw new InvalidOperationException("Self-test failed: " + label); assertions.Add("PASS " + label); };
            check(session.ReadOnly, "self-test is read only");
            int expectedCount = 228 + SupplementalCatalog.All.Count;
            int categoryCount = session.Catalog.Select(delegate(TweakDefinition d) { return d.Category; }).Distinct(StringComparer.Ordinal).Count();
            check(session.Catalog.Count == expectedCount && TweakCatalog.All.Count == 228, expectedCount + " definitions include all 228 originals");
            check(TweakCatalog.All.All(delegate(TweakDefinition d) { return session.ById.ContainsKey(d.Id); }), "original ID coverage");
            var originalCategories = TweakCatalog.All.Select(delegate(TweakDefinition d) { return d.Category; }).Distinct(StringComparer.Ordinal).ToArray();
            check(originalCategories.Length == 22 && originalCategories.All(delegate(string name) { return session.Catalog.Any(delegate(TweakDefinition d) { return d.Category == name; }); }), "all 22 original categories retained");
            foreach (var definition in SupplementalCatalog.All) check(session.ById.ContainsKey(definition.Id), "supplemental ID " + definition.Id);
            foreach (string id in new string[] { "exm-restart-sign-on-off", "exm-notification-sound-off", "exm-chrome-online-spelling-off", "exm-chrome-geolocation-off" }) check(session.ById.ContainsKey(id), "original supplemental ID " + id);
            check(!navigation.ContainsKey("Restore") && navigation.ContainsKey("System"), "System replaces Restore navigation");
            var restorePointCommand = Options.Parse(new string[] { "--preview", "--restore-point" });
            check(restorePointCommand.Preview && restorePointCommand.Command == "restore-point" && restorePointCommand.Value == null, "restore-point is a no-value command");
            check(session.Engine.GetBackups().Count == 0, "isolated backup store starts empty");
            await session.RefreshAsync();
            string inventoryStatus = await session.ReadSystemAsync();
            check(!String.IsNullOrWhiteSpace(inventoryStatus), "read-only system inventory returns status");
            check(session.SystemReadError == null && session.SystemReport != null, "live read-only System inventory deserializes successfully");
            check(session.SystemReport.Sections.Count >= 10 && session.SystemReport.Sections.Sum(s => s.Facts.Count) >= 50, "System exposes detailed hardware and Windows fields");
            check(session.SystemReport.Sections.All(s => !String.IsNullOrWhiteSpace(s.Title) && s.Facts.All(f => !String.IsNullOrWhiteSpace(f.Label) && !String.IsNullOrWhiteSpace(f.Value))), "System facts have readable labels and explicit values");
            check(session.Statuses.Keys.All(delegate(string id) { return session.ById.ContainsKey(id); }), "statuses resolve only whitelisted IDs");
            check(session.Statuses.Values.All(delegate(TweakStatus s) { return !s.HasBackup; }), "isolated state has no host backups");
            Navigate("Overview"); await RenderAsync(Path.Combine(outputDirectory, "dashboard.png"));
            Width = 900; Height = 650;
            await RenderAsync(Path.Combine(outputDirectory, "dashboard-small.png"));
            check(ActualWidth >= 900 && ActualHeight >= 650, "minimum window size renders");
            check(navigation.Values.All(delegate(Button b) { var bounds = b.TransformToAncestor(this).TransformBounds(new Rect(0, 0, b.ActualWidth, b.ActualHeight)); return b.ActualHeight > 0 && bounds.Top >= 0 && bounds.Bottom <= ActualHeight; }), "all navigation fits at minimum window size");
            Width = 1160; Height = 800;
            foreach (string destination in navigation.Keys.ToArray())
            {
                navigation[destination].RaiseEvent(new RoutedEventArgs(ButtonBase.ClickEvent)); check(page == destination && content.Content != null, "navigation " + destination);
            }
            Navigate("System"); await RenderAsync(Path.Combine(outputDirectory, "system.png"));
            var systemContent = content.Content as FrameworkElement;
            check(page == "System" && systemContent != null && systemContent.ActualWidth > 0 && systemContent.ActualHeight > 0, "System content renders");
            var restorePoint = VisualDescendants(content).OfType<Button>().FirstOrDefault(delegate(Button b) { return b.Name == "CreateRestorePoint"; });
            check(restorePoint != null && !restorePoint.IsEnabled, "CreateRestorePoint control is disabled in preview");
            Navigate("Tweaks"); check(tweaks.Items.Count == expectedCount, "unfiltered full catalog rendered");
            check(category.Items.Count == categoryCount + 1, "category selector includes all " + categoryCount + " categories");
            check(VirtualizingPanel.GetIsVirtualizing(tweaks) && VirtualizingPanel.GetVirtualizationMode(tweaks) == VirtualizationMode.Recycling, "tweak list virtualized with recycling");
            foreach (var definition in session.Catalog)
            {
                search.Text = definition.Id; check(tweaks.Items.Cast<TweakRow>().Any(delegate(TweakRow row) { return row.Id == definition.Id; }), "search ID " + definition.Id);
            }
            search.Text = "ASTRA__NO_MATCH__7EA4"; check(tweaks.Items.Count == 0 && empty.Visibility == Visibility.Visible, "empty-search state visible");
            search.Clear(); check(tweaks.Items.Count == expectedCount && empty.Visibility == Visibility.Collapsed, "search clear restores catalog");
            foreach (string name in category.Items.Cast<string>().Skip(1).ToArray())
            {
                category.SelectedItem = name;
                check(tweaks.Items.Count == session.Catalog.Count(delegate(TweakDefinition d) { return d.Category == name; }), "category filter " + name);
            }
            category.SelectedItem = "All categories";
            collection.SelectedItem = "Safe Recommended";
            check(tweaks.Items.Cast<TweakRow>().All(delegate(TweakRow row) { var d = row.Definition; return d.Recommended && d.Risk == TweakRisk.Low && !d.SecurityTradeOff && !d.PerformanceUnproven; }), "safe recommended excludes risk/security/unproven");
            collection.SelectedItem = "All collections";
            foreach (string group in new string[] { "Recommended", "Aggressive", "Absolute", "Max" })
            {
                collection.SelectedItem = group; check(tweaks.Items.Count == session.Catalog.Count(delegate(TweakDefinition d) { return group == "Recommended" ? d.Recommended : group == "Aggressive" ? d.Aggressive : group == "Absolute" ? d.Absolute : d.Max; }), "collection filter " + group);
            }
            collection.SelectedItem = "All collections"; statusFilter.SelectedItem = "Backed up"; check(tweaks.Items.Count == 0, "backed-up filter uses isolated state"); statusFilter.SelectedItem = "Any status";
            check(tweaks.Items.Cast<TweakRow>().All(delegate(TweakRow row) { return !row.CanApply && !row.CanRestore; }), "preview tweak controls disable mutations");
            check(session.Catalog.Where(delegate(TweakDefinition d) { return d.Risk != TweakRisk.Low || d.SecurityTradeOff; }).All(ToolboxSession.RiskConfirmationRequired), "medium/major/security require confirmation");
            var risk = session.Catalog.First(delegate(TweakDefinition d) { return d.Risk != TweakRisk.Low; });
            var confirmation = new ConfirmDialog("Review this tweak", ToolboxSession.TweakDetails(risk), "Apply this tweak");
            check(confirmation.Details.Text.Contains(risk.Id) && confirmation.Details.Text.Contains(risk.Risk.ToString()) && (String.IsNullOrWhiteSpace(risk.Caveat) || confirmation.Details.Text.Contains(risk.Caveat)), "risk dialog contains identity risk and caveat");
            check(confirmation.Cancel.IsDefault && confirmation.Cancel.IsCancel && !confirmation.Accept.IsDefault, "confirmation defaults to cancel"); confirmation.Close();
            await RenderAsync(Path.Combine(outputDirectory, "tuning.png"));
            Navigate("Wallpapers"); check(wallpaperError == null && wallpapers.Count == 9, "nine wallpaper manifest entries");
            check(wallpapers.All(delegate(WallpaperEntry w) { return w.Available && Theme.Image(w.FullPath, 80) != null; }), "all whitelisted wallpaper paths exist and decode");
            check(wallpaperButtons.Count == 9 && wallpaperPreview.Source != null, "wallpaper thumbnails and preview exist");
            if (wallpapers.Count > 1) wallpaperButtons[wallpapers[1].Id].RaiseEvent(new RoutedEventArgs(ButtonBase.ClickEvent));
            check(selectedWallpaper == wallpapers[1] && wallpaperPreview.Source != null && wallpaperTitle.Text.Contains(wallpapers[1].Title), "wallpaper selection updates preview");
            check(!wallpaperApply.IsEnabled, "preview wallpaper apply disabled"); await RenderAsync(Path.Combine(outputDirectory, "wallpapers.png"));
            var blocked = await session.ChangeTweakAsync(session.Catalog[0].Id, false, true);
            check(!blocked.Success && !blocked.RequiresElevation, "preview action guard rejects a requested change without invoking engine apply");
            bool writableRejected = false;
            try { session.RequireWritable(); } catch (InvalidOperationException) { writableRejected = true; }
            check(writableRejected, "preview helper/power/clean/restore guard rejects mutation");
            bool restorePointRejected = false;
            try { await session.CreateRestorePointAsync(); } catch (InvalidOperationException) { restorePointRejected = true; }
            check(restorePointRejected, "preview restore-point method rejects creation before elevation or helper dispatch");
            check(!session.CanMutate() && session.MutationDispatches == 0, "no system mutation or elevation dispatched");
            File.WriteAllText(Path.Combine(outputDirectory, "assertions.txt"), String.Join("\n", assertions));
            Console.WriteLine("Self-test passed: " + assertions.Count + " assertions; no system changes dispatched.");
        }

        private static IEnumerable<DependencyObject> VisualDescendants(DependencyObject root)
        {
            int count = VisualTreeHelper.GetChildrenCount(root);
            for (int i = 0; i < count; i++)
            {
                var child = VisualTreeHelper.GetChild(root, i); yield return child;
                foreach (var descendant in VisualDescendants(child)) yield return descendant;
            }
        }

        private async Task RenderAsync(string path)
        {
            await Dispatcher.InvokeAsync(delegate { UpdateLayout(); }, DispatcherPriority.Render);
            await Dispatcher.InvokeAsync(delegate { }, DispatcherPriority.ApplicationIdle);
            var bitmap = new RenderTargetBitmap((int)Math.Ceiling(ActualWidth), (int)Math.Ceiling(ActualHeight), 96, 96, PixelFormats.Pbgra32); bitmap.Render(this);
            var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap)); using (var stream = File.Create(path)) encoder.Save(stream);
        }
    }

    internal static class Program
    {
        [STAThread]
        public static int Main(string[] arguments)
        {
            try
            {
                Options options = Options.Parse(arguments);
                var catalog = ToolboxSession.FullCatalog();
                ValidateCommand(options, catalog);
                if (options.Command == "catalog")
                {
                    var metadata = catalog.Select(delegate(TweakDefinition d)
                    {
                        return new { id = d.Id, title = d.Title, description = d.Description, category = d.Category, kind = d.Kind.ToString(), risk = d.Risk.ToString(), requiresAdministrator = d.RequiresAdministrator, requiresRestart = d.RequiresRestart, caveat = d.Caveat, note = d.Note, securityTradeOff = d.SecurityTradeOff, performanceUnproven = d.PerformanceUnproven, recommended = d.Recommended, aggressive = d.Aggressive, absolute = d.Absolute, max = d.Max, supplemental = SupplementalCatalog.All.Any(delegate(TweakDefinition extra) { return extra.Id == d.Id; }) };
                    }).ToList();
                    Console.WriteLine(JsonSerializer.Serialize(metadata, metadata.GetType(), new JsonSerializerOptions { WriteIndented = true })); return 0;
                }
                if (options.Preview && options.Command != "ui" && options.Command != "self-test") { Console.Error.WriteLine("Preview blocks all mutations and elevation."); return 3; }
                bool readOnly = options.Preview || options.Command == "self-test";
                if (options.Command == "self-test")
                {
                    options.Value = Path.GetFullPath(options.Value); Directory.CreateDirectory(options.Value);
                    AppPaths.UseRoot(Path.Combine(options.Value, "isolated-state-" + Guid.NewGuid().ToString("N")));
                }
                else if (readOnly) AppPaths.UseRoot(Path.Combine(Path.GetTempPath(), "AstraToolboxPreview", Guid.NewGuid().ToString("N")));
                var session = new ToolboxSession(readOnly);
                if (options.Command != "ui" && options.Command != "self-test")
                {
                    // Keep confirmations on an STA dispatcher even after asynchronous CLI operations resume.
                    var commandApplication = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
                    commandApplication.Startup += async delegate
                    {
                        int exit;
                        try { exit = await RunCommandAsync(session, options); }
                        catch (OperationCanceledException error) { Console.Error.WriteLine(error.Message); exit = 5; }
                        catch (Exception error) { Console.Error.WriteLine("Astra Toolbox: " + error.Message); exit = 1; }
                        commandApplication.Shutdown(exit);
                    };
                    return commandApplication.Run();
                }
                var application = new Application { ShutdownMode = ShutdownMode.OnMainWindowClose };
                var window = new ToolboxWindow(session, options);
                if (options.Command == "self-test") { window.WindowStartupLocation = WindowStartupLocation.Manual; window.Left = -32000; window.Top = -32000; window.ShowInTaskbar = false; }
                return application.Run(window);
            }
            catch (OperationCanceledException error) { Console.Error.WriteLine(error.Message); return 5; }
            catch (Exception error) { Console.Error.WriteLine("Astra Toolbox: " + error.Message); return 1; }
        }

        private static void ValidateCommand(Options options, List<TweakDefinition> catalog)
        {
            if (options.Command == "apply" || options.Command == "revert" || options.Command == "apply-option" || options.Command == "revert-option")
            {
                if (options.Command.EndsWith("-option", StringComparison.Ordinal) && !ToolboxSession.ReviewedOptions.Contains(options.Value, StringComparer.Ordinal)) throw new ArgumentException("Only explicitly reviewed playbook options support this command.");
                if (!catalog.Any(delegate(TweakDefinition d) { return String.Equals(d.Id, options.Value, StringComparison.Ordinal); })) throw new ArgumentException("Unknown tweak ID. Use --catalog for the whitelist.");
            }
            else if (options.Command == "power") { PowerPresetKind kind; if (!ToolboxSession.TryPower(options.Value, out kind)) throw new ArgumentException("Unknown power preset."); }
            else if (options.Command == "clean") ToolboxSession.ParseCategories(options.Value);
            else if (options.Command == "game" || options.Command == "restore-game") { if (!ToolboxSession.Games.Contains(options.Value, StringComparer.Ordinal)) throw new ArgumentException("Unknown game profile."); }
            else if (options.Command == "wallpaper") { if (!ToolboxSession.LoadWallpapers().Any(delegate(WallpaperEntry w) { return w.Id == options.Value && w.Available; })) throw new ArgumentException("Unknown or missing wallpaper. Only manifest IDs are accepted."); }
            else if (options.Command == "self-test") { if (String.IsNullOrWhiteSpace(options.Value)) throw new ArgumentException("Self-test requires an output directory."); Path.GetFullPath(options.Value); }
        }

        private static async Task<int> RunCommandAsync(ToolboxSession session, Options options)
        {
            session.RequireWritable();
            string message;
            switch (options.Command)
            {
                case "apply": case "revert": case "apply-option": case "revert-option":
                    var result = await session.ChangeTweakAsync(options.Value, options.Command == "revert" || options.Command == "revert-option", options.Command.EndsWith("-option", StringComparison.Ordinal));
                    Console.WriteLine(result.Message + (result.RequiresRestart ? "\nRestart required; no restart is performed automatically." : ""));
                    return result.Success && !result.RequiresElevation ? 0 : 2;
                case "restore-all": message = await session.RestoreAllAsync(false); break;
                case "restore-point": message = await session.CreateRestorePointAsync(); break;
                case "power": message = await session.ChangePowerAsync(options.Value, false, false); break;
                case "restore-power": message = await session.ChangePowerAsync(null, true, false); break;
                case "clean":
                    await session.Cleaner.ScanAsync(null, CancellationToken.None);
                    message = await session.CleanAsync(ToolboxSession.ParseCategories(options.Value), false); break;
                case "wallpaper":
                    var entry = ToolboxSession.LoadWallpapers().Single(delegate(WallpaperEntry w) { return w.Id == options.Value; });
                    message = await session.WallpaperAsync(entry, false, false); break;
                case "restore-wallpaper": message = await session.WallpaperAsync(null, true, false); break;
                case "game": case "restore-game": message = await session.GameAsync(options.Value, options.Command == "restore-game", false); break;
                default: throw new ArgumentException("Command is not whitelisted.");
            }
            Console.WriteLine(message); return 0;
        }
    }
}
