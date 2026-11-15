using System;

namespace TelexMini
{
    // One-step, focus-bound undo of a user-triggered text expansion.
    // Only the very next Backspace may undo; mouse/focus/another key cancels.
    // Enter/Tab, surrogate pairs, passwords and unknown contexts are excluded.
    internal sealed class ExpansionUndo
    {
        string shortcut, expansion;
        IntPtr window, focus;
        internal void Clear() {shortcut=null; expansion=null; window=IntPtr.Zero; focus=IntPtr.Zero;}
        internal bool Arm(string key,string value,IntPtr targetWindow,IntPtr targetFocus)
        {
            Clear();
            if(string.IsNullOrEmpty(key) || string.IsNullOrEmpty(value) ||
               targetWindow==IntPtr.Zero || targetFocus==IntPtr.Zero ||
               key.Length<2 || key.Length>48 || value.Length>80)return false;
            foreach(char c in key)
                if(!(c>='a'&&c<='z'||c>='A'&&c<='Z'))return false;
            foreach(char c in value)
                if(char.IsSurrogate(c) || c=='\r' || c=='\n' || c=='\t')return false;
            shortcut=key; expansion=value;window=targetWindow;focus=targetFocus;
            return true;
        }
        internal bool TryTake(IntPtr targetWindow,IntPtr targetFocus,
                              out int erase,out string insert)
        {
            erase=0;insert=null;
            if(shortcut==null || targetWindow!=window || targetFocus!=focus) {
                Clear();
                return false;
            }
            erase=expansion.Length+1; // Expansion and synthetic SPACE.
            insert=shortcut;
            Clear();
            return true;
        }
    }
}
