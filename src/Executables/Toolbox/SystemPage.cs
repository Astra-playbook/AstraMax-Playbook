using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Media;
using Astra.Core.Models;

namespace Astra.Toolbox
{
    internal sealed class SystemFact
    {
        public string Label { get; set; }
        public string Value { get; set; }
    }

    internal sealed class SystemSection
    {
        public string Title { get; set; }
        public List<SystemFact> Facts { get; set; } = new List<SystemFact>();
    }

    internal sealed class SystemRecommendation
    {
        public string Title { get; set; }
        public string Evidence { get; set; }
        public string Action { get; set; }
        public string Priority { get; set; }
    }

    internal sealed class RestorePointResponse
    {
        public bool Success { get; set; }
        public bool Created { get; set; }
        public string Message { get; set; }
        public string Name { get; set; }
        public string CreationTime { get; set; }
        public List<string> Issues { get; set; } = new List<string>();
    }

    internal sealed class SystemInventory
    {
        public string CapturedAt { get; set; }
        public Dictionary<string, string> Summary { get; set; } = new Dictionary<string, string>();
        public List<SystemSection> Sections { get; set; } = new List<SystemSection>();
        public List<SystemRecommendation> Recommendations { get; set; } = new List<SystemRecommendation>();
        public List<string> Issues { get; set; } = new List<string>();
    }

    internal sealed partial class ToolboxSession
    {
        public SystemInventory SystemReport { get; private set; }
        public string SystemReadError { get; private set; }

        private Task<string> systemScan;
        private Process systemReadProcess;
        public bool SystemReadInProgress { get { return systemScan != null && !systemScan.IsCompleted; } }

        public Task<string> ReadSystemAsync()
        {
            if (systemScan == null || systemScan.IsCompleted) systemScan = CollectSystemAsync();
            return systemScan;
        }

        public void CancelSystemRead()
        {
            if (systemReadProcess == null) return;
            try { if (!systemReadProcess.HasExited) systemReadProcess.Kill(true); }
            catch (InvalidOperationException) { }
        }

