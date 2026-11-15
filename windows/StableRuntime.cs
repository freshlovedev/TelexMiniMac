using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

namespace TelexMini
{
    // The shell remembers notification icons by application identity and path.
    // A release extracted into a different build folder must NOT run from that
    // folder, otherwise Windows creates another "TelexMini.exe" Taskbar entry.
    // The user-local installation needs no UAC and is shared by all releases.
    internal static class StableRuntime
    {
        const string InstallMutex = @"Local\TelexMini.Install.v1";
        const string EngineMutex = @"Local\TelexMini.Portable.v1";
        const string AppId = "com.telexmini.desktop";
        internal const string UpgradeEventName = @"Local\TelexMini.UpgradeRequest.v1";
        const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

        [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
        static extern int SetCurrentProcessExplicitAppUserModelID(string appId);

        internal static string InstallDirectory {
            get {
                return Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Programs", "TelexMini");
            }
        }

        internal static void SetShellIdentity()
        {
            try { SetCurrentProcessExplicitAppUserModelID(AppId); }
            catch(EntryPointNotFoundException) {}
            catch(DllNotFoundException) {}
        }

        static bool AnEngineIsRunning()
        {
            using(var single=new Mutex(false,EngineMutex)) {
                try {
                    if(!single.WaitOne(0)) return true;
                    single.ReleaseMutex();
                    return false;
                } catch(AbandonedMutexException) {
                    single.ReleaseMutex();
                    return false;
                }
            }
        }

        internal static void CopyBundle(string source,string dest)
        {
            foreach(string folder in Directory.GetDirectories(source,"*",SearchOption.AllDirectories)) {
                string relative=folder.Substring(source.Length).TrimStart(Path.DirectorySeparatorChar);
                // Flutter stores executable assets under data/flutter_assets.
                // Never skip the bundle's Data directory. User preferences
                // are already stored separately in LocalAppData/TelexMini.
                Directory.CreateDirectory(Path.Combine(dest,relative));
            }
            foreach(string file in Directory.GetFiles(source,"*",SearchOption.AllDirectories)) {
                string relative=file.Substring(source.Length).TrimStart(Path.DirectorySeparatorChar);
                if(relative.Equals("portable.flag",StringComparison.OrdinalIgnoreCase))
                    continue;
                string target=Path.Combine(dest,relative);
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                File.Copy(file,target,true);
            }
        }

        static bool SettingsIsRunningFrom(string folder)
        {
            foreach(var settings in Process.GetProcessesByName("TelexMiniSettings")) {
                using(settings) {
                    try {
                        string executable=settings.MainModule.FileName;
                        if(string.Equals(Path.GetDirectoryName(executable),folder,
                            StringComparison.OrdinalIgnoreCase))return true;
                    } catch(System.ComponentModel.Win32Exception) {}
                      catch(InvalidOperationException) {}
                      catch(System.Security.SecurityException) {}
                }
            }
            return false;
        }

        static void StopEngineForUpgrade(string installed)
        {
            if(SettingsIsRunningFrom(installed))
                throw new IOException("Close the TelexMini Settings window before upgrading. Your edits will be preserved by the running version until you close it.");
            if(!AnEngineIsRunning())return;
            // Only the TelexMini tray engine created this per-user event.
            // The old version must exit cleanly to release its DLL and HWND;
            // never kill another process or request administrator privileges.
            try {
                using(var signal=EventWaitHandle.OpenExisting(UpgradeEventName))signal.Set();
            } catch(WaitHandleCannotBeOpenedException) {
                throw new IOException("Please exit the previous TelexMini tray icon once, then launch this update again.");
            }
            DateTime deadline=DateTime.UtcNow.AddSeconds(10);
            while(DateTime.UtcNow<deadline && AnEngineIsRunning())Thread.Sleep(60);
            if(AnEngineIsRunning())
                throw new IOException("The previous TelexMini is still running. Exit it from the system tray and retry.");
        }

        static void MigrateAutoStart(string installedExe)
        {
            try {
                using(var registry=Registry.CurrentUser.OpenSubKey(RunKey,true)) {
                    if(registry==null || registry.GetValue("TelexMini")==null) return;
                    // Preserve the user's choice to auto-start; only repair its
                    // target so it cannot relaunch an obsolete build directory.
                    registry.SetValue("TelexMini","\""+installedExe+"\"",RegistryValueKind.String);
                }
            } catch(System.Security.SecurityException) {}
              catch(UnauthorizedAccessException) {}
        }

        internal static bool RedirectIfNeeded()
        {
            string source=Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory)
                              .TrimEnd(Path.DirectorySeparatorChar);
            string installed=Path.GetFullPath(InstallDirectory)
                                 .TrimEnd(Path.DirectorySeparatorChar);
            if(string.Equals(source,installed,StringComparison.OrdinalIgnoreCase) ||
               File.Exists(Path.Combine(source,"portable.flag")) ||
               !File.Exists(Path.Combine(source,"TelexMiniSettings.exe")) ||
               !File.Exists(Path.Combine(source,"TelexMiniEngine.dll")))
                return false;

            // Avoid racing two launchers and never overwrite a running build.
            using(var gate=new Mutex(false,InstallMutex)) {
                bool owns=false;
                try {
                    try { owns=gate.WaitOne(TimeSpan.FromSeconds(10)); }
                    catch(AbandonedMutexException) {owns=true;}
                    if(!owns) throw new IOException("Another TelexMini installation is in progress.");
                    // Upgrades cannot merely activate the old singleton: that
                    // leaves the newly extracted ZIP unapplied indefinitely.
                    // Complete a clean handoff before touching installed files.
                    StopEngineForUpgrade(installed);

                    string parent=Path.GetDirectoryName(installed);
                    Directory.CreateDirectory(parent);
                    string staging=Path.Combine(parent,"TelexMini.stage."+Guid.NewGuid().ToString("N"));
                    string backup=Path.Combine(parent,"TelexMini.backup."+Guid.NewGuid().ToString("N"));
                    bool backedUp=false;
                    bool installedNew=false;
                    try {
                        Directory.CreateDirectory(staging);
                        CopyBundle(source,staging);
                        if(!File.Exists(Path.Combine(staging,"TelexMini.exe")) ||
                           !File.Exists(Path.Combine(staging,"TelexMiniSettings.exe")))
                            throw new IOException("Incomplete TelexMini package.");

                        if(Directory.Exists(installed)) {
                            Directory.Move(installed,backup);
                            backedUp=true;
                        }
                        Directory.Move(staging,installed);
                        installedNew=true;
                        string exe=Path.Combine(installed,"TelexMini.exe");
                        MigrateAutoStart(exe);
                        using(var launched=Process.Start(new ProcessStartInfo(exe) {
                            WorkingDirectory=installed, UseShellExecute=false
                        })) {
                            if(launched==null)
                                throw new IOException("Cannot start the updated TelexMini executable.");
                        }
                        // Hold the installer gate until the canonical engine
                        // owns its singleton. Simultaneous launches cannot
                        // race to install and display multiple tray identities.
                        DateTime deadline=DateTime.UtcNow.AddSeconds(5);
                        while(DateTime.UtcNow<deadline && !AnEngineIsRunning())
                            Thread.Sleep(50);
                        if(!AnEngineIsRunning())
                            throw new IOException("The updated TelexMini did not acquire its tray mutex; restoring the previous release.");
                        // Do not create a tray icon in this temporary copy.
                        return true;
                    } catch {
                        if(installedNew && Directory.Exists(installed))
                            Directory.Delete(installed,true);
                        if(backedUp && Directory.Exists(backup) &&
                           !Directory.Exists(installed))
                            Directory.Move(backup,installed);
                        throw;
                    } finally {
                        try {if(Directory.Exists(staging))Directory.Delete(staging,true);}
                        catch(IOException) {}
                        try {if(backedUp && Directory.Exists(backup))Directory.Delete(backup,true);}
                        catch(IOException) {}
                    }
                } catch(Exception error) {
                    MessageBox.Show("Cannot start TelexMini from a new release folder. "+
                        "The previous installation has been kept where possible.\n"+
                        error.Message+"\n\nTo run without installing, create portable.flag beside TelexMini.exe.",
                        "TelexMini",MessageBoxButtons.OK,MessageBoxIcon.Error);
                    return true; // Never register a new tray identity on failure.
                } finally {
                    if(owns) gate.ReleaseMutex();
                }
            }
        }
    }
}
