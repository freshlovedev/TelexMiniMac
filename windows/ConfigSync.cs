using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace TelexMini
{
    // Portable configuration schema shared with the macOS Settings app.
    // Never includes paths, passwords, recent text, or private identifiers.
    internal static class ConfigSync
    {
        internal const string FileName="telexmini-sync.tsv";
        static readonly string[] Keys={
            "InputMethod","LanguagePriority","SmartEnglish","RestoreInvalid",
            "SnippetsEnabled","ProfilesEnabled","DarkTheme","UILanguage"
        };
        internal static bool Allowed(string key,string value)
        {
            if(key=="InputMethod")return value=="Telex"||value=="VNI";
            if(key=="LanguagePriority")return value=="Vietnamese"||value=="Balanced"||value=="English";
            if(key=="UILanguage")return value=="vi"||value=="en";
            if(key=="SmartEnglish"||key=="RestoreInvalid"||key=="SnippetsEnabled"||
               key=="ProfilesEnabled"||key=="DarkTheme")return value=="true"||value=="false";
            return false;
        }
        internal static IDictionary<string,string> Parse(string content)
        {
            var results=new Dictionary<string,string>(StringComparer.Ordinal);
            foreach(string line in (content??"").Split(new[]{'\n'},StringSplitOptions.RemoveEmptyEntries)) {
                if(line.StartsWith("#")||line=="TelexMini-Sync\t1")continue;
                string[] parts=line.TrimEnd('\r').Split('\t');
                if(parts.Length==2 && Allowed(parts[0],parts[1]))results[parts[0]]=parts[1];
            }
            return results;
        }
        internal static string Export()
        {
            var lines=new List<string> {"TelexMini-Sync\t1"};
            foreach(string key in Keys) {
                string value=UserPreferences.String(key,
                    key=="InputMethod"?"Telex":key=="LanguagePriority"?"Balanced":
                    key=="UILanguage"?"vi":
                    (key=="SmartEnglish"||key=="RestoreInvalid"||key=="DarkTheme")?"true":"false");
                if(Allowed(key,value))lines.Add(key+"\t"+value);
            }
            return string.Join("\n",lines.ToArray())+"\n";
        }
        internal static void Import(string content)
        {
            foreach(var item in Parse(content))UserPreferences.Set(item.Key,item.Value);
        }
        internal static void WriteTo(string folder)
        {
            File.WriteAllText(Path.Combine(folder,FileName),Export(),new UTF8Encoding(false));
        }
        internal static void ReadFrom(string folder)
        {
            string path=Path.Combine(folder,FileName);
            if(File.Exists(path))Import(File.ReadAllText(path,Encoding.UTF8));
        }
    }
}
