using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;
using System.Reflection;
[assembly: AssemblyTitle("Astra Toolbox")]
[assembly: AssemblyProduct("Astra Toolbox")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]
static class Launcher
{
    static string Quote(string value)
    {
        var result = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in value)
        {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') { result.Append('\\', slashes * 2 + 1); result.Append(c); }
            else { result.Append('\\', slashes); result.Append(c); }
            slashes = 0;
        }
        result.Append('\\', slashes * 2); result.Append('"');
        return result.ToString();
    }
    [STAThread]
    static int Main(string[] args)
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string dotnet = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "dotnet", "dotnet.exe");
        string app = Path.Combine(dir, "Toolbox.dll");
        bool cli = args.Length > 0 && args[0] != "--preview" && args[0] != "--self-test";
        try
        {
            string desktop = Path.Combine(Path.GetDirectoryName(dotnet), "shared", "Microsoft.WindowsDesktop.App");
            if (!File.Exists(dotnet) || !Directory.Exists(desktop) || Directory.GetDirectories(desktop, "8.*").Length == 0)
                throw new InvalidOperationException("Install .NET Desktop Runtime 8 x64 from the playbook's bundled Redist folder, then reopen Astra Toolbox.");
            if (!File.Exists(app)) throw new FileNotFoundException("Keep Astra-Toolbox.exe with Toolbox.dll, Astra.Core.dll, Assets and Wallpapers. Extract the whole toolbox ZIP first.");
            var psi = new ProcessStartInfo(dotnet);
            psi.Arguments = Quote(app);
            foreach (string arg in args) psi.Arguments += " " + Quote(arg);
            psi.WorkingDirectory = dir;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            if (cli) { psi.RedirectStandardOutput = true; psi.RedirectStandardError = true; }
            using (Process process = Process.Start(psi))
            {
                if (!cli) { process.WaitForExit(); return process.ExitCode; }
                var stdout = process.StandardOutput.ReadToEndAsync();
                var stderr = process.StandardError.ReadToEndAsync();
                process.WaitForExit();
                string logDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AstraPC", "Logs");
                Directory.CreateDirectory(logDir);
                File.AppendAllText(Path.Combine(logDir, "toolbox-cli.log"), DateTime.Now.ToString("s") + " exit=" + process.ExitCode + Environment.NewLine + stdout.Result + stderr.Result);
                return process.ExitCode;
            }
        }
        catch (Exception ex)
        {
            if (!cli) MessageBox.Show(ex.Message, "Astra Toolbox", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return 1;
        }
    }
}
