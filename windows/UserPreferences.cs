using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace TelexMini
{
    // Portable mode is an explicit opt-in marker beside the executable.
    // Data is isolated under Data/ and never silently migrated or deleted.
    internal static class AppStorage {
        internal static string ExeDirectory {get {return AppDomain.CurrentDomain.BaseDirectory;}}
        internal static bool IsPortable {get {return File.Exists(Path.Combine(ExeDirectory,"portable.flag"));}}
        internal static string ResolveDirectory(string exeDirectory,string localDirectory,bool portable) {
            return portable?Path.Combine(exeDirectory,"Data"):Path.Combine(localDirectory,"TelexMini");
        }
        internal static string DirectoryPath {
            get { return ResolveDirectory(ExeDirectory,
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                IsPortable); }
        }
        internal static void EnablePortable() {
            string dest=Path.Combine(ExeDirectory,"Data");
            Directory.CreateDirectory(dest);
            string current=DirectoryPath;
            foreach(string filename in new[]{"preferences.ini","EnglishWords.txt","VietnameseOverrides.txt","snippets.tsv","profiles.tsv"}) {
                string src=Path.Combine(current,filename),target=Path.Combine(dest,filename);
                if(File.Exists(src) && !File.Exists(target)) File.Copy(src,target,false);
            }
            File.WriteAllText(Path.Combine(ExeDirectory,"portable.flag"),
                "TelexMini portable profile. Restart the app to activate.\n");
        }
        internal static void DisablePortable() {
            string dest=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"TelexMini");
            Directory.CreateDirectory(dest);
            string current=DirectoryPath;
            foreach(string filename in new[]{"preferences.ini","EnglishWords.txt","VietnameseOverrides.txt","snippets.tsv","profiles.tsv"}) {
                string src=Path.Combine(current,filename),target=Path.Combine(dest,filename);
                if(File.Exists(src)) File.Copy(src,target,true);
            }
            File.Delete(Path.Combine(ExeDirectory,"portable.flag"));
        }
    }

    // User settings only. No keystrokes, text history, or passwords are written to disk.
    // Flutter's Windows runner updates this same file; the native input engine
    // notices the atomic replacement and applies the new settings without restart.
    internal static class UserPreferences
    {
        static readonly object gate=new object();
        static readonly Dictionary<string,string> values=Load();
        static DateTime lastWriteUtc=FileStamp();

        internal static string FilePath {
            get { return Path.Combine(AppStorage.DirectoryPath,"preferences.ini"); }
        }
        static DateTime FileStamp() {
            try {return File.Exists(FilePath)?File.GetLastWriteTimeUtc(FilePath):DateTime.MinValue;}
            catch(Exception) {return DateTime.MinValue;}
        }
        static Dictionary<string,string> Load() {
            var v=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
            try {
                if(File.Exists(FilePath)) foreach(string line in File.ReadAllLines(FilePath,Encoding.UTF8)) {
                    int index=line.IndexOf('=');
                    if(index>0) v[line.Substring(0,index).Trim()]=line.Substring(index+1).Trim();
                }
            } catch(IOException) {} catch(UnauthorizedAccessException) {}
            return v;
        }
        internal static bool ReloadIfChanged() {
            DateTime stamp=FileStamp();
            lock(gate) if(stamp==lastWriteUtc)return false;
            var fresh=Load();
            lock(gate) {
                values.Clear();
                foreach(var entry in fresh)values[entry.Key]=entry.Value;
                lastWriteUtc=stamp;
            }
            return true;
        }
        internal static bool Bool(string key,bool fallback) {
            lock(gate) {
                string value;
                return values.TryGetValue(key,out value) ?
                    (value=="true"?true:value=="false"?false:fallback) : fallback;
            }
        }
        internal static string String(string key,string fallback) {
            lock(gate) {
                string value;
                return values.TryGetValue(key,out value)?value:fallback;
            }
        }
        internal static void Set(string key,bool value) {Set(key,value?"true":"false");}
        internal static void Set(string key,string value) {
            lock(gate) values[key]=value??"";
            Save();
        }
        internal static void Reload() {
            var fresh=Load();
            lock(gate) {
                values.Clear();
                foreach(var entry in fresh)values[entry.Key]=entry.Value;
                lastWriteUtc=FileStamp();
            }
        }
        static void Save() {
            try {
                string folder=Path.GetDirectoryName(FilePath);
                Directory.CreateDirectory(folder);
                string[] rows;
                lock(gate) {
                    var list=new List<string>();
                    foreach(var item in values)list.Add(item.Key+"="+item.Value);
                    rows=list.ToArray();
                }
                string temp=FilePath+".tmp";
                File.WriteAllLines(temp,rows,new UTF8Encoding(false));
                if(File.Exists(FilePath))File.Replace(temp,FilePath,null);
                else File.Move(temp,FilePath);
                lock(gate)lastWriteUtc=FileStamp();
            } catch(IOException) {} catch(UnauthorizedAccessException) {} catch(PlatformNotSupportedException) {}
        }
    }
}
