using System;
using System.Threading;
using System.Windows.Forms;

namespace TelexMini
{
    // Dedicated STA worker: a busy clipboard must NEVER block WH_KEYBOARD_LL.
    // A snapshot is requested only when a user types the final character of
    // a configured shortcut containing {clipboard}, not through polling.
    // If the snapshot is not ready at the word boundary, leave typed text intact.
    internal sealed class ClipboardMacroSnapshot : IDisposable
    {
        readonly object gate = new object();
        readonly AutoResetEvent wake = new AutoResetEvent(false);
        readonly Thread worker;
        readonly Func<string> reader;
        bool stopping;
        int generation, readyGeneration=-1;
        string requestedWord, readyText;

        internal ClipboardMacroSnapshot(Func<string> provider=null)
        {
            reader=provider ?? delegate {
                return Clipboard.ContainsText(TextDataFormat.UnicodeText)
                    ? Clipboard.GetText(TextDataFormat.UnicodeText) : "";
            };
            worker=new Thread(Work) {IsBackground=true,Name="TelexMini clipboard snapshot"};
            worker.SetApartmentState(ApartmentState.STA);
            worker.Start();
        }
        internal void Request(string word)
        {
            if(string.IsNullOrEmpty(word)) {Cancel();return;}
            lock(gate) {
                if(stopping || string.Equals(word,requestedWord,StringComparison.OrdinalIgnoreCase))return;
                generation++;
                requestedWord=word;
                readyGeneration=-1;
                readyText=null;
            }
            wake.Set();
        }
        internal bool TryGet(string word,out string value)
        {
            lock(gate) {
                if(readyGeneration==generation &&
                   string.Equals(requestedWord,word,StringComparison.OrdinalIgnoreCase)) {
                    value=readyText;
                    return true;
                }
            }
            value=null;
            return false;
        }
        internal void Cancel()
        {
            lock(gate) {
                if(requestedWord==null)return;
                generation++;
                requestedWord=null;
                readyText=null;
                readyGeneration=-1;
            }
        }
        void Work()
        {
            while(true) {
                wake.WaitOne();
                int version;
                lock(gate) {
                    if(stopping)return;
                    if(requestedWord==null)continue;
                    version=generation;
                }
                string content="";
                try {content=reader() ?? "";}
                catch(System.Runtime.InteropServices.ExternalException) {}
                catch(ThreadStateException) {}
                catch(InvalidOperationException) {}
                // Bound both memory and the generated insertion size.
                if(content.Length>1024)content=content.Substring(0,1024);
                content=content.Replace('\r',' ').Replace('\n',' ').Replace('\t',' ');
                lock(gate) {
                    if(!stopping && version==generation) {
                        readyText=content;
                        readyGeneration=version;
                    }
                }
            }
        }
        public void Dispose()
        {
            lock(gate) {
                stopping=true;
                generation++;
                requestedWord=null;
                readyText=null;
            }
            wake.Set();
            // Clipboard providers owned by other programs may be stalled.
            // Never wait indefinitely to terminate the input engine.
            if(worker.Join(100))wake.Dispose();
        }
    }
}
