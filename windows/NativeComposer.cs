using System;
using System.IO;
using System.Runtime.InteropServices;

namespace TelexMini
{
    // Telex/VNI composition runs exclusively in the portable C++ engine.
    // Windows uses a per-user keyboard hook to route keys to the portable
    // C++ Telex/VNI composer. No privileged input service or typing log.
    // Returned UTF-16 buffers are owned by the C++ instance.
    internal sealed class NativeComposer : IDisposable
    {
        const string EngineDll="TelexMiniEngine.dll";
        [DllImport(EngineDll,CallingConvention=CallingConvention.Cdecl,
            ExactSpelling=true,EntryPoint="TelexMiniEngine_ApiVersion")]
        static extern uint ApiVersion();
        [DllImport(EngineDll,CallingConvention=CallingConvention.Cdecl,
            CharSet=CharSet.Unicode,ExactSpelling=true,EntryPoint="TelexMiniEngine_Create")]
        static extern IntPtr Create(string seed,string english,string vietnamese);
        [DllImport(EngineDll,CallingConvention=CallingConvention.Cdecl,
            ExactSpelling=true,EntryPoint="TelexMiniEngine_Destroy")]
        static extern void Destroy(IntPtr handle);
        [DllImport(EngineDll,CallingConvention=CallingConvention.Cdecl,
            ExactSpelling=true,EntryPoint="TelexMiniEngine_Configure")]
        [return: MarshalAs(UnmanagedType.I1)]
        static extern bool Configure(IntPtr handle,
            [MarshalAs(UnmanagedType.I1)] bool smart,
            [MarshalAs(UnmanagedType.I1)] bool englishFirst,
            [MarshalAs(UnmanagedType.I1)] bool vni,
            [MarshalAs(UnmanagedType.I1)] bool restore);
        [DllImport(EngineDll,CallingConvention=CallingConvention.Cdecl,
            ExactSpelling=true,EntryPoint="TelexMiniEngine_Reset")]
        static extern void NativeReset(IntPtr handle);
        [DllImport(EngineDll,CallingConvention=CallingConvention.Cdecl,
            ExactSpelling=true,EntryPoint="TelexMiniEngine_Backspace")]
        static extern void NativeBackspace(IntPtr handle);
        [DllImport(EngineDll,CallingConvention=CallingConvention.Cdecl,
            ExactSpelling=true,EntryPoint="TelexMiniEngine_Text")]
        static extern IntPtr NativeText(IntPtr handle);
        [DllImport(EngineDll,CallingConvention=CallingConvention.Cdecl,
            ExactSpelling=true,EntryPoint="TelexMiniEngine_Push")]
        static extern IntPtr NativePush(IntPtr handle,[MarshalAs(UnmanagedType.U2)] char key);
        [DllImport(EngineDll,CallingConvention=CallingConvention.Cdecl,
            ExactSpelling=true,EntryPoint="TelexMiniEngine_Finish")]
        static extern IntPtr NativeFinish(IntPtr handle);
        [DllImport(EngineDll,CallingConvention=CallingConvention.Cdecl,
            CharSet=CharSet.Unicode,ExactSpelling=true,EntryPoint="TelexMiniEngine_Restore")]
        [return: MarshalAs(UnmanagedType.I1)]
        static extern bool NativeRestore(IntPtr handle,string word);
        [DllImport(EngineDll,CallingConvention=CallingConvention.Cdecl,
            ExactSpelling=true,EntryPoint="TelexMiniEngine_Reload")]
        [return: MarshalAs(UnmanagedType.I1)]
        static extern bool NativeReload(IntPtr handle);

        IntPtr handle;
        string textCache="";
        bool smartEnglish=true,englishFirst, vni, restoreInvalid=true;
        public NativeComposer() {
            if(ApiVersion()!=1)
                throw new InvalidOperationException("Unsupported native TelexMini engine API.");
            string seed=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"english_seed.txt");
            if(!File.Exists(seed))
                throw new FileNotFoundException("Native engine dictionary is missing.",seed);
            string english=File.Exists(EnglishLexicon.EnglishPath)?EnglishLexicon.EnglishPath:
                Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"EnglishWords.txt");
            string vietnamese=File.Exists(EnglishLexicon.VietnamesePath)?EnglishLexicon.VietnamesePath:
                Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"VietnameseOverrides.txt");
            handle=Create(seed,english,vietnamese);
            if(handle==IntPtr.Zero)throw new InvalidOperationException("Cannot initialize native composer.");
            if(!Configure(handle,smartEnglish,englishFirst,vni,restoreInvalid))
                throw new InvalidOperationException("Cannot configure native composer.");
        }
        static string Decode(IntPtr p) {return p==IntPtr.Zero?null:Marshal.PtrToStringUni(p);}
        void EnsureOpen(){if(handle==IntPtr.Zero)throw new ObjectDisposedException("NativeComposer");}
        void Reconfigure() {
            EnsureOpen();
            if(!Configure(handle,smartEnglish,englishFirst,vni,restoreInvalid))
                throw new InvalidOperationException("Native composer configuration failed.");
        }
        public bool SmartEnglish {
            get {return smartEnglish;}
            set {if(smartEnglish!=value){smartEnglish=value;Reconfigure();}}
        }
        public bool PreferEnglishExact {
            get {return englishFirst;}
            set {if(englishFirst!=value){englishFirst=value;Reconfigure();}}
        }
        public bool UseVni {
            get {return vni;}
            set {if(vni!=value){vni=value;Reconfigure();}}
        }
        public string Text {
            get {EnsureOpen();return textCache;}
        }
        public string Push(char key) {
            EnsureOpen();
            var value=Decode(NativePush(handle,key));
            if(value==null)throw new InvalidOperationException("Native Telex engine Push failed.");
            textCache=value;
            return textCache;
        }
        public string Finish(bool restore) {
            EnsureOpen();
            if(restoreInvalid!=restore){restoreInvalid=restore;Reconfigure();}
            var value=Decode(NativeFinish(handle));
            if(value==null)throw new InvalidOperationException("Native Telex engine Finish failed.");
            return value;
        }
        public void Reset() {EnsureOpen();NativeReset(handle);textCache="";}
        public void Backspace() {EnsureOpen();NativeBackspace(handle);
            textCache=Decode(NativeText(handle))??"";}
        internal void RestoreLiteralWord(string text) {
            EnsureOpen();
            if(!NativeRestore(handle,text??""))
                throw new InvalidOperationException("Native Telex engine Restore failed.");
            textCache=text??"";
        }
        internal void ReloadLexicon() {
            EnsureOpen();
            if(!NativeReload(handle))
                throw new InvalidOperationException("Native Telex engine Lexicon reload failed.");
            textCache="";
        }
        ~NativeComposer() {Close();}
        void Close() {
            var h=handle;handle=IntPtr.Zero;
            if(h!=IntPtr.Zero)Destroy(h);
        }
        public void Dispose() {Close();GC.SuppressFinalize(this);}
    }
}
