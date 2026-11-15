using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using TelexMini;
class TelexNativeOracle {
  static readonly string[] Seeds = {
    "w","W","ow","now","noww","windows","world","uow","uw","aw",
    "boost","boosst","parameter","download","exe","been","bên",
    "tieengs","chayj","kieeru","boons","truowngf","nguwowif",
    "as","ass","aaa","ddd","eex","exxe","esscape","escape",
    "a","aa","ae","aee","ax","off","office","github",
    "ba","baf","bar","baj","bax","bas","bao","baos",
    "duwongf","duongd","truwongf","chuong","chuoong","oong",
    "uon","uong","nguoi","nguoiwf","nguyeenx","tieen","quas",
    "h","hh","d","dd","wi","why","wonder","how","snow",
    "one","once","good","book","booked","keyboard","terminal"
  };
  static void Main(string[] args) {
    if(args.Length!=1)throw new ArgumentException("output TSV required");
    var words=new SortedSet<string>(StringComparer.Ordinal);
    foreach(var word in Seeds)words.Add(word);
    foreach(var onset in new[]{"","b","c","ch","d","dd","h","k","kh","l","m","n","ng","nh","ph","q","r","s","t","th","tr","v","x"})
      foreach(var vowel in new[]{"a","e","i","o","u","y","ao","oe","oa","uo","ie","uy","ua","ee","aa","oo","ow","uw","aw","uow"})
        foreach(var tail in new[]{"","n","ng","t","c","m","s","f","r","x","j","w","9","1","7"}) {
          var word=onset+vowel+tail;
          if(word.Length<=18)words.Add(word);
        }
    foreach(var line in File.ReadAllLines("telex-corpus.tsv",Encoding.UTF8)) {
      if(line.StartsWith("#"))continue;
      var parts=line.Split('\t');
      if(parts.Length>=2 && parts[0]!="raw" && parts[0].Length<=30)words.Add(parts[0]);
    }
    using(var writer=new StreamWriter(args[0],false,new UTF8Encoding(false))) {
      writer.WriteLine("mode\tinput\timmediate\tfinish");
      foreach(var word in words)foreach(var mode in new[]{"vi","balanced","english","vni"}) {
        var engine=new TelexEngine {
          SmartEnglish=mode!="vi" && mode!="vni",
          PreferEnglishExact=mode=="english",
          UseVni=mode=="vni"
        };
        var outputs=new List<string>();
        foreach(char c in word)outputs.Add(engine.Push(c));
        writer.WriteLine(mode+"\t"+word+"\t"+
                         string.Join("|",outputs.ToArray())+"\t"+engine.Finish(true));
      }
    }
    Console.WriteLine("ORACLE cases="+words.Count*4);
  }
}