using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;
using Astra.Core.Infrastructure;
using Astra.Core.Models;
using Astra.Core.Services;
using Astra.Toolbox;

static class SnapshotFixture
{
    static void Assert(bool value, string label)
    {
        if (!value) throw new InvalidOperationException(label);
        Console.WriteLine("PASS: " + label);
    }
    static async Task Run(string root, string keyPath)
    {
        AppPaths.UseRoot(root);
        var log = new LogService();
        var engine = new TweakEngine(log, new AdminService(log));
        int index = 0;
        foreach (var original in SupplementalCatalog.All)
        {
            string name = "Fixture" + index;
            var kind = index == 0 ? RegistryValueKind.String : index == 1 ? RegistryValueKind.QWord : RegistryValueKind.DWord;
            object before = index == 0 ? (object)"original text" : index == 1 ? (object)1234567890123L : (object)19;
            using (var key = Registry.CurrentUser.CreateSubKey(keyPath))
            {
                key.SetValue("Unrelated", "keep", RegistryValueKind.String);
                if (index != 3) key.SetValue(name, before, kind);
            }
            var definition = new TweakDefinition
            {
                Id = original.Id, Title = original.Title, Description = "Isolated registry fixture", Category = original.Category,
                Kind = TweakKind.Registry, Risk = TweakRisk.Low, RequiresAdministrator = false,
                RegistryTargets = new[] { new RegistryTarget(RegistryHive.CurrentUser, keyPath, name, RegistryValueKind.DWord, 1, false) }
            };
            var applied = await engine.ApplyAsync(definition, CancellationToken.None);
            Assert(applied.Success && engine.HasBackup(definition.Id), original.Id + " saves a fixture backup");
            using (var key = Registry.CurrentUser.OpenSubKey(keyPath, true)) key.SetValue(name, 77, RegistryValueKind.DWord);
            Assert((await engine.ApplyAsync(definition, CancellationToken.None)).Success, original.Id + " supports reapplication");
            var restored = await engine.RevertAsync(definition, CancellationToken.None);
            Assert(restored.Success && !engine.HasBackup(definition.Id), original.Id + " consumes only its completed backup");
            using (var key = Registry.CurrentUser.OpenSubKey(keyPath))
            {
                Assert(index == 3 ? key.GetValue(name) == null : Object.Equals(key.GetValue(name), before) && key.GetValueKind(name) == kind, original.Id + " restores exact existence, type and first value");
                Assert((string)key.GetValue("Unrelated") == "keep", "unrelated fixture value preserved");
            }
            index++;
        }
        Assert(engine.GetBackups().Count == 0, "all isolated snapshots completed");
    }
    static int Main(string[] args)
    {
        string keyPath = @"Software\AstraToolboxFixture\" + Guid.NewGuid().ToString("N");
        try { Run(args[0], keyPath).GetAwaiter().GetResult(); Console.WriteLine("Snapshot fixtures passed; no production registry keys were targeted."); return 0; }
        catch (Exception error) { Console.Error.WriteLine(error); return 1; }
        finally { Registry.CurrentUser.DeleteSubKeyTree(keyPath, false); }
    }
}
