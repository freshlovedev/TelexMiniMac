using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;

namespace TelexMini
{
    // Pure offline transformations. No clipboard access or background history.
    internal enum TextOperation { Nfc, RemoveMarks, Upper, Lower, Title, TrimSpaces, Sentence, Markdown }
    internal static class TextTransforms
    {
        internal static string Apply(string value, TextOperation mode)
        {
            value = (value ?? "").Normalize(NormalizationForm.FormC);
            switch(mode) {
                case TextOperation.Nfc: return value;
                case TextOperation.RemoveMarks: return RemoveMarks(value);
                case TextOperation.Upper: return value.ToUpperInvariant();
                case TextOperation.Lower: return value.ToLowerInvariant();
                case TextOperation.Title: return CultureInfo.GetCultureInfo("vi-VN").TextInfo.ToTitleCase(value.ToLowerInvariant());
                case TextOperation.TrimSpaces: return CleanSpaces(value);
                case TextOperation.Sentence: return SentenceCase(value);
                case TextOperation.Markdown: return ToMarkdown(value);
                default: return value;
            }
        }
        internal static string RemoveMarks(string input)
        {
            var builder = new StringBuilder(input.Length);
            foreach(char character in input.Normalize(NormalizationForm.FormD)) {
                var category=CharUnicodeInfo.GetUnicodeCategory(character);
                if(category==UnicodeCategory.NonSpacingMark ||
                   category==UnicodeCategory.SpacingCombiningMark ||
                   category==UnicodeCategory.EnclosingMark)continue;
                builder.Append(character=='đ'?'d':character=='Đ'?'D':character);
            }
            return builder.ToString().Normalize(NormalizationForm.FormC);
        }
        internal static string CleanSpaces(string input)
        {
            var lines=input.Replace("\r\n","\n").Replace('\r','\n').Split('\n');
            for(int i=0;i<lines.Length;i++) {
                var line=lines[i].Trim();
                var result=new StringBuilder(line.Length);
                bool previousSpace=false;
                foreach(char c in line) {
                    if(c==' ' || c=='\t') {
                        if(!previousSpace)result.Append(' ');
                        previousSpace=true;
                    } else { result.Append(c);previousSpace=false; }
                }
                lines[i]=result.ToString();
            }
            return string.Join(Environment.NewLine,lines);
        }
        internal static string SentenceCase(string input)
        {
            var result=new StringBuilder(input.Length);
            bool upper=true;
            foreach(char c in input) {
                result.Append(char.IsLetter(c) && upper?char.ToUpperInvariant(c):c);
                if(char.IsLetter(c))upper=false;
                if(c=='.' || c=='!' || c=='?' || c=='\n')upper=true;
            }
            return result.ToString();
        }
        internal static string ToMarkdown(string input)
        {
            var lines=CleanSpaces(input).Split(new[]{Environment.NewLine},StringSplitOptions.None);
            var result=new StringBuilder();
            foreach(var line in lines) {
                string text=line.Trim();
                if(text.Length==0){result.AppendLine();continue;}
                if((text.StartsWith("• ") || text.StartsWith("· ") || text.StartsWith("- ")))
                    result.Append("- ").AppendLine(text.Substring(2));
                else result.AppendLine(text);
            }
            return result.ToString().TrimEnd('\r','\n');
        }
    }

    // Exact one-word repair, bound to the actual focused HWND and the last
    // inserted SPACE. It does not inspect arbitrary user documents.
    internal sealed class WordRepair
    {
        string original,displayed;
        IntPtr window,focus;
        internal void Clear(){original=null;displayed=null;window=IntPtr.Zero;focus=IntPtr.Zero;}
        internal bool Arm(string raw,string converted,IntPtr win,IntPtr control)
        {
            Clear();
            if(string.IsNullOrEmpty(raw)||string.IsNullOrEmpty(converted)||
               raw==converted || raw.Length>48 || converted.Length>48 ||
               win==IntPtr.Zero || control==IntPtr.Zero)return false;
            if(!raw.All(c=>c>='a'&&c<='z'||c>='A'&&c<='Z'))return false;
            original=raw;displayed=converted;window=win;focus=control;
            return true;
        }
        internal bool TryPlan(IntPtr win,IntPtr control,out int erase,out string insertion,out string restored)
        {
            erase=0;insertion=null;restored=null;
            if(original==null || win!=window || control!=focus){Clear();return false;}
            erase=displayed.Length+1;
            insertion=original+" ";
            restored=original;
            return Native.IsSafeEditSize(erase,insertion.Length,false);
        }
        internal string Original { get{return original;} }
        internal void ClearAfterRepair(){Clear();}
    }

    // Offline adaptive learning is explicit opt-in AND triggered only by the
    // user's repair shortcut. No background key logging or automatic corpus.
    internal static class AdaptiveDictionary
    {
        static readonly object gate=new object();
        internal static bool Valid(string raw)
        {
            return !string.IsNullOrEmpty(raw) && raw.Length>=2 && raw.Length<=48 &&
                   raw.All(c=>c>='a'&&c<='z'||c>='A'&&c<='Z');
        }
        internal static void QueueConfirmedEnglish(string raw)
        {
            if(!Valid(raw))return;
            string value=raw.ToLowerInvariant();
            ThreadPool.QueueUserWorkItem(_ => {
                lock(gate) {
                    try {
                        string path=EnglishLexicon.EnglishPath;
                        Directory.CreateDirectory(Path.GetDirectoryName(path));
                        var words=new HashSet<string>(StringComparer.Ordinal);
                        if(File.Exists(path))
                            foreach(var word in File.ReadAllLines(path,Encoding.UTF8))
                                if(Valid(word.Trim()))words.Add(word.Trim().ToLowerInvariant());
                        if(words.Contains(value) || words.Count>=5000)return;
                        words.Add(value);
                        string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
                        try {
                            File.WriteAllLines(temp,words.OrderBy(x=>x,StringComparer.Ordinal),new UTF8Encoding(false));
                            if(File.Exists(path))File.Replace(temp,path,null);
                            else File.Move(temp,path);
                            File.WriteAllText(Path.Combine(EnglishLexicon.DirectoryPath,
                                "dictionary-reload.flag"),DateTime.UtcNow.Ticks.ToString(CultureInfo.InvariantCulture));
                        } finally {if(File.Exists(temp))File.Delete(temp);}
                    } catch(IOException) {} catch(UnauthorizedAccessException) {}
                }
            });
        }
    }
}
