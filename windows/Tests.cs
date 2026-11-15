using System;
using System.Drawing;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

namespace TelexMini
{
    internal static class Tests
    {
        [DllImport("user32.dll")] static extern IntPtr GetKeyboardLayout(uint thread);
        [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern IntPtr LoadKeyboardLayout(string name,uint flags);
        [DllImport("user32.dll")] static extern IntPtr ActivateKeyboardLayout(IntPtr layout,uint flags);
        static int failures;
        static readonly string[,] Cases = {
            {"tieengs","tiếng"}, {"Vieetj","Việt"}, {"chaof","chào"}, {"ddawng","đăng"},
            {"ddaas","đấ"}, {"truowngf","trường"}, {"nguowif","người"}, {"duwowngf","dường"},
            {"hoaf","hoà"}, {"khoer","khoẻ"}, {"thuys","thuý"}, {"quas","quá"},
            {"quys","quý"}, {"gias","giá"}, {"gif","gì"}, {"gins","gín"},
            {"muoons","muốn"}, {"tieesng","tiếng"}, {"tieesngz","tiêng"},
            {"ass","as"}, {"aaa","aa"}, {"eee","ee"}, {"ooo","oo"}, {"ddd","dd"},
            {"aww","aw"}, {"uww","uw"}, {"oww","ow"}, {"uoww","uow"},
            {"DDawNG","ĐăNG"}, {"TIEENGS","TIẾNG"}, {"aasf","ầ"}, {"asdf","àd"},
            {"toasn","toán"}, {"tuyeenr","tuyển"}, {"nguyeenx","nguyễn"},
            {"huowsng","hướng"}, {"ruouwj","rượu"}, {"khuyur","khuỷu"}, {"cuwus","cứu"},
            {"yeeus","yếu"}, {"quoocs","quốc"}, {"giaan","giân"}, {"duongdwf","đường"},
            {"ddoojng","động"}, {"caamr","cẩm"}, {"cawsn","cắn"}, {"tuwj","tự"},
            {"nhowx","nhỡ"}, {"vieecj","việc"}, {"nguowis","ngưới"},
            {"esscape","escape"}, {"esscapes","escapes"}, {"asssets","assets"},
            {"offfice","office"}, {"eeeror","eeror"}, {"dddriver","ddriver"},
            {"owwword","owword"}, {"uowwword","uowword"}, {"ESSCAPE","ESCAPE"},
            {"chayj","chạy"}, {"chajy","chạy"},
            {"kieeur","kiểu"}, {"kieeru","kiểu"},
            {"nhieeuf","nhiều"}, {"nhieefu","nhiều"},
            {"vaayj","vậy"}, {"vaajy","vậy"},
            {"yeeus","yếu"}, {"yeesu","yếu"},
            {"nguowif","người"}, {"nguowfi","người"},
            {"muoons","muốn"}, {"muoosn","muốn"},
            {"tuyeenr","tuyển"}, {"tuyeern","tuyển"},
            {"vieecj","việc"}, {"vieejc","việc"},
            {"duongdwf","đường"}, {"duongdfw","đường"},
            {"ngoais","ngoái"}, {"ngoasi","ngoái"}
        };
        static void Equal(string label,string expected,string actual)
        {
            bool pass=expected==actual;
            Console.WriteLine((pass ? "PASS " : "FAIL ")+label+" => "+actual+(pass ? "" : " (expected "+expected+")"));
            if(!pass) failures++;
        }
        [STAThread] static int Main(string[] args)
        {
            Console.OutputEncoding=System.Text.Encoding.UTF8;
            string oracle=Path.Combine(Environment.CurrentDirectory,"telex-corpus.tsv");
            if(!File.Exists(oracle)) {
                failures++;Console.WriteLine("FAIL missing shared Telex oracle: "+oracle);
            } else {
                int checkedRows=0;
                foreach(string line in File.ReadAllLines(oracle,System.Text.Encoding.UTF8)) {
                    if(line.StartsWith("#") || line.StartsWith("raw\t") || line.Length==0) continue;
                    string[] columns=line.Split('\t');
                    if(columns.Length!=3) {failures++;continue;}
                    var engine=new TelexEngine {SmartEnglish=false,
                        UseVni=columns[2]=="vni"};
                    // Exercise the SAME prefix/tail edit plan as the live
                    // Windows hook against an isolated scratch text field.
                    string field="prefix ";
                    foreach(char c in columns[0]) {
                        string before=engine.Text, after=engine.Push(c);
                        TextEditPlan plan=TextEditPlan.Between(before,after);
                        field=plan.Apply(field);
                        if(field!="prefix "+after) {
                            failures++;Console.WriteLine("FAIL edit-plan oracle "+columns[0]);
                            break;
                        }
                    }
                    string finished=engine.Finish(true);
                    field=TextEditPlan.Between(engine.Text,finished).Apply(field);
                    if(field!="prefix "+finished) {
                        failures++;Console.WriteLine("FAIL edit-plan boundary "+columns[0]);
                    }
                    if(engine.Text!=columns[1] || finished!=columns[1]) {
                        failures++;Console.WriteLine("FAIL oracle "+columns[0]+" => "+
                            engine.Text+" / "+engine.Finish(true)+" (expected "+columns[1]+")");
                    }
                    checkedRows++;
                }
                if(checkedRows<4500) failures++;
                Console.WriteLine("Independent Telex/VNI Unicode oracle: "+checkedRows+" cases");
            }
            for(int i=0;i<Cases.GetLength(0);i++) {
                var engine=new TelexEngine(); foreach(char c in Cases[i,0]) engine.Push(c);
                Equal(Cases[i,0],Cases[i,1],engine.Text);
                Equal("Finish "+Cases[i,0],Cases[i,0]=="asdf" ? "asdf" : Cases[i,1],engine.Finish(true));
            }
            // Test replacement, suffix deletion, append, literal escape and
            // boundary restoration without interacting with user documents.
            foreach(var row in new[] {
                new[]{"","á"},new[]{"abc","áb"},new[]{"tiếng","tiến"},
                new[]{"kiể","kiểu"},new[]{"bô","book"},new[]{"á","as"}
            }) {
                var editPlan=TextEditPlan.Between(row[0],row[1]);
                Equal("Edit plan "+row[0]+" => "+row[1],
                    "prefix "+row[1],editPlan.Apply("prefix "+row[0]));
            }
            // Simulated document input tests exercise typing, replacement,
            // Backspace, whitespace commits, and adjacent words together.
            ReplayScenario("kieeru nhieefu vaajy","kiểu nhiều vậy");
            ReplayScenario("xuosong chajy as","xuống chạy á");
            ReplayScenario("ass exe eex","as exe ễ");
            ReplayScenario("offfice parameter","office parameter");
            ReplayScenario("tieengs\bg","tiếng");
            ReplayScenario("boons beens","bốn bến");
            ReplayScenario("nguowfi tuyeern","người tuyển");
            ReplayScenario("kieeru\b u","kiể u");
            var snippets=Productivity.ReadSnippetsFromText("dc\tđược\nko\tkhông\n");
            Equal("Snippet explicit enabled","được",Productivity.Expand("dc",snippets,true));
            Equal("Snippet case insensitive","không",Productivity.Expand("KO",snippets,true));
            Equal("Snippet disabled",null,Productivity.Expand("dc",snippets,false));
            Equal("Snippet unknown",null,Productivity.Expand("nope",snippets,true));
            var dynamic=Productivity.ReadSnippetsFromText("today\t{date}\nclock\t{time}");
            Equal("Date snippet macro",DateTime.Now.ToString("yyyy-MM-dd"),
                Productivity.Expand("today",dynamic,true));
            Equal("Time snippet macro format","True",
                System.Text.RegularExpressions.Regex.IsMatch(
                    Productivity.Expand("clock",dynamic,true),@"^\d{2}:\d{2}$").ToString());
            Equal("Snippet bad format rejected","True",
                ThrowsFormat(delegate {Productivity.ReadSnippetsFromText("d\tđược");}).ToString());
            Equal("Snippet unsupported punctuation rejected","True",
                ThrowsFormat(delegate {Productivity.ReadSnippetsFromText("@@\temail");}).ToString());
            string profilesText=Productivity.ValidateProfiles("code.exe\tEnglish\nchrome.exe\tBalanced\nword.exe\tVietnamese");
            Equal("Application profile English","English",Productivity.GetProfile("code.exe",profilesText));
            Equal("Application profile Vietnamese","Vietnamese",Productivity.GetProfile("WORD",profilesText));
            Equal("Application profile default","Default",Productivity.GetProfile("notepad.exe",profilesText));
            Equal("Profile substring not matched","Default",Productivity.GetProfile("mycode.exe",profilesText));
            Equal("Bad profile rejected","True",
                ThrowsFormat(delegate {Productivity.ValidateProfiles("code.exe\tUnknown");}).ToString());
            Equal("Unicode quick symbols","True",Array.Exists(Productivity.Symbols,s=>s=="₫").ToString());
            string oldUiLanguage=UserPreferences.String("UILanguage","vi");
            UserPreferences.Set("UILanguage","en");
            Equal("English workspace label","WORKSPACE",UiText.T("KHÔNG GIAN"));
            Equal("English privacy label","PRIVATE BY DESIGN",UiText.T("RIÊNG TƯ"));
            Equal("English password label","PASSWORD PROTECTION",UiText.T("BẢO VỆ MẬT KHẨU"));
            Equal("English productivity nav","⚡  Snippets",UiText.T("⚡  Gõ tắt"));
            Equal("English light theme label","☀  Light",UiText.T("☀  Sáng"));
            Equal("English dark theme label","☾  Dark",UiText.T("☾  Tối"));
            UserPreferences.Set("UILanguage","vi");
            Equal("Vietnamese workspace label","KHÔNG GIAN",UiText.T("KHÔNG GIAN"));
            UserPreferences.Set("UILanguage",oldUiLanguage);
            bool oldDarkTheme=UserPreferences.Bool("DarkTheme",true);
            UserPreferences.Set("DarkTheme",false);
            Equal("Light page palette",Color.FromArgb(246,249,252).ToArgb().ToString(),UiPalette.Page.ToArgb().ToString());
            Equal("Light field palette",Color.FromArgb(241,246,250).ToArgb().ToString(),UiPalette.Field.ToArgb().ToString());
            UserPreferences.Set("DarkTheme",true);
            Equal("Dark page palette",Color.FromArgb(15,25,40).ToArgb().ToString(),UiPalette.Page.ToArgb().ToString());
            Equal("Dark field palette",Color.FromArgb(31,47,66).ToArgb().ToString(),UiPalette.Field.ToArgb().ToString());
            UserPreferences.Set("DarkTheme",oldDarkTheme);
            Equal("Spell suggestions typo","True",Array.Exists(SpellAdvisor.Suggest("kiễu"),s=>s=="kiểu").ToString());
            Equal("Spell suggestions no auto-replacement","0",SpellAdvisor.Suggest("").Length.ToString());
            var sync=ConfigSync.Parse("TelexMini-Sync\t1\nInputMethod\tVNI\nLanguagePriority\tEnglish\nUnknown\thack\nSmartEnglish\tinvalid\n");
            Equal("Cross-platform sync input mode","VNI",sync["InputMethod"]);
            Equal("Cross-platform sync priority","English",sync["LanguagePriority"]);
            Equal("Cross-platform sync unknown rejected","False",sync.ContainsKey("Unknown").ToString());
            Equal("Cross-platform sync invalid rejected","False",sync.ContainsKey("SmartEnglish").ToString());
            Equal("Portable default uses LocalAppData","False",AppStorage.IsPortable.ToString());
            Equal("Portable data path",Path.Combine("C:\\Demo","Data"),
                AppStorage.ResolveDirectory("C:\\Demo","C:\\Users\\Test",true));
            Equal("Installed data path",Path.Combine("C:\\Users\\Test","TelexMini"),
                AppStorage.ResolveDirectory("C:\\Demo","C:\\Users\\Test",false));
            foreach(string word in new[] { "escape", "hello", "browser", "github", "script" }) {
                var english=new TelexEngine(); foreach(char c in word) english.Push(c);
                Equal("Restore English "+word,word,english.Finish(true));
                Equal("Restoration off "+word,english.Text,english.Finish(false));
            }
            var ambiguous=new TelexEngine(); foreach(char c in "as") ambiguous.Push(c);
            Equal("Ambiguous word retains Vietnamese","á",ambiguous.Finish(true));
            foreach(string word in new[] { "office","testing","password","framework","plugin","dashboard","release","browser","github","script","assets","developer","windows","hello","english","parameter","parameters","parameterized","parameterization","parametric","parametrize","params","parentheses","parallel","parser" }) {
                var bilingual=new TelexEngine { SmartEnglish=true };
                string prefix="";
                foreach(char c in word) {
                    prefix+=c;
                    bilingual.Push(c);
                    string expectedPrefix=prefix=="of" ? "ò" :
                        prefix=="as" ? "á" :
                        prefix=="tes" ? "té" :
                        prefix=="test" ? "tét" :
                        prefix=="das" ? "dá" :
                        prefix=="off" ? "of" :
                        prefix=="ass" ? "as" : prefix;
                    Equal("Smart English prefix "+prefix,expectedPrefix,bilingual.Text);
                }
                Equal("Smart English while typing "+word,word,bilingual.Text);
                Equal("Smart English boundary "+word,word,bilingual.Finish(true));
            }
            foreach(string word in new[] { "tieengs","vieetj","truowngf","nguowif","caamr","ddawng","toasn" }) {
                var bilingual=new TelexEngine { SmartEnglish=true };
                foreach(char c in word) bilingual.Push(c);
                var reference=new TelexEngine(); foreach(char c in word) reference.Push(c);
                Equal("Smart Vietnamese "+word,reference.Text,bilingual.Text);
                Equal("Smart Vietnamese boundary "+word,reference.Finish(true),bilingual.Finish(true));
            }
            // Interleaved shape/tone commands must commute for a valid
            // Vietnamese syllable: xuo + s + o + ng -> xuống.
            foreach(var pair in new[] {
                new[]{"xuosong","xuống"},new[]{"xuoosng","xuống"},
                new[]{"xuoongs","xuống"},new[]{"muosong","muống"},
                new[]{"cuosong","cuống"},new[]{"xuofong","xuồng"},
                new[]{"xuorong","xuổng"},new[]{"exe","exe"},
                new[]{"eex","ễ"},new[]{"kieeru","kiểu"},
                new[]{"nhieefu","nhiều"},new[]{"vaajy","vậy"},
                new[]{"book","book"},new[]{"good","good"}
            }) {
                var e=new TelexEngine {SmartEnglish=true};
                foreach(char c in pair[0]) e.Push(c);
                Equal("Interleaved Telex "+pair[0],pair[1],e.Text);
                Equal("Interleaved Telex boundary "+pair[0],pair[1],e.Finish(true));
            }
            // The vowel-shaping key may come after all five tone keys:
            // xuo+s+o+ng == xuo+o+s+ng, and likewise for other vowel groups.
            foreach(string stem in new[]{"xuo","muo","cuo","kie","tua"}) {
                char vowel=stem[stem.Length-1];
                foreach(char mark in "sfrxj") {
                    string before=stem+mark+vowel+"ng";
                    string after=stem+vowel+mark+"ng";
                    var a=new TelexEngine {SmartEnglish=true};
                    var b=new TelexEngine {SmartEnglish=true};
                    foreach(char c in before) a.Push(c);
                    foreach(char c in after) b.Push(c);
                    string expected=b.Finish(true);
                    Equal("Interleaved vowel shape "+before,expected,a.Text);
                    Equal("Interleaved vowel shape boundary "+before,expected,a.Finish(true));
                }
            }
            // Metamorphic tone-position tests: 6 vowel families x 5 tones.
            // A tone before the last vowel must equal the same tone at the
            // end, regardless of which accent key is used.
            foreach(var family in new[] {
                new[]{"kiee","u"},new[]{"nhiee","u"},new[]{"vaa","y"},
                new[]{"cha","y"},new[]{"nguow","i"},new[]{"yee","u"}
            }) foreach(char mark in "sfrxj") {
                string before=family[0]+mark+family[1];
                string after=family[0]+family[1]+mark;
                var first=new TelexEngine {SmartEnglish=true};
                var second=new TelexEngine {SmartEnglish=true};
                foreach(char c in before) first.Push(c);
                foreach(char c in after) second.Push(c);
                string expected=second.Finish(true);
                Equal("Accent before final vowel "+before,expected,first.Text);
                Equal("Accent before final vowel boundary "+before,expected,first.Finish(true));
            }
            // Telex shaping must happen on the second vowel, never at the
            // word boundary. English words sharing a prefix can recover later.
            foreach(var pair in new[] {
                new[]{"as","á"},new[]{"ex","ẽ"},new[]{"exe","exe"},
                new[]{"ee","ê"},new[]{"eex","ễ"},
                new[]{"b","b"}, new[]{"bo","bo"},new[]{"boo","bô"},
                new[]{"boon","bôn"},new[]{"boons","bốn"},
                new[]{"aa","â"},new[]{"ee","ê"},new[]{"oo","ô"},
                new[]{"tiee","tiê"},new[]{"tieen","tiên"},
                new[]{"tieengs","tiếng"}
            }) {
                var bilingual=new TelexEngine {SmartEnglish=true};
                foreach(char c in pair[0]) bilingual.Push(c);
                Equal("Instant Telex "+pair[0],pair[1],bilingual.Text);
            }
            foreach(var pair in new[] {
                new[]{"book","book"}, new[]{"books","books"},
                new[]{"good","good"}, new[]{"boost","bốt"}
            }) {
                var bilingual=new TelexEngine {SmartEnglish=true};
                foreach(char c in pair[0]) bilingual.Push(c);
                Equal("English after instant Telex "+pair[0],pair[1],bilingual.Text);
                Equal("English boundary after instant Telex "+pair[0],pair[1],bilingual.Finish(true));
            }
            foreach(var pair in new[] {
                new[]{"bee","bê"},new[]{"been","bên"},
                new[]{"beens","bến"},new[]{"teen","tên"},
                new[]{"seen","sên"},new[]{"boost","bốt"}
            }) {
                var bilingual=new TelexEngine {SmartEnglish=true};
                foreach(char c in pair[0]) bilingual.Push(c);
                Equal("Vietnamese priority "+pair[0],pair[1],bilingual.Text);
                Equal("Vietnamese priority at boundary "+pair[0],pair[1],bilingual.Finish(true));
            }
            // Tone commands are immediate; a vowel after an unshaped
            // toned vowel means an English token rather than a second shape.
            foreach(var pair in new[] {
                new[]{"as","á"},new[]{"ass","as"},
                new[]{"ex","ẽ"},new[]{"exe","exe"},
                new[]{"ee","ê"},new[]{"eex","ễ"}
            }) {
                var e=new TelexEngine {SmartEnglish=true};
                foreach(char c in pair[0]) e.Push(c);
                Equal("Immediate tone placement "+pair[0],pair[1],e.Text);
                Equal("Immediate tone boundary "+pair[0],pair[1],e.Finish(true));
            }
            // Repeating an effective Telex key restores the original raw
            // typing and keeps subsequent letters literal until boundary.
            foreach(var pair in new[] {
                new[]{"booss","boos"},new[]{"boosst","boost"},
                new[]{"boosster","booster"},new[]{"guitarr","guitar"},
                new[]{"ass","as"},new[]{"aaa","aa"},new[]{"eee","ee"},
                new[]{"ooo","oo"},new[]{"ddd","dd"},
                new[]{"aass","aas"},new[]{"uoww","uow"},
                new[]{"boons","bốn"},new[]{"been","bên"}
            }) {
                var bilingual=new TelexEngine {SmartEnglish=true};
                foreach(char c in pair[0]) bilingual.Push(c);
                Equal("Repeated Telex escape "+pair[0],pair[1],bilingual.Text);
                Equal("Repeated Telex escape boundary "+pair[0],pair[1],bilingual.Finish(true));
            }
            var englishFirst=new TelexEngine {SmartEnglish=true,PreferEnglishExact=true};
            foreach(char c in "been") englishFirst.Push(c);
            Equal("English-first explicit collision","been",englishFirst.Text);
            Equal("English-first boundary","been",englishFirst.Finish(true));
            var vietnameseOnly=new TelexEngine {SmartEnglish=false};
            foreach(char c in "been") vietnameseOnly.Push(c);
            Equal("Vietnamese-first explicit collision","bên",vietnameseOnly.Text);
            // VNI uses numbered tone/shape keys while ordinary Telex stays the default.
            foreach(var pair in new[] {
                new[]{"bo6n1","bốn"},new[]{"tie6ng1","tiếng"},
                new[]{"da9ng8","đăng"},new[]{"ma1","má"},
                new[]{"mo7","mơ"},new[]{"mu7","mư"},
                new[]{"uo7","ươ"},new[]{"abc123","abc123"}
            }) {
                var e=new TelexEngine {UseVni=true,SmartEnglish=true};
                foreach(char c in pair[0]) e.Push(c);
                Equal("VNI "+pair[0],pair[1],e.Text);
                Equal("VNI boundary "+pair[0],pair[1],e.Finish(true));
            }
            Equal("Excluded app initial false","False",ContextPolicy.IsUserExcluded("nonexistent_example.exe").ToString());
            Equal("Excluded process exact match","True",ContextPolicy.MatchesExcluded("code.exe","chrome, code, notepad").ToString());
            Equal("Excluded process does not match substring","False",ContextPolicy.MatchesExcluded("mycode.exe","chrome, code").ToString());
            // Algorithmic recovery of unfamiliar English words, not dictionary matches.
            foreach(string word in new[] {
                "paradoxical","paramagnets","privatization","fluctuation",
                "cryptanalysis","synchronization","customizable","cursorial",
                "verifiability","transactional","gradients","kernelization",
                "robustness","photorealistic","subroutines","whimsical",
                "microarchitecture","hyperparameterization","reparameterizing",
                "asynchronousness","combinatorialism","cryptomining",
                "dataclassification","encapsulationist","serializationist",
                "decentralizationist","typographically","unpredictability",
                "metaprogramming","cryptographically","infrastructural",
                "managerialism","keyboardless","firmwareless"
            }) {
                Equal("Unknown English not in dictionary "+word,"False",EnglishLexicon.IsWord(word).ToString());
                var bilingual=new TelexEngine { SmartEnglish=true };
                foreach(char c in word) bilingual.Push(c);
                Equal("Unknown English while typing "+word,word,bilingual.Text);
                Equal("Unknown English boundary "+word,word,bilingual.Finish(true));
            }
            Equal("Password always English", "False", ContextPolicy.UseVietnamese(true,false,InputContextKind.Password).ToString());
            Equal("Unknown field fail closed", "False", ContextPolicy.UseVietnamese(true,false,InputContextKind.Checking).ToString());
            Equal("Unavailable field fail closed", "False", ContextPolicy.UseVietnamese(true,false,InputContextKind.Unavailable).ToString());
            var cachedText=new InputContextMonitor.Snapshot(new IntPtr(101),new IntPtr(202),303,
                InputContextKind.Text,7);
            var cachedPassword=new InputContextMonitor.Snapshot(new IntPtr(101),new IntPtr(202),303,
                InputContextKind.Password,7);
            Equal("Cached field reused across V/E revisions","True",
                InputContextMonitor.SnapshotMatches(cachedText,new IntPtr(101),new IntPtr(202),303).ToString());
            Equal("Changed focus never reuses prior classification","False",
                InputContextMonitor.SnapshotMatches(cachedPassword,new IntPtr(101),new IntPtr(203),303).ToString());
            Equal("Reused HWND with new process never reuses classification","False",
                InputContextMonitor.SnapshotMatches(cachedPassword,new IntPtr(101),new IntPtr(202),304).ToString());
            Equal("Fresh focus snapshot matches its revision","True",
                InputContextMonitor.SnapshotMatches(cachedText,new IntPtr(101),new IntPtr(202),303,7).ToString());
            Equal("Stale focus snapshot fails closed","False",
                InputContextMonitor.SnapshotMatches(cachedPassword,new IntPtr(101),new IntPtr(202),303,8).ToString());
            Equal("Unknown process has no restore target","True",
                (Native.FindTopLevelWindowForProcess(int.MaxValue)==IntPtr.Zero).ToString());
            uint seed=0x47A2B199;
            foreach(bool vni in new[]{false,true}) {
                string alphabet=vni ? "abcdefghijklmnopqrstuvxyz123456789" :
                                      "abcdefghijklmnopqrstuvxyz";
                for(int iteration=0;iteration<1500;iteration++) {
                    var e=new TelexEngine {SmartEnglish=true,UseVni=vni};
                    int written=0;
                    bool valid=true;
                    for(int j=0;j<24;j++) {
                        unchecked {seed=seed*1664525u+1013904223u;}
                        char c=alphabet[(int)(seed%(uint)alphabet.Length)];
                        e.Push(c);written++;
                        if(e.Text.Length>written) valid=false;
                        if((seed&31)==0) {e.Backspace();written=e.Text.Length;}
                    }
                    if(e.Finish(true).Length>written) valid=false;
                    if(!valid) {failures++;Console.WriteLine("FAIL randomized composition invariant");}
                }
            }
            Console.WriteLine("Deterministic stress: 3000 compositions.");
            Console.WriteLine("Bundled English vocabulary: "+EnglishLexicon.WordCount);
            var longWord=new TelexEngine(); string longInput=new string('b',70)+"esscape";
            foreach(char c in longInput) longWord.Push(c);
            Equal("Long identifier retains prefix",longInput,longWord.Text);
            Equal("Terminal classifier","True",ContextPolicy.IsTerminal("WindowsTerminal.exe").ToString());
            Equal("PowerShell classifier","True",ContextPolicy.IsTerminal("pwsh").ToString());
            Equal("Browser remains text","False",ContextPolicy.IsTerminal("msedge").ToString());
            Equal("Steam remote executable","True",ContextPolicy.ShouldYieldKeys("streaming_client.exe").ToString());
            Equal("Steam remote case insensitive","True",ContextPolicy.ShouldYieldKeys("STREAMING_CLIENT").ToString());
            Equal("Steam library keeps Telex","False",ContextPolicy.ShouldYieldKeys("steam.exe").ToString());
            Equal("Steam chat keeps Telex","False",ContextPolicy.ShouldYieldKeys("steamwebhelper.exe").ToString());
            foreach(string name in new[] { "Fightcade2.exe", "fcadefbneo.exe", "fcadefbneo", "flycast.exe", "fbneo.exe" })
                Equal("Game bypass "+name,"True",ContextPolicy.IsGame(name).ToString());
            foreach(string name in new[] { "msedge", "notepad", "pwsh" })
                Equal("Non-game "+name,"False",ContextPolicy.IsGame(name).ToString());
            using(var hooks=new Keyboard()) {
                Equal("Hooks initially active","True",hooks.HooksInstalled.ToString());
                hooks.Enabled=false;
                Equal("Manual E removes both hooks","False",hooks.HooksInstalled.ToString());
                hooks.Enabled=true;
                Equal("Manual V restores hooks","True",hooks.HooksInstalled.ToString());
                hooks.Suspended=true;
                Equal("Game suspension removes both hooks","False",hooks.HooksInstalled.ToString());
                hooks.Enabled=false; hooks.Suspended=false;
                Equal("Leaving game preserves manual E","False",hooks.HooksInstalled.ToString());
                hooks.Enabled=true;
                Equal("Resume restores hooks","True",hooks.HooksInstalled.ToString());
            }
            using(var monitor=new InputContextMonitor()) {
                System.Threading.Thread.Sleep(1000);
                Equal("Disabled auto mode performs zero UIA queries","0",monitor.AccessibilityQueries.ToString());
                int revision=monitor.Current.Revision;
                monitor.Enabled=true;monitor.Enabled=false;
                Equal("V/E toggles preserve cached focus revision",revision.ToString(),monitor.Current.Revision.ToString());
            }
            var fastSnapshot=new InputContextMonitor.Snapshot(new IntPtr(11),new IntPtr(22),33,
                InputContextKind.Text,1);
            var latencyWatch=System.Diagnostics.Stopwatch.StartNew();
            for(int i=0;i<10000;i++)
                InputContextMonitor.SnapshotMatches(fastSnapshot,new IntPtr(11),new IntPtr(22),33);
            latencyWatch.Stop();
            if(latencyWatch.ElapsedMilliseconds>250) {
                failures++;Console.WriteLine("FAIL cached focus lookup exceeded 250ms: "+latencyWatch.ElapsedMilliseconds);
            } else Console.WriteLine("Cached focus lookup 10k iterations: "+latencyWatch.ElapsedMilliseconds+"ms");

            foreach(InputContextKind context in Enum.GetValues(typeof(InputContextKind))) {
                Equal("Auto context "+context,(context==InputContextKind.Text).ToString(),ContextPolicy.UseVietnamese(true,true,context).ToString());
                Equal("Manual English stays English "+context,"False",ContextPolicy.UseVietnamese(false,true,context).ToString());
                Equal("Auto disabled "+context,(context==InputContextKind.Text || context==InputContextKind.Terminal).ToString(),ContextPolicy.UseVietnamese(true,false,context).ToString());
            }
            var edit=new TelexEngine(); foreach(char c in "tieengs") edit.Push(c);
            edit.Backspace(); Equal("Backspace removes visible character","tiến",edit.Text);
            edit.Push('g'); Equal("Continue after Backspace","tiếng",edit.Text);
            edit.Reset(); Equal("Reset","",edit.Text);
            foreach(char c in "ess") edit.Push(c);
            edit.Backspace();
            foreach(char c in "scape") edit.Push(c);
            Equal("English lock survives Backspace","escape",edit.Text);
            edit.Reset(); foreach(char c in "tieengs") edit.Push(c);
            Equal("Word boundary restores Telex","tiếng",edit.Text);
            edit.Reset(); foreach(char c in "ess") edit.Push(c);
            edit.Backspace(); edit.Backspace();
            foreach(char c in "as") edit.Push(c);
            Equal("Deleting whole word restores Telex","á",edit.Text);
            TestSettingsLayoutAndDictionary();
            TestProductivityUi();
            Console.WriteLine("INPUT struct size: "+Marshal.SizeOf(typeof(Native.INPUT)));
            if(Marshal.SizeOf(typeof(Native.INPUT))!=(IntPtr.Size==8 ? 40 : 28)) failures++;
            if(args.Length>0 && args[0]=="--integration") {
                IntPtr previous=GetKeyboardLayout(0);
                Console.WriteLine("Original keyboard layout: "+previous.ToInt64().ToString("X"));
                LoadKeyboardLayout("00000409",1);
                Console.WriteLine("Test keyboard layout: "+GetKeyboardLayout(0).ToInt64().ToString("X"));
                try { Application.EnableVisualStyles(); Application.Run(new IntegrationForm()); }
                finally { ActivateKeyboardLayout(previous,0); }
            }
            Console.WriteLine("Failures: "+failures); return failures==0 ? 0 : 1;
        }
        static bool ThrowsFormat(Action f) {
            try {f();return false;} catch(FormatException) {return true;}
        }
        static void ReplayScenario(string keys,string expected)
        {
            var engine=new TelexEngine {SmartEnglish=true};
            string document="prefix ";
            foreach(char c in keys) {
                if(c==' ' || c=='\n') {
                    string final=engine.Finish(true);
                    document=TextEditPlan.Between(engine.Text,final).Apply(document);
                    document+=c;engine.Reset();
                } else if(c=='\b') {
                    engine.Backspace();
                    if(document.Length>0) document=document.Substring(0,document.Length-1);
                } else {
                    string before=engine.Text,after=engine.Push(c);
                    document=TextEditPlan.Between(before,after).Apply(document);
                }
            }
            document=TextEditPlan.Between(engine.Text,engine.Finish(true)).Apply(document);
            Equal("Scratch document scenario "+keys,"prefix "+expected,document);
        }
        static void TestSettingsLayoutAndDictionary()
        {
            using(var host=new Form())
            using(var mode=new Button())
            using(var status=new Label())
            using(var auto=new CheckBox())
            using(var restore=new CheckBox())
            using(var smart=new CheckBox())
            using(var hide=new Button())
            using(var exit=new Button()) {
                var ui=new ModernChrome(host,mode,status,auto,restore,smart,hide,exit,
                    delegate {},delegate {},delegate {});
                host.CreateControl();
                host.PerformLayout();
                var layout=host.Controls.Count>0 ? host.Controls[0] as TableLayoutPanel : null;
                if(layout!=null) layout.PerformLayout();
                Control nav=layout==null ? null : layout.GetControlFromPosition(0,0);
                Control content=layout==null ? null : layout.GetControlFromPosition(1,0);
                Equal("Settings layout columns do not overlap","True",
                    (nav!=null && content!=null && content.Left>=nav.Right && content.Width>0).ToString());
                Equal("Settings width supports navigation and content","True",
                    (host.ClientSize.Width>=950 && layout!=null && layout.ColumnCount==2).ToString());
                var leftField=typeof(ModernChrome).GetField("leftCard",BindingFlags.Instance|BindingFlags.NonPublic);
                var leftCard=leftField==null?null:leftField.GetValue(ui) as Control;
                int leftChecks=0,leftLabels=0;
                if(leftCard!=null) foreach(Control child in leftCard.Controls) {
                    if(child is CheckBox) leftChecks++;
                    if(child is Label && !string.IsNullOrWhiteSpace(child.Text)) leftLabels++;
                }
                Equal("Language card contains both options and labels","True",
                    (leftCard!=null && leftChecks==2 && leftLabels>=2).ToString());
            }
            string testFile=Path.Combine(Path.GetTempPath(),
                "TelexMini-Dictionary-UI-"+Guid.NewGuid().ToString("N")+".txt");
            try {
                File.WriteAllText(testFile,"",System.Text.Encoding.UTF8);
                using(Form editor=DictionaryEditor.CreateForTests(false,testFile)) {
                Equal("Dictionary editor opens in app","True",
                    (editor.Controls.Count>0 && editor.Text.IndexOf(UiText.IsEnglish?"dictionary":"Anh",StringComparison.OrdinalIgnoreCase)>=0).ToString());
                Equal("Dictionary editor uses TelexMini icon","True",(editor.Icon!=null).ToString());
                var textboxes=new List<TextBox>();
                var buttons=new List<Button>();
                var lists=new List<ListBox>();
                CollectControls(editor,textboxes,buttons,lists);
                Equal("Dictionary inline editing controls","True",
                    (textboxes.Count>=2 && lists.Count==1 && buttons.Count>=4).ToString());
                if(textboxes.Count>=2 && lists.Count==1 && buttons.Count>=4) {
                    // Search is first, entry is second. Never invoke Save,
                    // so this test does not touch a user's dictionary on disk.
                    textboxes[1].Text="telexminiuitestword";
                    // Button.PerformClick ignores invisible test forms. Exercise the
                    // same add/remove callbacks without showing a window.
                    typeof(DictionaryEditor).GetMethod("AddWord",BindingFlags.Instance|BindingFlags.NonPublic)
                        .Invoke(editor,new object[0]);
                    Equal("Dictionary add without external editor","True",
                        lists[0].Items.Contains("telexminiuitestword").ToString());
                    typeof(DictionaryEditor).GetMethod("RemoveWord",BindingFlags.Instance|BindingFlags.NonPublic)
                        .Invoke(editor,new object[0]);
                    Equal("Dictionary remove without external editor","False",
                        lists[0].Items.Contains("telexminiuitestword").ToString());
                    // Save a word to a temporary test-only file and verify
                    // that the editor persists it, without changing user data.
                    textboxes[1].Text="telexminiuitestword";
                    typeof(DictionaryEditor).GetMethod("AddWord",BindingFlags.Instance|BindingFlags.NonPublic)
                        .Invoke(editor,new object[0]);
                    typeof(DictionaryEditor).GetMethod("SaveWords",BindingFlags.Instance|BindingFlags.NonPublic)
                        .Invoke(editor,new object[0]);
                    Equal("Dictionary save persists words","True",
                        (File.ReadAllText(testFile).Contains("telexminiuitestword")).ToString());
                }
                }
            } finally {
                if(File.Exists(testFile)) File.Delete(testFile);
            }
        }

        static void TestProductivityUi()
        {
            var ctor=typeof(ProductivitySettings).GetConstructor(
                BindingFlags.Instance|BindingFlags.NonPublic,null,Type.EmptyTypes,null);
            Equal("Productivity settings constructor","True",(ctor!=null).ToString());
            if(ctor!=null) using(var dialog=(Form)ctor.Invoke(new object[0])) {
                Equal("Productivity dialog uses TelexMini icon","True",(dialog.Icon!=null).ToString());
                var boxes=new List<TextBox>();
                var buttons=new List<Button>();
                var lists=new List<ListBox>();
                CollectControls(dialog,boxes,buttons,lists);
                Equal("Productivity inline editors","True",(boxes.Count>=3).ToString());
                Equal("Productivity save control","True",
                    buttons.Exists(b=>b.Text==UiText.T("Lưu và áp dụng")).ToString());
            }
            var advancedCtor=typeof(AdvancedSettings).GetConstructor(
                BindingFlags.Instance|BindingFlags.NonPublic,null,Type.EmptyTypes,null);
            Equal("Advanced settings constructor","True",(advancedCtor!=null).ToString());
            if(advancedCtor!=null) using(var advanced=(Form)advancedCtor.Invoke(new object[0]))
                Equal("Advanced settings uses TelexMini icon","True",(advanced.Icon!=null).ToString());
            var iconFactory=typeof(MainForm).GetMethod("MakeIcon",BindingFlags.Static|BindingFlags.NonPublic);
            if(iconFactory!=null) {
                using(var v=(Icon)iconFactory.Invoke(null,new object[]{"V",Color.FromArgb(18,167,119)}))
                    Equal("Vietnamese taskbar icon has V badge","32x32",v.Width+"x"+v.Height);
                using(var e=(Icon)iconFactory.Invoke(null,new object[]{"E",Color.FromArgb(57,112,232)}))
                    Equal("English taskbar icon has E badge","32x32",e.Width+"x"+e.Height);
            }
            using(var picker=new SymbolPicker()) {
                Equal("Symbol picker uses TelexMini icon","True",(picker.Icon!=null).ToString());
                var boxes=new List<TextBox>();
                var buttons=new List<Button>();
                var lists=new List<ListBox>();
                CollectControls(picker,boxes,buttons,lists);
                Equal("Symbol picker offers 20+ symbols","True",(buttons.Count>=20).ToString());
            }
        }
        static void CollectControls(Control root,List<TextBox> textboxes,List<Button> buttons,List<ListBox> lists)
        {
            foreach(Control c in root.Controls) {
                if(c is TextBox) textboxes.Add((TextBox)c);
                if(c is Button) buttons.Add((Button)c);
                if(c is ListBox) lists.Add((ListBox)c);
                CollectControls(c,textboxes,buttons,lists);
            }
        }
        sealed class IntegrationForm : Form
        {
            readonly TextBox box=new TextBox { Dock=DockStyle.Fill, Multiline=true, ImeMode=ImeMode.Disable };
            readonly Timer timer=new Timer { Interval=45 };
            readonly Keyboard hook=new Keyboard { AcceptTestInput=true };
            readonly string[] input={"tieengs vieetj", "truowngf nguowif", "ass aaa ddd", "toasn", "tieengs\bg", "as", "as", "esscape tieengs vieetj", "ess\bscape", "esscape.as", "escape tieengs ", "hello.browser ", "github\t"};
            readonly string[] expected={"tiếng việt", "trường người", "as aa dd", "toán", "tiếng", "as", "á", "escape tiếng việt", "escape", "escape.á", "escape tiếng ", "hello.browser ", "github"};
            int test,position,delay=8;
            internal IntegrationForm() {
                Text="Telex Mini — automated input test";
                StartPosition=FormStartPosition.CenterScreen;
                TopMost=true;
                Controls.Add(box);
                var start=new Button { Text="Start input test", Dock=DockStyle.Top, Height=40 };
                Controls.Add(start);
                start.Click+=delegate { start.Enabled=false; box.Focus(); LoadKeyboardLayout("00000409",1); timer.Start(); };
                if(Environment.GetEnvironmentVariable("TELEX_AUTO_INTEGRATION")=="1")
                    Shown+=delegate {
                        TopMost=true;Activate();BringToFront();
                        start.PerformClick();
                    };
                timer.Tick+=Tick;
            }
            void Tick(object sender,EventArgs e) {
                if(delay-->0) return;
                if(Native.GetForegroundWindow()!=Handle) {
                    Console.WriteLine("FAIL integration aborted: test window lost foreground."); failures++; timer.Stop(); Close(); return;
                }
                if(position<input[test].Length) {
                    if(Environment.GetEnvironmentVariable("TELEX_TRACE")=="1") Console.WriteLine("TRACE "+position+" ["+box.Text+"]");
                    char c=input[test][position++]; ushort vk=c=='\b' ? (ushort)8 : c=='\t' ? (ushort)9 : c==' ' ? (ushort)32 : c=='.' ? (ushort)0xBE : (ushort)char.ToUpperInvariant(c);
                    var down=Native.Key(vk,0,0); down.Data.Keyboard.Extra=UIntPtr.Zero;
                    var up=Native.Key(vk,0,2); up.Data.Keyboard.Extra=UIntPtr.Zero;
                    Native.SendInput(2,new[] { down,up },Marshal.SizeOf(typeof(Native.INPUT)));
                    delay=1; return;
                }
                Equal("Windows TextBox: "+input[test],expected[test],box.Text);
                test++; position=0;
                if(test==input.Length) { timer.Stop(); Close(); return; }
                box.Clear(); hook.Enabled=test!=5; delay=3;
            }
            protected override void Dispose(bool disposing) { if(disposing) { timer.Dispose(); hook.Dispose(); } base.Dispose(disposing); }
        }
    }
}
