using System;

namespace TelexMini
{
    // Offline, deterministic bilingual regression corpus. Every result is a
    // known expected output, not merely the result of another implementation.
    internal static class BilingualCorpus
    {
        static readonly string[] English = {
            "boost","parameter","download","setup","exe","hello","world",
            "book","books","good","browser","github","terminal","keyboard",
            "code","source","project","process","window","input","escape",
            "restore","backup","video","youtube","worker","computer",
            "document","office","offline","website","software","system",
            "now","world","window","how","snow"
        };
        static readonly string[][] Vietnamese = {
            new[]{"tieengs","tiếng"},new[]{"chayj","chạy"},
            new[]{"kieeru","kiểu"},new[]{"boons","bốn"},
            new[]{"truowngf","trường"},new[]{"nguowif","người"},
            new[]{"toasn","toán"},new[]{"ddang","đang"},
            new[]{"been","bên"},new[]{"as","á"},
            new[]{"eex","ễ"},new[]{"chuoong","chuông"},
            new[]{"w","ư"},new[]{"ow","ơ"},new[]{"now","nơ"},
            new[]{"aw","ă"},new[]{"uw","ư"},new[]{"nuw","nư"}
        };
        static readonly string[][] Balanced = {
            new[]{"boost","boost"},new[]{"been","bên"},
            new[]{"parameter","parameter"},new[]{"download","download"},
            new[]{"exe","exe"},new[]{"books","books"},
            new[]{"good","good"},new[]{"ass","as"},
            new[]{"boosst","boost"},new[]{"tieengs","tiếng"},
            new[]{"chayj","chạy"},new[]{"kieeru","kiểu"},
            new[]{"w","ư"},new[]{"now","nơ"},new[]{"noww","now"},
            new[]{"nuw","nư"},new[]{"uow","ươ"}
        };
        static string Compose(string typed,bool smart,bool preferEnglish,bool vni=false) {
            var engine=new TelexEngine {
                SmartEnglish=smart,PreferEnglishExact=preferEnglish,UseVni=vni
            };
            foreach(char key in typed)engine.Push(key);
            return engine.Finish(true);
        }
        internal static int Run(Action<string,string,string> check)
        {
            int cases=0;
            // Repeat across 16 passes to expose accidentally shared composer
            // state, dictionary mutation, and profile-independent exceptions.
            for(int pass=0;pass<16;pass++) {
                foreach(string word in English) {
                    check("English3 "+pass+" "+word,"True",
                          EnglishLexicon.IsKnownEnglishWord(word).ToString());
                    check("English-first3 "+pass+" "+word,word,
                          Compose(word,true,true));
                    cases+=2;
                }
                foreach(var row in Vietnamese) {
                    check("Vietnamese3 "+pass+" "+row[0],row[1],
                          Compose(row[0],false,false));
                    cases++;
                }
                foreach(var row in Balanced) {
                    check("Balanced3 "+pass+" "+row[0],row[1],
                          Compose(row[0],true,false));
                    cases++;
                }
            }
            // Uppercase word lookups must not allocate in the ASCII lowercase
            // hot path, and must still honor case-insensitive dictionaries.
            foreach(string word in English) {
                check("English dictionary case3 "+word,"True",
                    EnglishLexicon.IsKnownEnglishWord(word.ToUpperInvariant()).ToString());
                cases++;
            }
            return cases;
        }
    }
}
