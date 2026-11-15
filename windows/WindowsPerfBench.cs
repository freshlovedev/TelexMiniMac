using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;

namespace TelexMini
{
    // Deterministic, offline microbenchmark. Does NOT send keys to live
    // applications or measure physical key-to-screen latency.
    internal static class WindowsPerfBench
    {
        static readonly string[] Words = {
            "tieengs","chayj","kieeru","nhieefu","nguowif",
            "boons","boost","parameter","download","exe",
            "ddawng","truwowngf","ass","offfice","vieejc",
            "ttest","duowngf","nhaas","hello","github",
            "quas","baor","truowngf","nguyeenx","muoons"
        };
        static double Microseconds(long ticks) {
            return ticks*1000000.0/Stopwatch.Frequency;
        }
        static double Percentile(List<long> samples,double percentile) {
            if(samples.Count==0)return 0;
            int i=Math.Min(samples.Count-1,Math.Max(0,(int)Math.Ceiling(percentile*samples.Count)-1));
            return Microseconds(samples[i]);
        }
        static void Report(string kind,List<long> values,double seconds) {
            values.Sort();
            Console.WriteLine("BENCH "+kind+
                " samples="+values.Count+
                " p50_us="+Percentile(values,.50).ToString("F2",CultureInfo.InvariantCulture)+
                " p95_us="+Percentile(values,.95).ToString("F2",CultureInfo.InvariantCulture)+
                " p99_us="+Percentile(values,.99).ToString("F2",CultureInfo.InvariantCulture)+
                " throughput_per_s="+(values.Count/Math.Max(.0001,seconds)).ToString("F0",CultureInfo.InvariantCulture));
        }
        internal static int Run()
        {
            const int iterations=12000;
            Console.WriteLine("BENCH TelexMini Windows native simulated workload");
            Console.WriteLine("BENCH engine_only=true live_hook=false content_logged=false");
            Console.WriteLine("BENCH cpu_cores="+Environment.ProcessorCount+" os="+Environment.OSVersion.Version);
            int failures=0;
            var keySamples=new List<long>(iterations);
            GC.Collect();GC.WaitForPendingFinalizers();GC.Collect();
            var start=Stopwatch.StartNew();
            for(int i=0;i<iterations;i++) {
                string word=Words[i%Words.Length];
                var engine=new TelexEngine {SmartEnglish=(i%4)!=0,PreferEnglishExact=(i%7)==0};
                string virtualField="prefix ";
                long t=Stopwatch.GetTimestamp();
                foreach(char c in word) {
                    string before=engine.Text, after=engine.Push(c);
                    var edit=TextEditPlan.Between(before,after);
                    virtualField=edit.Apply(virtualField);
                    if(virtualField!="prefix "+after) {failures++;break;}
                }
                string finish=engine.Finish(true);
                virtualField=TextEditPlan.Between(engine.Text,finish).Apply(virtualField);
                if(virtualField!="prefix "+finish)failures++;
                keySamples.Add(Stopwatch.GetTimestamp()-t);
            }
            start.Stop();
            Report("compose_and_editplan_per_word",keySamples,start.Elapsed.TotalSeconds);
            var profiles=new System.Text.StringBuilder();
            for(int i=0;i<200;i++)profiles.Append("app").Append(i).Append(".exe\t")
                .Append(i%2==0?"English":"Vietnamese").Append('\n');
            var text=profiles.ToString();
            var table=Productivity.ParseProfiles(text);
            var legacy=new List<long>(8000);
            var cached=new List<long>(8000);
            string[] queries=new string[8000];
            for(int i=0;i<queries.Length;i++)queries[i]="app"+(i%200)+".exe";
            start.Restart();
            for(int i=0;i<queries.Length;i++) {
                long t=Stopwatch.GetTimestamp();
                Productivity.GetProfile(queries[i],text);
                legacy.Add(Stopwatch.GetTimestamp()-t);
            }
            start.Stop();
            double legacySeconds=start.Elapsed.TotalSeconds;
            start.Restart();
            for(int i=0;i<queries.Length;i++) {
                long t=Stopwatch.GetTimestamp();
                string actual=Productivity.GetProfile(table,queries[i]);
                cached.Add(Stopwatch.GetTimestamp()-t);
                string expected=i%2==0?"English":"Vietnamese";
                if(actual!=expected)failures++;
            }
            start.Stop();
            Report("profile_legacy_scan",legacy,legacySeconds);
            Report("profile_cached_lookup",cached,start.Elapsed.TotalSeconds);
            // Deterministic stress: every edit plan is checked against a
            // simulated text field, never an actual user document.
            const int stress=100000;
            var stressSamples=new List<long>(stress);
            GC.Collect();GC.WaitForPendingFinalizers();GC.Collect();
            long managedBefore=GC.GetTotalMemory(true);
            using(var process=Process.GetCurrentProcess()) {
                process.Refresh();
                long privateBefore=process.PrivateMemorySize64;
                start.Restart();
                for(int i=0;i<stress;i++) {
                    string keys=Words[(i*17)%Words.Length];
                    var e=new TelexEngine {
                        SmartEnglish=(i%3)!=0,
                        PreferEnglishExact=(i%11)==0,
                        UseVni=(i%13)==0
                    };
                    string field="baseline ";
                    long t=Stopwatch.GetTimestamp();
                    foreach(char c in keys) {
                        string before=e.Text;
                        string after=e.Push(c);
                        var plan=TextEditPlan.Between(before,after);
                        if(!Native.IsSafeEditSize(plan.Erase,plan.Insert.Length,false))failures++;
                        field=plan.Apply(field);
                        if(field!="baseline "+after) {failures++;break;}
                    }
                    string finalized=e.Finish(true);
                    field=TextEditPlan.Between(e.Text,finalized).Apply(field);
                    if(field!="baseline "+finalized)failures++;
                    stressSamples.Add(Stopwatch.GetTimestamp()-t);
                }
                start.Stop();
                Report("stress_compose_100k_words",stressSamples,start.Elapsed.TotalSeconds);
                GC.Collect();GC.WaitForPendingFinalizers();GC.Collect();
                process.Refresh();
                long managedAfter=GC.GetTotalMemory(true);
                Console.WriteLine("BENCH managed_delta_bytes="+
                    (managedAfter-managedBefore).ToString(CultureInfo.InvariantCulture));
                Console.WriteLine("BENCH private_delta_bytes="+
                    (process.PrivateMemorySize64-privateBefore).ToString(CultureInfo.InvariantCulture));
            }
            // Compare the shipped C++ runtime bridge to the legacy C#
            // composer on exactly the same 100k deterministic words.
            var bridgeSamples=new List<long>(stress);
            GC.Collect();GC.WaitForPendingFinalizers();GC.Collect();
            using(var runtime=new NativeComposer()) {
                start.Restart();
                for(int i=0;i<stress;i++) {
                    string keys=Words[(i*17)%Words.Length];
                    bool smart=(i%3)!=0, first=(i%11)==0, vni=(i%13)==0;
                    var reference=new TelexEngine {
                        SmartEnglish=smart, PreferEnglishExact=first,UseVni=vni
                    };
                    foreach(char c in keys)reference.Push(c);
                    string expected=reference.Finish(true);

                    runtime.Reset();
                    runtime.SmartEnglish=smart;
                    runtime.PreferEnglishExact=first;
                    runtime.UseVni=vni;

                    long t=Stopwatch.GetTimestamp();
                    foreach(char c in keys)runtime.Push(c);
                    string actual=runtime.Finish(true);
                    bridgeSamples.Add(Stopwatch.GetTimestamp()-t);

                    if(expected!=actual)failures++;
                }
                start.Stop();
            }
            double nativeSeconds=0;
            foreach(long ticks in bridgeSamples)nativeSeconds+=ticks/(double)Stopwatch.Frequency;
            Report("native_bridge_100k_words",bridgeSamples,nativeSeconds);
            Console.WriteLine("BENCH failures="+failures);
            return failures==0?0:1;
        }
    }
}