        private async Task<string> CollectSystemAsync()
        {
            SystemReadError = null;
            try
            {
                string path = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "SystemInfo.ps1"));
                if (!File.Exists(path)) throw new FileNotFoundException("The packaged SystemInfo.ps1 inventory helper is missing.", path);
                string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe");
                var info = new ProcessStartInfo(powershell, "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " + QuoteArgument(path))
                {
                    UseShellExecute = false, CreateNoWindow = true,
                    RedirectStandardOutput = true, RedirectStandardError = true,
                    StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8,
                    WorkingDirectory = Path.GetDirectoryName(path)
                };
                using (var process = Process.Start(info))
                using (var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(90)))
                {
                    if (process == null) throw new InvalidOperationException("Windows could not start the read-only inventory helper.");
                    systemReadProcess = process;
                    var output = process.StandardOutput.ReadToEndAsync();
                    var errors = process.StandardError.ReadToEndAsync();
                    try { await process.WaitForExitAsync(timeout.Token); }
                    catch (OperationCanceledException)
                    {
                        process.Kill(true);
                        await process.WaitForExitAsync();
                        throw new TimeoutException("The read-only hardware scan timed out. Try refreshing the System page.");
                    }
                    string json = (await output).Trim().TrimStart('\uFEFF');
                    string error = (await errors).Trim();
                    if (process.ExitCode != 0) throw new InvalidOperationException("System inventory failed: " + error);
                    var report = JsonSerializer.Deserialize<SystemInventory>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                    if (report == null || report.Sections == null || report.Sections.Count == 0 || report.Sections.Any(s => s.Facts == null))
                        throw new InvalidDataException("Windows returned an incomplete inventory report.");
                    SystemReport = report;
                    return report.Sections.Count + " system sections read. " + report.Recommendations.Count + " evidence-based checks. No settings changed.";
                }
            }
            catch (Exception error)
            {
                SystemReadError = error.Message;
                return "System details unavailable: " + error.Message;
            }
            finally { systemReadProcess = null; }
        }

        public async Task<string> CreateRestorePointAsync()
        {
            RequireWritable();
            if (!Admin.IsAdministrator)
            {
                int exit = await ElevateAsync(new string[] { "--restore-point" }, false);
                if (exit == 5) throw new OperationCanceledException("Windows administrator approval was cancelled.");
                if (exit != 0) throw new InvalidOperationException("Windows did not confirm a new restore point. Check System Protection or the Windows frequency limit. Details are in the toolbox CLI log (exit " + exit + ").");
                return "Windows confirmed a new Astra Toolbox restore point. This is not a full backup of personal files.";
            }
            MutationDispatches++;
            return await RunHelperAsync("RestorePoint.ps1", new string[] { "-Create" });
        }
    }

    internal sealed partial class ToolboxWindow
    {
        private Button createRestorePoint;

        private async Task RefreshReadOnlyAsync()
        {
            if (busy) return;
            await RunAsync(async delegate { await session.RefreshAsync(); return session.StatusError ?? "Tweak states refreshed. No changes applied."; });
            if (!IsVisible) return;
            Notify("Reading hardware in the background. You can keep browsing.", true);
            string inventory = await session.ReadSystemAsync();
            if (!IsVisible || busy) return;
            Notify(session.StatusError ?? inventory, session.SystemReadError == null && session.StatusError == null);
            if (page == "System") Navigate("System");
        }

        private UIElement BuildSystem()
        {
            var panel = new StackPanel { Name = "SystemPage" };
            panel.Children.Add(Heading("Your PC, in detail", "Real hardware. Real Windows state. Improvement ideas backed by what this PC reports."));
            var report = session.SystemReport;
            if (session.SystemReadError != null)
            {
                var unavailable = Theme.Text((report == null ? "Inventory unavailable. " : "Refresh failed; the previous report is shown. ") + session.SystemReadError, 13, Theme.Error, FontWeights.Normal);
                panel.Children.Add(Theme.Card(unavailable));
            }
            if (report != null)
            {
                var summary = new Grid(); summary.ColumnDefinitions.Add(new ColumnDefinition()); summary.ColumnDefinitions.Add(new ColumnDefinition());
                summary.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); summary.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
                string[] keys = { "cpu", "ram", "gpu", "os" }; string[] labels = { "Processor", "Memory", "Graphics", "Windows" };
                string[] glyphs = { "\uE950", "\uE964", "\uE7F4", "\uE782" };
                for (int i = 0; i < keys.Length; i++)
                {
                    string value; if (!report.Summary.TryGetValue(keys[i], out value)) value = "Unavailable";
                    var item = new StackPanel();
                    var caption = new DockPanel();
                    var glyph = new TextBlock { Text = glyphs[i], FontFamily = new FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets"), FontSize = 14, Foreground = Theme.Brush(Theme.Blue), Margin = new Thickness(0, 0, 9, 0) };
                    caption.Children.Add(glyph); caption.Children.Add(Theme.Text(labels[i].ToUpperInvariant(), 10, Theme.Secondary, FontWeights.SemiBold)); item.Children.Add(caption);
                    var detail = Theme.Text(value, 15, Theme.Ink, FontWeights.SemiBold); detail.Margin = new Thickness(0, 8, 0, 0); item.Children.Add(detail);
                    var cell = Theme.Glass(item, new Thickness(16), 12, false); cell.Margin = new Thickness(i % 2 == 0 ? 0 : 6, 0, i % 2 == 0 ? 6 : 0, 12);
                    Grid.SetColumn(cell, i % 2); Grid.SetRow(cell, i / 2); summary.Children.Add(cell);
                }
                panel.Children.Add(summary);
            }
            var safety = new StackPanel();
            var safetyHeading = new DockPanel();
            var shield = Theme.Glass(new TextBlock { Text = "\uE83D", FontFamily = new FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets"), FontSize = 18, Foreground = Theme.Brush(Theme.Blue), VerticalAlignment = VerticalAlignment.Center }, new Thickness(9), 9, false);
            shield.Margin = new Thickness(0, 0, 12, 0); safetyHeading.Children.Add(shield);
            var safetyTitle = Theme.Text("A checkpoint before you change anything", 18, Theme.Ink, FontWeights.SemiBold); safetyTitle.VerticalAlignment = VerticalAlignment.Center; safetyHeading.Children.Add(safetyTitle); safety.Children.Add(safetyHeading);
            var explain = Theme.Text("Create a Windows System Restore point with one click. Windows asks for administrator approval if needed. System Protection must already be enabled; Windows may limit how often a new point can be created. Personal files need a separate backup.", 12, Theme.Secondary, FontWeights.Normal);
            explain.Margin = new Thickness(0, 8, 0, 13); safety.Children.Add(explain);
            var controls = new WrapPanel();
            createRestorePoint = Theme.Button("Create restore point", true); createRestorePoint.Name = "CreateRestorePoint";
            AutomationProperties.SetName(createRestorePoint, "Create restore point");
            createRestorePoint.IsEnabled = !session.ReadOnly;
            createRestorePoint.ToolTip = session.ReadOnly ? "Preview blocks restore-point creation and UAC." : "Create one point. Never changes protection, quota or the Windows frequency limit.";
            createRestorePoint.Click += async delegate
            {
                await RunAsync(async delegate
                {
                    string result = await session.CreateRestorePointAsync();
                    await session.ReadSystemAsync();
                    return result;
                });
            };
            controls.Children.Add(createRestorePoint);
            var protection = Theme.Button("System Protection settings", false); protection.Name = "OpenSystemProtection"; protection.IsEnabled = !session.ReadOnly;
            protection.Click += delegate { OpenSystemUtility("SystemPropertiesProtection.exe"); }; controls.Children.Add(protection); safety.Children.Add(controls);
            var checkpoint = Theme.Card(safety); checkpoint.Background = Theme.Frost("#C2D3E8F9");
            // Keep the checkpoint action above variable-height hardware details.
            panel.Children.Insert(1, checkpoint);
            if (report == null)
                panel.Children.Add(Theme.Card(Theme.Text(session.SystemReadInProgress ? "Reading hardware in the background. You can browse other pages while Windows gathers the details; no settings are changed." : "Use Refresh state to collect CPU, GPU, memory, storage, networking, Windows and security details. This scan is read-only.", 13, Theme.Secondary, FontWeights.Normal)));
            else
            {
                panel.Children.Add(SectionTitle("Where you can improve", "These are checks to review, not changes applied automatically. Benefits depend on your workload."));
                var recommendations = report.Recommendations.OrderBy(r => r.Priority == "High" ? 0 : r.Priority == "Medium" ? 1 : 2).ToList();
                if (recommendations.Count == 0)
                    panel.Children.Add(Theme.Card(Theme.Text("No specific issue was detected in the available measurements. This is not a benchmark or a guarantee that every component is optimal.", 13, Theme.Secondary, FontWeights.Normal)));
                foreach (var recommendation in recommendations)
                {
                    var advice = new StackPanel();
                    var adviceHeading = new DockPanel();
                    var priority = Theme.Glass(Theme.Text(recommendation.Priority + " priority", 10, recommendation.Priority == "High" ? Theme.Error : Theme.Accent, FontWeights.SemiBold), new Thickness(9, 5, 9, 5), 7, false);
                    priority.Margin = new Thickness(12, 0, 0, 0); DockPanel.SetDock(priority, Dock.Right); adviceHeading.Children.Add(priority);
                    adviceHeading.Children.Add(Theme.Text(recommendation.Title, 16, Theme.Ink, FontWeights.SemiBold)); advice.Children.Add(adviceHeading);
                    var evidence = Theme.Text(recommendation.Evidence, 12, Theme.Secondary, FontWeights.Normal); evidence.Margin = new Thickness(0, 8, 0, 7); advice.Children.Add(evidence);
                    advice.Children.Add(Theme.Text(recommendation.Action, 13, Theme.Ink, FontWeights.Normal)); panel.Children.Add(Theme.Card(advice));
                }
                var optional = session.Catalog.Where(d =>
                {
                    TweakStatus status;
                    return d.Recommended && d.Risk == TweakRisk.Low && !d.SecurityTradeOff && !d.PerformanceUnproven && session.Statuses.TryGetValue(d.Id, out status) && !status.IsApplied;
                }).OrderByDescending(d => SupplementalCatalog.All.Any(extra => extra.Id == d.Id)).Take(8).ToList();
                if (optional.Count > 0)
                {
                    var adjustments = new StackPanel();
                    adjustments.Children.Add(Theme.Text("Small, reversible preferences", 17, Theme.Ink, FontWeights.SemiBold));
                    var note = Theme.Text("These low-risk preferences are not currently set to their target value. They are optional, not universal performance upgrades; review each description and caveat first.", 12, Theme.Secondary, FontWeights.Normal);
                    note.Margin = new Thickness(0, 8, 0, 11); adjustments.Children.Add(note);
                    foreach (var definition in optional)
                    {
                        string id = definition.Id;
                        var row = new Grid { Margin = new Thickness(0, 0, 0, 10) }; row.ColumnDefinitions.Add(new ColumnDefinition()); row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                        var label = Theme.Text(definition.Title + "\n" + definition.Category, 12, Theme.Ink, FontWeights.Normal); label.Margin = new Thickness(0, 0, 10, 0); row.Children.Add(label);
                        var review = Theme.Button("Review", false); review.Padding = new Thickness(12, 7, 12, 7); review.MinHeight = 33; review.Margin = new Thickness(0); Grid.SetColumn(review, 1);
                        review.Click += delegate { Navigate("Tweaks"); search.Text = id; }; row.Children.Add(review); adjustments.Children.Add(row);
                    }
                    panel.Children.Add(Theme.Card(adjustments));
                }
                panel.Children.Add(SectionTitle("Hardware & Windows inventory", "Measured at " + report.CapturedAt + ". Expand any section. Refresh to update transient readings."));
                foreach (var section in report.Sections)
                {
                    var facts = new StackPanel { Margin = new Thickness(0, 10, 0, 0) };
                    foreach (var fact in section.Facts)
                    {
                        var row = new Grid { Margin = new Thickness(0, 0, 0, 11) };
                        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(190) }); row.ColumnDefinitions.Add(new ColumnDefinition());
                        var label = Theme.Text(fact.Label, 12, Theme.Secondary, FontWeights.Normal); label.Margin = new Thickness(0, 0, 13, 0); row.Children.Add(label);
                        var value = Theme.Text(fact.Value, 12, Theme.Ink, FontWeights.Normal); value.ToolTip = fact.Value; Grid.SetColumn(value, 1); row.Children.Add(value); facts.Children.Add(row);
                    }
                    var expander = new Expander { Header = Theme.Text(section.Title + "  /  " + section.Facts.Count + " details", 15, Theme.Ink, FontWeights.SemiBold), Content = facts, IsExpanded = false };
                    panel.Children.Add(Theme.Card(expander));
                }
                if (report.Issues.Count > 0)
                {
                    var issues = Theme.Text(String.Join("\n", report.Issues), 12, Theme.Secondary, FontWeights.Normal);
                    panel.Children.Add(Theme.Card(new Expander { Header = Theme.Text("Unavailable or restricted readings", 15, Theme.Ink, FontWeights.SemiBold), Content = issues }));
                }
            }
            var fullReport = Theme.Button("Open full Windows System Information", false); fullReport.Name = "OpenWindowsSystemInformation"; fullReport.IsEnabled = !session.ReadOnly; fullReport.HorizontalAlignment = HorizontalAlignment.Left;
            fullReport.Click += delegate { OpenSystemUtility("msinfo32.exe"); }; panel.Children.Add(fullReport);
            var scope = Theme.Text("Windows does not reliably expose every temperature, fan speed, XMP profile or GPU memory figure through standard APIs. Unsupported readings stay unavailable. No sensor driver, benchmark or external lookup runs during this scan.", 11, Theme.Secondary, FontWeights.Normal);
            scope.Margin = new Thickness(0, 8, 0, 18); panel.Children.Add(scope);
            panel.Children.Add(BuildRestore());
            return Scroll(panel);
        }

        private UIElement SectionTitle(string title, string description)
        {
            var panel = new StackPanel { Margin = new Thickness(0, 8, 0, 16) };
            var heading = new DockPanel();
            var marker = new Border { Width = 3, Height = 18, CornerRadius = new CornerRadius(2), Background = Theme.Brush(Theme.Blue), Margin = new Thickness(0, 0, 10, 0), VerticalAlignment = VerticalAlignment.Center }; heading.Children.Add(marker);
            heading.Children.Add(Theme.Text(title, 19, Theme.Ink, FontWeights.SemiBold)); panel.Children.Add(heading);
            var note = Theme.Text(description, 12, Theme.Secondary, FontWeights.Normal); note.Margin = new Thickness(13, 6, 0, 0); panel.Children.Add(note); return panel;
        }

        private void OpenSystemUtility(string name)
        {
            if (session.ReadOnly) { Notify("Preview does not launch external Windows controls.", false); return; }
            if (name != "msinfo32.exe" && name != "SystemPropertiesProtection.exe") throw new ArgumentException("Unknown Windows system utility.");
            try
            {
                Process.Start(new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), name)) { UseShellExecute = true });
                Notify("Opened Windows controls. Astra did not change any settings.", true);
            }
            catch (Exception error) { Notify(error.Message, false); }
        }
    }
}
