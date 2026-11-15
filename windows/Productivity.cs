using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace TelexMini
{
    // Opt-in offline productivity tools. No key history is persisted.
    // TSV format is portable between macOS and Windows.
    internal static class Productivity
    {
        internal static string DirectoryPath {
            get {return EnglishLexicon.DirectoryPath;}
        }
        internal static string SnippetsPath {
            get {return Path.Combine(DirectoryPath,"snippets.tsv");}
        }
        internal static string ProfilesPath {
            get {return Path.Combine(DirectoryPath,"profiles.tsv");}
        }
        internal static string PortablePath(string name) {
            return Path.Combine(AppDomain.CurrentDomain.BaseDirectory,name);
        }
        static readonly string[] SymbolValues={
            "→","←","↑","↓","✓","✕","•","…","°","₫","©","®","™","±",
            "≠","≤","≥","∞","€","£","¥","—","–","♥","★","😊","👍","❤️"
        };
        internal static string[] Symbols {get {return (string[])SymbolValues.Clone();}}
        internal static IDictionary<string,string> ReadSnippets(string path=null)
        {
            var result=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
            string file=path ?? (File.Exists(SnippetsPath) ? SnippetsPath : PortablePath("snippets.tsv"));
            try {
                if(!File.Exists(file)) return result;
                foreach(string line in File.ReadAllLines(file,Encoding.UTF8)) {
                    if(line.StartsWith("#")) continue;
                    int tab=line.IndexOf('\t');
                    if(tab<1) continue;
                    string key=line.Substring(0,tab).Trim();
                    string value=line.Substring(tab+1);
                    if(key.Length<2 || key.Length>48 || value.Length>1024 ||
                       value.Contains("\t") || value.Contains("\r") || value.Contains("\n")) continue;
                    bool ok=true;
                    foreach(char c in key) if(!(c>='a'&&c<='z'||c>='A'&&c<='Z')) ok=false;
                    if(ok && value.Length>0) result[key]=value;
                    if(result.Count>=256) break;
                }
            } catch(IOException) {} catch(UnauthorizedAccessException) {}
            return result;
        }
        internal static IDictionary<string,string> ReadSnippetsFromText(string source)
        {
            var result=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
            foreach(string line in (source??"").Split(new[]{'\r','\n'},StringSplitOptions.RemoveEmptyEntries)) {
                if(line.StartsWith("#")) continue;
                int tab=line.IndexOf('\t');
                if(tab<=0) throw new FormatException("Gõ tắt phải phân cách bằng Tab.");
                string key=line.Substring(0,tab).Trim();
                string value=line.Substring(tab+1);
                if(key.Length<2 || key.Length>48 || value.Length==0 || value.Length>1024 ||
                   value.IndexOf('\t')>=0) throw new FormatException("Phím tắt hoặc nội dung không hợp lệ.");
                foreach(char c in key)
                    if(!(c>='a'&&c<='z'||c>='A'&&c<='Z'))
                        throw new FormatException("Phím tắt chỉ nhận chữ Latin a-z.");
                result[key]=value;
                if(result.Count>256) throw new FormatException("Tối đa 256 gõ tắt.");
            }
            return result;
        }
        internal static string ValidateProfiles(string content)
        {
            var result=new List<string>();
            foreach(string line in (content??"").Split(new[]{'\r','\n'},StringSplitOptions.RemoveEmptyEntries)) {
                if(line.StartsWith("#"))continue;
                var parts=line.Split('\t');
                if(parts.Length!=2)throw new FormatException("Profile phải có tên ứng dụng, Tab, chế độ.");
                string name=parts[0].Trim(),mode=parts[1].Trim();
                if(name.Length==0||name.Length>100 ||
                   (mode!="English"&&mode!="Vietnamese"&&mode!="Balanced"))
                    throw new FormatException("Profile chỉ nhận English/Vietnamese/Balanced.");
                foreach(char c in name) if(!(char.IsLetterOrDigit(c)||c=='-'||c=='_'||c=='.'))
                    throw new FormatException("Tên ứng dụng không hợp lệ.");
                result.Add(name+"\t"+mode);
                if(result.Count>200)throw new FormatException("Tối đa 200 ứng dụng.");
            }
            return string.Join(Environment.NewLine,result.ToArray());
        }
        internal static void SaveProfiles(string content) {
            Directory.CreateDirectory(DirectoryPath);
            string temp=ProfilesPath+".tmp";
            File.WriteAllText(temp,content,new UTF8Encoding(false));
            if(File.Exists(ProfilesPath)) File.Replace(temp,ProfilesPath,null);
            else File.Move(temp,ProfilesPath);
        }
        internal static string Expand(string raw,IDictionary<string,string> snippets,bool enabled,Func<string> clipboardProvider=null)
        {
            if(!enabled || raw==null || snippets==null) return null;
            string value;
            if(!snippets.TryGetValue(raw,out value)) return null;
            DateTime now=DateTime.Now;
            string result=value.Replace("{date}",now.ToString("yyyy-MM-dd"))
                               .Replace("{time}",now.ToString("HH:mm"))
                               .Replace("{datetime}",now.ToString("yyyy-MM-dd HH:mm"));
            // Clipboard is never inspected unless the user explicitly chose
            // the {clipboard} macro and triggers this exact shortcut in a
            // confirmed normal text field (Keyboard.cs enforces the context).
            if(result.Contains("{clipboard}")) {
                // The keyboard hook must not read the Windows clipboard.
                // Require a completed snapshot from the dedicated STA worker.
                if(clipboardProvider==null)return null;
                string content=clipboardProvider() ?? "";
                if(content.Length>1024) content=content.Substring(0,1024);
                content=content.Replace('\r',' ').Replace('\n',' ').Replace('\t',' ');
                result=result.Replace("{clipboard}",content);
            }
            // TSV persists escaped line breaks; expand only after the user
            // triggers the snippet. The cursor marker is interpreted by the
            // hook's safe, finite key-injection plan rather than persisted.
            return result.Replace("\\r\\n","\r\n").Replace("\\n","\r\n")
                         .Replace("\\t","\t");
        }
        internal static IDictionary<string,string> ParseProfiles(string lines)
        {
            var result=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
            if(string.IsNullOrEmpty(lines)) return result;
            foreach(string line in lines.Split(new[]{'\r','\n'},StringSplitOptions.RemoveEmptyEntries)) {
                int tab=line.IndexOf('\t');
                if(tab<=0 || line.IndexOf('\t',tab+1)>=0)continue;
                string name=line.Substring(0,tab).Trim();
                string mode=line.Substring(tab+1).Trim();
                if(name.EndsWith(".exe",StringComparison.OrdinalIgnoreCase))
                    name=name.Substring(0,name.Length-4);
                if(name.Length>0 && (mode=="English"||mode=="Vietnamese"||mode=="Balanced"))
                    result[name]=mode;
            }
            return result;
        }
        internal static string GetProfile(IDictionary<string,string> profiles,string process)
        {
            if(profiles==null || string.IsNullOrEmpty(process)) return "Default";
            string name=process.Trim();
            if(name.EndsWith(".exe",StringComparison.OrdinalIgnoreCase))
                name=name.Substring(0,name.Length-4);
            string mode;
            return profiles.TryGetValue(name,out mode)?mode:"Default";
        }
        internal static string GetProfile(string process,string lines)
        {
            if(string.IsNullOrEmpty(process) || string.IsNullOrEmpty(lines)) return "Default";
            string name=process.ToLowerInvariant().Trim();
            if(name.EndsWith(".exe")) name=name.Substring(0,name.Length-4);
            foreach(string line in lines.Split(new[]{'\r','\n'},StringSplitOptions.RemoveEmptyEntries)) {
                var cells=line.Split('\t');
                if(cells.Length!=2) continue;
                string app=cells[0].Trim().ToLowerInvariant();
                if(app.EndsWith(".exe")) app=app.Substring(0,app.Length-4);
                string mode=cells[1].Trim();
                if(app==name && (mode=="Vietnamese"||mode=="English"||mode=="Balanced"))
                    return mode;
            }
            return "Default";
        }
        internal static string ReadProfiles() {
            try {
                string path=File.Exists(ProfilesPath)?ProfilesPath:PortablePath("profiles.tsv");
                return File.Exists(path)?File.ReadAllText(path,Encoding.UTF8):"";
            } catch(IOException) {return "";} catch(UnauthorizedAccessException){return "";}
        }
        internal static string ProfileFor(string app) {
            return GetProfile(app,ReadProfiles());
        }
        internal static void SaveSnippets(IDictionary<string,string> snippets) {
            Directory.CreateDirectory(DirectoryPath);
            string temp=SnippetsPath+".tmp";
            using(var writer=new StreamWriter(temp,false,new UTF8Encoding(false))) {
                foreach(var pair in snippets) writer.WriteLine(pair.Key+"\t"+pair.Value);
            }
            if(File.Exists(SnippetsPath)) File.Replace(temp,SnippetsPath,null);
            else File.Move(temp,SnippetsPath);
        }
    }
}
