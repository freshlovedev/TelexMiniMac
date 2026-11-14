using System;

namespace TelexMini
{
    // Pure tail-edit contract between the composer and a Windows text control.
    // No handles, keystrokes, clipboard access, or operating-system calls.
    // Both the hook and simulated text-control tests use this same plan.
    internal struct TextEditPlan
    {
        internal readonly int Erase;
        internal readonly string Insert;
        internal bool IsAppend { get {return Erase==0;} }
        TextEditPlan(int erase,string insert) {Erase=erase;Insert=insert;}
        internal static TextEditPlan Between(string before,string after)
        {
            if(before==null || after==null) throw new ArgumentNullException();
            int common=0;
            while(common<before.Length && common<after.Length &&
                  before[common]==after[common]) common++;
            return new TextEditPlan(before.Length-common,after.Substring(common));
        }
        // Simulates insertion into a scratch text field with the caret at the
        // end. No content is read from or written to an actual user document.
        internal string Apply(string field)
        {
            if(field==null || field.Length<Erase)
                throw new InvalidOperationException("Invalid text-edit boundary.");
            return field.Substring(0,field.Length-Erase)+Insert;
        }
    }
}
