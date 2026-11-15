using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Globalization;

namespace TelexMini
{
    internal static class Native
    {
        internal delegate IntPtr HookProc(int code, IntPtr message, IntPtr data);
        internal delegate void WinEventProc(IntPtr hook,uint eventType,IntPtr window,
                                           int objectId,int childId,uint thread,uint time);
        [DllImport("user32.dll",SetLastError=true)]
        internal static extern IntPtr SetWinEventHook(uint first,uint last,IntPtr module,
                              WinEventProc callback,uint process,uint thread,uint flags);
        [DllImport("user32.dll")]
        internal static extern bool UnhookWinEvent(IntPtr hook);
        [DllImport("user32.dll", SetLastError=true)] internal static extern IntPtr SetWindowsHookEx(int id, HookProc proc, IntPtr module, uint thread);
        [DllImport("user32.dll")] internal static extern bool UnhookWindowsHookEx(IntPtr hook);
        [DllImport("user32.dll")] internal static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr message, IntPtr data);
        [DllImport("kernel32.dll", CharSet=CharSet.Auto)] internal static extern IntPtr GetModuleHandle(string name);
        [DllImport("user32.dll")] internal static extern short GetAsyncKeyState(int key);
        [DllImport("user32.dll")] internal static extern short GetKeyState(int key);
        [DllImport("user32.dll")] internal static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] internal static extern uint GetWindowThreadProcessId(IntPtr window, IntPtr process);
        [DllImport("user32.dll",EntryPoint="GetWindowThreadProcessId")]
        internal static extern uint GetWindowThreadProcessIdWithPid(IntPtr window,out uint process);
        [DllImport("user32.dll")] internal static extern bool GetGUIThreadInfo(uint thread, ref GUIInfo info);
        [DllImport("user32.dll", SetLastError=true)] internal static extern uint SendInput(uint count, INPUT[] inputs, int size);
        [DllImport("user32.dll")] internal static extern bool RegisterHotKey(IntPtr window, int id, uint mods, uint key);
        [DllImport("user32.dll")] internal static extern bool UnregisterHotKey(IntPtr window, int id);
        [DllImport("user32.dll")] internal static extern bool DestroyIcon(IntPtr icon);
        [DllImport("user32.dll")] internal static extern bool ShowWindow(IntPtr window,int command);
        [DllImport("user32.dll")] internal static extern bool SetForegroundWindow(IntPtr window);
        [DllImport("user32.dll",CharSet=CharSet.Auto)]
        internal static extern IntPtr SendMessage(IntPtr window,int message,IntPtr wParam,IntPtr lParam);
        internal delegate bool EnumWindowsProc(IntPtr window,IntPtr parameter);
        [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc callback,IntPtr parameter);
        [DllImport("user32.dll",EntryPoint="GetWindowThreadProcessId")]
        static extern uint GetWindowThreadProcessIdForWindow(IntPtr window,out uint processId);
        [DllImport("user32.dll",CharSet=CharSet.Unicode)]
        static extern int GetWindowText(IntPtr window,StringBuilder text,int maxCount);
        [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr window,uint command);
        internal static IntPtr FindTopLevelWindowForProcess(int processId) {
            IntPtr found=IntPtr.Zero;
            EnumWindows(delegate(IntPtr window,IntPtr parameter) {
                uint pid=0;GetWindowThreadProcessIdForWindow(window,out pid);
                if(pid!=(uint)processId || GetWindow(window,4)!=IntPtr.Zero) return true;
                var title=new StringBuilder(256);
                GetWindowText(window,title,title.Capacity);
                if(title.ToString().IndexOf("TelexMini",StringComparison.OrdinalIgnoreCase)>=0) {
                    found=window;return false;
                }
                if(found==IntPtr.Zero) found=window;
                return true;
            },IntPtr.Zero);
            return found;
        }
        [StructLayout(LayoutKind.Sequential)] internal struct Point { public int X,Y; }
        [StructLayout(LayoutKind.Sequential)] internal struct Rect { public int L,T,R,B; }
        [StructLayout(LayoutKind.Sequential)] internal struct GUIInfo {
            public int Size; public uint Flags; public IntPtr Active,Focus,Capture,MenuOwner,MoveSize,Caret; public Rect CaretRect;
        }
        internal static readonly int GUIInfoSize=Marshal.SizeOf(typeof(GUIInfo));
        [StructLayout(LayoutKind.Sequential)] internal struct KBD {
            public uint Key,Scan,Flags,Time; public UIntPtr Extra;
        }
        [StructLayout(LayoutKind.Sequential)] internal struct KEYINPUT {
            public ushort Key,Scan; public uint Flags,Time; public UIntPtr Extra;
        }
        [StructLayout(LayoutKind.Sequential)] internal struct MOUSEINPUT {
            public int X,Y; public uint Data,Flags,Time; public UIntPtr Extra;
        }
        [StructLayout(LayoutKind.Explicit)] internal struct UNION {
            [FieldOffset(0)] public KEYINPUT Keyboard;
            [FieldOffset(0)] public MOUSEINPUT Mouse;
        }
        [StructLayout(LayoutKind.Sequential)] internal struct INPUT { public uint Type; public UNION Data; }
        internal static readonly UIntPtr Marker = new UIntPtr(0x54454C58u);
        internal static INPUT Key(ushort key, ushort scan, uint flags) {
            return new INPUT { Type=1, Data=new UNION { Keyboard=new KEYINPUT { Key=key, Scan=scan, Flags=flags, Extra=Marker } } };
        }
        // If Windows refuses ALL synthesized events, the hook must let the
        // user's original physical key through instead of silently losing it.
        // A partially accepted SendInput batch cannot safely be replayed.
        // The only buffer used by the low-level keyboard hook is per-thread.
        // Scrub its Unicode keystrokes after SendInput returns; never use a
        // process-global ArrayPool because typing data could be retained there.
        [ThreadStatic] static INPUT[] inputScratch;
        internal const int MaxInjectionEvents=4096;
        internal static bool IsSafeEditSize(int erase,int insertLength,bool boundary) {
            if(erase<0 || insertLength<0) return false;
            long events=2L*(erase+(long)insertLength)+(boundary?2:0);
            return events<=MaxInjectionEvents;
        }
        internal static bool EvaluateInjectionResult(uint requested,uint accepted,out bool canForward)
        {
            // Retry is unsafe after partial insertion; original key is forwarded
            // only if Windows accepted exactly zero synthesized events.
            canForward=accepted==0;
            return accepted==requested;
        }
        internal static bool Replace(int erase, string insert, out bool canForward,
                                     ushort followingKey=0)
        {
            if(insert==null || !IsSafeEditSize(erase,insert.Length,followingKey!=0)) {
                // Refuse a pathological batch BEFORE modifying the document.
                canForward=true;
                return false;
            }
            int needed=2*(erase+insert.Length)+(followingKey==0?0:2);
            if(needed==0) { canForward=false;return true; }
            INPUT[] inputs=inputScratch;
            if(inputs==null || inputs.Length<needed) {
                int length=64;
                while(length<needed)length*=2;
                inputs=new INPUT[length]; inputScratch=inputs;
            }
            int p=0;
            try {
                for (int i=0; i<erase; i++) { inputs[p++]=Key(8,0,0); inputs[p++]=Key(8,0,2); }
                foreach (char c in insert) { inputs[p++]=Key(0,c,4); inputs[p++]=Key(0,c,6); }
                if(followingKey!=0) { inputs[p++]=Key(followingKey,0,0); inputs[p++]=Key(followingKey,0,2); }
                uint count=SendInput((uint)p,inputs,Marshal.SizeOf(typeof(INPUT)));
                // Zero accepted: original physical key is safe to forward.
                // Partially accepted: do NOT retry (could duplicate/delete text).
                return EvaluateInjectionResult((uint)p,count,out canForward);
            } finally {
                Array.Clear(inputs,0,p);
            }
        }
    }
    internal sealed class Keyboard : IDisposable
    {
        readonly Native.HookProc keyProc, mouseProc;
        IntPtr keyHook, mouseHook, foreground, focus;
        readonly NativeComposer engine = new NativeComposer { SmartEnglish=true };
        bool enabled=true;
        bool suspended, disposed;
        bool baseSmartEnglish=true,basePreferEnglishExact=false;
        readonly InputContextMonitor context;
        int contextRevision=-1;
        internal bool AutoEnglish=false;
        internal bool SnippetsEnabled=false;
        internal bool ProfilesEnabled=false;
        string activeProfile="Default";
        IDictionary<string,string> snippets=Productivity.ReadSnippets();
        ClipboardMacroSnapshot clipboardSnapshot;
        readonly ExpansionUndo expansionUndo=new ExpansionUndo();
        bool suppressOneExpansion;
        IDictionary<string,string> cachedProfiles=Productivity.ParseProfiles(Productivity.ReadProfiles());
        internal void InstallIntegrationSnippets(IDictionary<string,string> testSnippets) {
            if(!AcceptTestInput)throw new InvalidOperationException("Integration mode required.");
            snippets=testSnippets ?? new Dictionary<string,string>();
            SnippetsEnabled=true;
        }
        internal void ReloadNativeDictionary() {
            engine.ReloadLexicon();
        }
        internal void ReloadProductivity() {
            snippets=Productivity.ReadSnippets();
            bool needsClipboard=false;
            foreach(var item in snippets.Values)
                if(item.IndexOf("{clipboard}",StringComparison.Ordinal)>=0) {
                    needsClipboard=true; break;
                }
            // Prepare the worker on the native UI thread, not inside the hook.
            if(SnippetsEnabled && needsClipboard && clipboardSnapshot==null)
                clipboardSnapshot=new ClipboardMacroSnapshot();
            if((!SnippetsEnabled || !needsClipboard) && clipboardSnapshot!=null) {
                clipboardSnapshot.Dispose(); clipboardSnapshot=null;
            }
            cachedProfiles=Productivity.ParseProfiles(Productivity.ReadProfiles());
            string nextProfile=ProfilesEnabled?Productivity.GetProfile(cachedProfiles,ForegroundProcess(Native.GetForegroundWindow())):"Default";
            if(activeProfile!=nextProfile){activeProfile=nextProfile;ApplyProfile();}
        }
        void ApplyProfile() {
            expansionUndo.Clear(); suppressOneExpansion=false;
            if(clipboardSnapshot!=null)clipboardSnapshot.Cancel();
            engine.SmartEnglish=activeProfile=="Vietnamese" ? false :
                activeProfile=="Balanced" ? true : baseSmartEnglish;
            engine.PreferEnglishExact=activeProfile=="Balanced" ? false : basePreferEnglishExact;
            engine.Reset();
        }
        static string ForegroundProcess(IntPtr window) {
            try {
                uint pid;
                Native.GetWindowThreadProcessIdWithPid(window,out pid);
                using(var process=Process.GetProcessById((int)pid)) return process.ProcessName;
            } catch(Exception) {return "";}
        }
        internal bool PreferEnglishExact {
            get {return basePreferEnglishExact;}
            set {if(basePreferEnglishExact==value)return; basePreferEnglishExact=value;ApplyProfile();}
        }
        internal bool UseVni {
            get { return engine.UseVni; }
            set { if(engine.UseVni==value)return; engine.UseVni=value; engine.Reset(); }
        }
        internal bool RestoreInvalid=true;
        internal bool SmartEnglish {
            get { return baseSmartEnglish; }
            set { if(baseSmartEnglish==value)return; baseSmartEnglish=value;ApplyProfile(); }
        }
        internal InputContextKind ContextKind {
            get {
                if(context==null || !enabled || suspended) return InputContextKind.Text;
                IntPtr window=Native.GetForegroundWindow();
                IntPtr focused=InputContextMonitor.FocusOf(window);
                if(InputContextMonitor.IsNativePassword(focused)) return InputContextKind.Password;
                return context.GetKind(window,focused);
            }
        }
        internal bool EffectiveEnabled { get { return ContextPolicy.UseVietnamese(enabled,AutoEnglish,ContextKind) && activeProfile!="English"; } }
        internal bool AcceptTestInput = false;
        internal event Action InjectionFailed;
        internal bool Enabled {
            get {return enabled;}
            set {
                if(enabled==value)return;
                if(clipboardSnapshot!=null)clipboardSnapshot.Cancel();
                expansionUndo.Clear(); suppressOneExpansion=false;
                enabled=value;engine.Reset();UpdateHooks();
            }
        }
        internal bool Suspended { get { return suspended; } set { if(suspended==value) return; if(clipboardSnapshot!=null)clipboardSnapshot.Cancel(); expansionUndo.Clear(); suppressOneExpansion=false; suspended=value; engine.Reset(); UpdateHooks(); } }
        internal bool HooksInstalled { get { return keyHook!=IntPtr.Zero || mouseHook!=IntPtr.Zero; } }
        internal Keyboard(InputContextMonitor monitor=null)
        {
            context=monitor;
            keyProc=OnKey; mouseProc=OnMouse;
            UpdateHooks();
        }
        internal void SyncBackend() { UpdateHooks(); }
        void UpdateHooks()
        {
            // One non-admin Windows input transport; no system IME registration.
            if(disposed || suspended || !enabled) {
                RemoveHooks(); return;
            }
            if(keyHook!=IntPtr.Zero) return;
            IntPtr module=Native.GetModuleHandle(null);
            keyHook=Native.SetWindowsHookEx(13,keyProc,module,0);
            if (keyHook == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            mouseHook=Native.SetWindowsHookEx(14,mouseProc,module,0);
            if (mouseHook == IntPtr.Zero) { int error=Marshal.GetLastWin32Error(); RemoveHooks(); throw new Win32Exception(error); }
        }
        static bool Down(int key) { return Native.GetAsyncKeyState(key) < 0; }
        IntPtr OnMouse(int code, IntPtr message, IntPtr data)
        {
            int m=message.ToInt32();
            if (code >= 0 && (m==0x201 || m==0x204 || m==0x207 || m==0x20B || m==0x20A || m==0x20E)) {
                expansionUndo.Clear(); suppressOneExpansion=false;
                engine.Reset(); if(context!=null) context.RequestCheck();
            }
            return Native.CallNextHookEx(mouseHook,code,message,data);
        }
        long hookSamples, hookTotalTicks, hookMaximumTicks;
        internal string HookDiagnostics() {
            long count=Interlocked.Read(ref hookSamples);
            long total=Interlocked.Read(ref hookTotalTicks);
            long maximum=Interlocked.Read(ref hookMaximumTicks);
            double scale=1000.0 / Stopwatch.Frequency;
            return count.ToString(CultureInfo.InvariantCulture) + "\t" +
                   (count>0?total*scale/count:0).ToString("F4",CultureInfo.InvariantCulture) + "\t" +
                   (maximum*scale).ToString("F4",CultureInfo.InvariantCulture);
        }
        void PrepareClipboardSnapshot(string word,InputContextKind kind)
        {
            string macro;
            if(!SnippetsEnabled || kind!=InputContextKind.Text ||
               !snippets.TryGetValue(word,out macro) ||
               macro.IndexOf("{clipboard}",StringComparison.Ordinal)<0) {
                if(clipboardSnapshot!=null)clipboardSnapshot.Cancel();
                return;
            }
            if(clipboardSnapshot!=null)clipboardSnapshot.Request(word);
        }
        IntPtr OnKey(int code, IntPtr message, IntPtr data)
        {
            long started=Stopwatch.GetTimestamp();
            try {return ProcessKey(code,message,data);}
            finally {
                long ticks=Stopwatch.GetTimestamp()-started;
                if(ticks>=0 && ticks<Stopwatch.Frequency*2) {
                    Interlocked.Increment(ref hookSamples);
                    Interlocked.Add(ref hookTotalTicks,ticks);
                    long previous;
                    do {
                        previous=Interlocked.Read(ref hookMaximumTicks);
                        if(previous>=ticks) break;
                    } while(Interlocked.CompareExchange(ref hookMaximumTicks,ticks,previous)!=previous);
                }
            }
        }
        IntPtr ProcessKey(int code, IntPtr message, IntPtr data)
        {
            if (code < 0)
                return Native.CallNextHookEx(keyHook,code,message,data);
            var key=Marshal.PtrToStructure<Native.KBD>(data);
            if (key.Extra == Native.Marker) return Native.CallNextHookEx(keyHook,code,message,data);
            if ((key.Flags & 0x10) != 0 && !AcceptTestInput) { engine.Reset(); return Native.CallNextHookEx(keyHook,code,message,data); }
            int m=message.ToInt32();
            if (m!=0x100 && m!=0x104) return Native.CallNextHookEx(keyHook,code,message,data);
            uint vk=key.Key;
            // Only characters, deletion and word boundaries need a focused-control
            // lookup. Function/navigation/modifier keys invalidate composition and
            // pass through without GetGUIThreadInfo/UIA/foreground process lookup.
            // Any subsequent text key revalidates exact HWND and password style.
            bool textKey=(vk>=0x41 && vk<=0x5A) ||
                (engine.UseVni && vk>=0x31 && vk<=0x39);
            bool boundaryKey=vk==32 || vk==13 || vk==9 ||
                (vk>=0xBA && vk<=0xC0) || (vk>=0xDB && vk<=0xDE);
            if(!textKey && !boundaryKey && vk!=8) {
                if(vk!=0x10 && vk!=0xA0 && vk!=0xA1 && vk!=0x14) {
                    if(clipboardSnapshot!=null)clipboardSnapshot.Cancel();
                    expansionUndo.Clear();suppressOneExpansion=false;engine.Reset();
                }
                return Native.CallNextHookEx(keyHook,code,message,data);
            }
            IntPtr window=Native.GetForegroundWindow();
            uint focusedPid=0;
            uint focusThread=Native.GetWindowThreadProcessIdWithPid(window,out focusedPid);
            var info=new Native.GUIInfo { Size=Native.GUIInfoSize };
            if(focusThread==0 || !Native.GetGUIThreadInfo(focusThread,ref info) || info.Focus==IntPtr.Zero) {
                if(clipboardSnapshot!=null)clipboardSnapshot.Cancel();
                expansionUndo.Clear();suppressOneExpansion=false;engine.Reset();
                return Native.CallNextHookEx(keyHook,code,message,data);
            }
            if (foreground!=window || focus!=info.Focus) {
                if(clipboardSnapshot!=null)clipboardSnapshot.Cancel();
                expansionUndo.Clear(); suppressOneExpansion=false;
                engine.Reset(); foreground=window; focus=info.Focus;
                activeProfile=ProfilesEnabled?Productivity.GetProfile(cachedProfiles,ForegroundProcess(window)):"Default";
                ApplyProfile();
                if(context!=null) context.RequestCheck();
            }
            if(context!=null && contextRevision!=context.Current.Revision) { if(clipboardSnapshot!=null)clipboardSnapshot.Cancel(); expansionUndo.Clear(); suppressOneExpansion=false; engine.Reset(); contextRevision=context.Current.Revision; }
            InputContextKind kind=InputContextMonitor.IsNativePassword(info.Focus) ? InputContextKind.Password :
                context==null ? InputContextKind.Text : context.GetKind(window,info.Focus,focusedPid);
            if(activeProfile=="English" || !ContextPolicy.UseVietnamese(enabled,AutoEnglish,kind)) {
                if(clipboardSnapshot!=null)clipboardSnapshot.Cancel();
                expansionUndo.Clear(); suppressOneExpansion=false;
                engine.Reset(); return Native.CallNextHookEx(keyHook,code,message,data);
            }
            if (Down(0x11) || Down(0x12) || Down(0x5B) || Down(0x5C)) { expansionUndo.Clear(); suppressOneExpansion=false; engine.Reset(); return Native.CallNextHookEx(keyHook,code,message,data); }
            if(vk!=8 && vk!=0x10 && vk!=0xA0 && vk!=0xA1 && vk!=0x14) {
                expansionUndo.Clear();
                if(vk!=32)suppressOneExpansion=false;
            }
            if (vk==8) {
                if(clipboardSnapshot!=null)clipboardSnapshot.Cancel();
                int erase;string insert;
                if(kind==InputContextKind.Text &&
                   expansionUndo.TryTake(window,info.Focus,out erase,out insert)) {
                    bool canForward;
                    if(Native.Replace(erase,insert,out canForward)) {
                        engine.RestoreLiteralWord(insert);
                        suppressOneExpansion=true;
                        return new IntPtr(1);
                    }
                    engine.Reset();
                    if(InjectionFailed!=null)InjectionFailed();
                    if(!canForward)return new IntPtr(1);
                }
                engine.Backspace();return Native.CallNextHookEx(keyHook,code,message,data);
            }
            if ((vk>=0x41 && vk<=0x5A) ||
                (engine.UseVni && vk>=0x31 && vk<=0x39 && !Down(0x10))) {
                char c=(char)vk;
                if (!(Down(0x10) ^ ((Native.GetKeyState(0x14)&1)!=0))) c=char.ToLowerInvariant(c);
                string before=engine.Text, after=engine.Push(c);
                PrepareClipboardSnapshot(after,kind);
                if (after==before+c) return Native.CallNextHookEx(keyHook,code,message,data);
                TextEditPlan edit=TextEditPlan.Between(before,after);
                bool canForward;
                if (!Native.Replace(edit.Erase,edit.Insert,out canForward)) {
                    engine.Reset();
                    if (InjectionFailed!=null) InjectionFailed();
                    if(canForward) return Native.CallNextHookEx(keyHook,code,message,data);
                }
                return new IntPtr(1);
            }
            if(vk==32 || vk==13 || vk==9 || (vk>=0xBA && vk<=0xC0) || (vk>=0xDB && vk<=0xDE)) {
                string before=engine.Text, after=engine.Finish(RestoreInvalid);
                string expanded=null;
                // Expansion is opt-in and only at a real word boundary.
                // Never expand in password/unknown fields or excluded apps.
                if(SnippetsEnabled && !suppressOneExpansion && kind==InputContextKind.Text &&
                   !string.IsNullOrEmpty(before)) {
                    string macro;
                    if(snippets.TryGetValue(before,out macro) &&
                       macro.IndexOf("{clipboard}",StringComparison.Ordinal)>=0) {
                        string snapshot;
                        if(clipboardSnapshot!=null && clipboardSnapshot.TryGet(before,out snapshot))
                            expanded=Productivity.Expand(before,snippets,true,delegate{return snapshot;});
                    } else {
                        expanded=Productivity.Expand(before,snippets,true);
                    }
                    if(expanded!=null) after=expanded;
                }
                if(clipboardSnapshot!=null)clipboardSnapshot.Cancel();
                suppressOneExpansion=false;
                engine.Reset();
                if(before!=after) {
                    TextEditPlan edit=TextEditPlan.Between(before,after);
                    bool canForward;
                    if(!Native.Replace(edit.Erase,edit.Insert,out canForward,(ushort)vk)) {
                        engine.Reset();
                        if(InjectionFailed!=null) InjectionFailed();
                        if(canForward) return Native.CallNextHookEx(keyHook,code,message,data);
                    } else if(expanded!=null && vk==32 && kind==InputContextKind.Text) {
                        expansionUndo.Arm(before,after,window,info.Focus);
                    }
                    return new IntPtr(1);
                }
            }
            if (vk!=0x10 && vk!=0xA0 && vk!=0xA1 && vk!=0x14) { if(clipboardSnapshot!=null)clipboardSnapshot.Cancel(); expansionUndo.Clear(); suppressOneExpansion=false; engine.Reset(); }
            return Native.CallNextHookEx(keyHook,code,message,data);
        }
        // Explicit safe recovery after resume/session-unlock or via tray command.
        // Do not reinstall hooks in E mode or while suspended for games/remote.
        internal bool TryRepairHooks()
        {
            if(disposed)return false;
            if(clipboardSnapshot!=null)clipboardSnapshot.Cancel();
            expansionUndo.Clear(); suppressOneExpansion=false;
            engine.Reset();
            RemoveHooks();
            if(suspended || !enabled)return true;
            try {
                UpdateHooks();
                return keyHook!=IntPtr.Zero && mouseHook!=IntPtr.Zero;
            } catch(Win32Exception) {
                RemoveHooks(); // Fail open: Windows still receives physical keys.
                return false;
            }
        }
        public void Dispose()
        {
            disposed=true; RemoveHooks();
            if(clipboardSnapshot!=null)clipboardSnapshot.Dispose();
            engine.Dispose();
        }
        void RemoveHooks()
        {
            if (keyHook!=IntPtr.Zero) { Native.UnhookWindowsHookEx(keyHook); keyHook=IntPtr.Zero; }
            if (mouseHook!=IntPtr.Zero) { Native.UnhookWindowsHookEx(mouseHook); mouseHook=IntPtr.Zero; }
        }
    }
}
