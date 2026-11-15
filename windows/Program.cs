using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace TelexMini
{
    internal sealed class MainForm : Form
    {
        readonly Keyboard keyboard;
        readonly NotifyIcon tray;
        readonly Button toggle,hide,exit;
        readonly Label status;
        readonly ToolStripMenuItem switchItem;
        readonly InputContextMonitor context;
        readonly System.Windows.Forms.Timer modeTimer;
        readonly CheckBox autoEnglish, restoreWords, smartEnglish;
        readonly GameGuard gameGuard;
        readonly ToolStripMenuItem pauseItem;
        ModernChrome chrome;
        bool gameActive, manualPause;
        string displayedMode="";
        Icon vietIcon, englishIcon;
        bool registered, cleaned;
        internal MainForm()
        {
            // Flutter owns the visible desktop UI when installed alongside the native engine.
            Shown+=delegate {
                if(SharedUiLauncher.OpenOrActivate()) {
                    BeginInvoke((Action)delegate { Hide(); ShowInTaskbar=false; });
                }
            };
            Text="Telex Mini"; ClientSize=new Size(334,306); FormBorderStyle=FormBorderStyle.FixedSingle;
            MaximizeBox=false; ShowInTaskbar=true; StartPosition=FormStartPosition.CenterScreen; TopMost=true;
            BackColor=Color.FromArgb(246,248,251); Font=new Font("Segoe UI",10);
            vietIcon=MakeIcon("V",Color.FromArgb(0,183,164)); englishIcon=MakeIcon("E",Color.FromArgb(0,183,164));
            Icon=AppIcons.Brand;
            toggle=new Button { Location=new Point(18,18), Size=new Size(298,56), FlatStyle=FlatStyle.Flat,
                Font=new Font("Segoe UI",15,FontStyle.Bold), ForeColor=Color.White, Cursor=Cursors.Hand, TabStop=false };
            toggle.FlatAppearance.BorderSize=0;
            status=new Label { Location=new Point(18,83), Size=new Size(298,68), TextAlign=ContentAlignment.MiddleCenter };
            hide=new Button { Text=UiText.T("Thu xuống khay"), Location=new Point(18,262), Size=new Size(175,28), TabStop=false };
            exit=new Button { Text=UiText.T("Thoát"), Location=new Point(203,262), Size=new Size(113,28), TabStop=false };
            Controls.AddRange(new Control[] { toggle,status,hide,exit });
            autoEnglish=new CheckBox { Text=UiText.T("Tự dùng English trong terminal"), Location=new Point(18,157), Size=new Size(298,25),
                Checked=UserPreferences.Bool("AutoEnglish",false), TabStop=false };
            restoreWords=new CheckBox { Text=UiText.T("Khôi phục từ không hợp lệ"), Location=new Point(18,186), Size=new Size(298,25),
                Checked=UserPreferences.Bool("RestoreInvalid",true), TabStop=false };
            smartEnglish=new CheckBox { Text=UiText.T("Bảo vệ từ tiếng Anh (offline)"), Location=new Point(18,215), Size=new Size(298,25),
                Checked=UserPreferences.Bool("SmartEnglish",true), TabStop=false };
            Controls.AddRange(new Control[] { autoEnglish,restoreWords,smartEnglish });
            context=new InputContextMonitor();
            keyboard=new Keyboard(context);
            keyboard.Enabled=UserPreferences.Bool("VietnameseEnabled",true);
            keyboard.AutoEnglish=autoEnglish.Checked;
            keyboard.RestoreInvalid=restoreWords.Checked;
            keyboard.SmartEnglish=smartEnglish.Checked &&
                UserPreferences.String("LanguagePriority","Balanced")!="Vietnamese";
            keyboard.PreferEnglishExact=UserPreferences.String("LanguagePriority","Balanced")=="English";
            keyboard.UseVni=UserPreferences.String("InputMethod","Telex")=="VNI";
            keyboard.SnippetsEnabled=UserPreferences.Bool("SnippetsEnabled",false);
            keyboard.ProfilesEnabled=UserPreferences.Bool("ProfilesEnabled",false);
            autoEnglish.CheckedChanged+=delegate { keyboard.AutoEnglish=autoEnglish.Checked; UserPreferences.Set("AutoEnglish",autoEnglish.Checked); keyboard.Enabled=keyboard.Enabled; SyncPerformance(); UpdateMode(); };
            restoreWords.CheckedChanged+=delegate { keyboard.RestoreInvalid=restoreWords.Checked; UserPreferences.Set("RestoreInvalid",restoreWords.Checked); };
            smartEnglish.CheckedChanged+=delegate {
                keyboard.SmartEnglish=smartEnglish.Checked &&
                    UserPreferences.String("LanguagePriority","Balanced")!="Vietnamese";
                UserPreferences.Set("SmartEnglish",smartEnglish.Checked); UpdateMode();
            };
            var menu=new ContextMenuStrip();
            switchItem=new ToolStripMenuItem("",null,delegate { Toggle(); }); menu.Items.Add(switchItem);
            pauseItem=new ToolStripMenuItem("Tạm dừng hoàn toàn: game / remote") { CheckOnClick=true };
            pauseItem.CheckedChanged+=delegate { manualPause=pauseItem.Checked; SyncPerformance(); UpdateMode(); };
            menu.Items.Add(pauseItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(UiText.T("Từ điển tiếng Anh")+"...",null,delegate { EditDictionary(false); });
            menu.Items.Add(UiText.T("Ưu tiên Telex")+"...",null,delegate { EditDictionary(true); });
            menu.Items.Add(UiText.T("↻  Nạp lại từ điển"),null,delegate { EnglishLexicon.Reload(); keyboard.SmartEnglish=keyboard.SmartEnglish; UpdateMode(); });
            menu.Items.Add(UiText.T("⚙  Cài đặt nâng cao")+"...",null,delegate { OpenAdvanced(); });
            menu.Items.Add(UiText.T("⚡  Gõ tắt & ứng dụng")+"...",null,delegate { OpenProductivity(); });
            menu.Items.Add(UiText.T("⌘  Ký tự nhanh")+"...",null,delegate { OpenSymbols(); });
            menu.Items.Add(UiText.T("Kiểm tra bản cập nhật..."),null,delegate {
                try {
                    System.Diagnostics.Process.Start("https://github.com/muahacodon321-boop/TelexMiniMac/releases");
                } catch(Exception ex) {
                    MessageBox.Show(this,ex.Message,"TelexMini",MessageBoxButtons.OK,MessageBoxIcon.Information);
                }
            });
            menu.Items.Add(UiText.T("Mở TelexMini"),null,delegate { OpenSharedUiOrFallback(); });
            menu.Items.Add(new ToolStripSeparator()); menu.Items.Add(UiText.T("Thoát"),null,delegate { Close(); });
            tray=new NotifyIcon { Icon=vietIcon, Text=UiText.T("Telex Mini — Tiếng Việt"), ContextMenuStrip=menu, Visible=true };
            tray.MouseClick+=delegate(object sender, MouseEventArgs e) {
                if(e.Button==MouseButtons.Left) OpenSharedUiOrFallback();
            };
            tray.MouseDoubleClick+=delegate { OpenSharedUiOrFallback(); };
            toggle.Click+=delegate { Toggle(); };
            hide.Click+=delegate { WindowState=FormWindowState.Normal; Hide(); };
            exit.Click+=delegate { Close(); };
            // Standard Windows minimize remains on the taskbar.
            // Only the explicit hide button sends this window to the tray.
            keyboard.InjectionFailed+=delegate { BeginInvoke((Action)delegate { tray.ShowBalloonTip(3500,UiText.T("Không thay được ký tự"),UiText.T("Ứng dụng đích có thể đang chạy quyền quản trị. Xem HUONG-DAN.md."),ToolTipIcon.Info); }); };
            RegisterShortcut();
            modeTimer=new System.Windows.Forms.Timer { Interval=150 };
            gameGuard=new GameGuard(delegate(bool active) { gameActive=active; SyncPerformance(); UpdateMode(); });
            modeTimer.Tick+=delegate { RefreshExternalSettings(); gameGuard.Check(); UpdateMode(); }; modeTimer.Start();
            RebuildChrome();
            SyncPerformance();
            UpdateMode();
        }
        void RebuildChrome() {
            chrome=new ModernChrome(this,toggle,status,autoEnglish,restoreWords,smartEnglish,hide,exit,
                delegate {EditDictionary(false);},
                delegate {EditDictionary(true);},
                delegate {EnglishLexicon.Reload();keyboard.SmartEnglish=keyboard.SmartEnglish;},
                delegate {OpenAdvanced();},
                delegate {OpenProductivity();},
                delegate {OpenSymbols();});
        }
        void OpenProductivity() {
            keyboard.Suspended=true;
            try {
                if(ProductivitySettings.Open(this)) {
                    keyboard.SnippetsEnabled=UserPreferences.Bool("SnippetsEnabled",false);
                    keyboard.ProfilesEnabled=UserPreferences.Bool("ProfilesEnabled",false);
                    keyboard.ReloadProductivity();
                }
            } finally {SyncPerformance();UpdateMode();}
        }
        void OpenSymbols() {
            keyboard.Suspended=true;
            try {using(var picker=new SymbolPicker()) picker.ShowDialog(this);}
            finally {SyncPerformance();UpdateMode();}
        }
        void RegisterShortcut() {
            if(registered) Native.UnregisterHotKey(Handle,1);
            string chosen=UserPreferences.String("Hotkey","Ctrl + Shift + Space");
            uint modifiers=0x4006;uint key=0x20;
            if(chosen=="Ctrl + Alt + V") { modifiers=0x4003;key=0x56; }
            else if(chosen=="Alt + Shift + V") { modifiers=0x4005;key=0x56; }
            registered=Native.RegisterHotKey(Handle,1,modifiers,key);
        }
        void OpenAdvanced() {
            keyboard.Suspended=true;
            try {
                if(AdvancedSettings.Open(this)) {
                    autoEnglish.Checked=UserPreferences.Bool("AutoEnglish",autoEnglish.Checked);
                    restoreWords.Checked=UserPreferences.Bool("RestoreInvalid",restoreWords.Checked);
                    smartEnglish.Checked=UserPreferences.Bool("SmartEnglish",smartEnglish.Checked);
                    RebuildChrome();
                    keyboard.UseVni=UserPreferences.String("InputMethod","Telex")=="VNI";
            keyboard.SnippetsEnabled=UserPreferences.Bool("SnippetsEnabled",false);
            keyboard.ProfilesEnabled=UserPreferences.Bool("ProfilesEnabled",false);
                    string language=UserPreferences.String("LanguagePriority","Balanced");
                    keyboard.SmartEnglish=smartEnglish.Checked && language!="Vietnamese";
                    keyboard.PreferEnglishExact=language=="English";
                    keyboard.ReloadProductivity();
                    RegisterShortcut();
                    gameGuard.RefreshPolicy();
                    context.RequestCheck();
                }
            } finally {SyncPerformance();UpdateMode();}
        }
        static Icon MakeIcon(string letter, Color badgeColor)
        {
            using(var bitmap=new Bitmap(32,32))
            using(var graphics=Graphics.FromImage(bitmap))
            using(var stateFont=new Font("Segoe UI",21,FontStyle.Bold,GraphicsUnit.Pixel))
            using(var brandFont=new Font("Segoe UI",7.5f,FontStyle.Bold,GraphicsUnit.Pixel))
            using(var badgeBrush=new SolidBrush(badgeColor))
            using(var format=new StringFormat {Alignment=StringAlignment.Center,LineAlignment=StringAlignment.Center})
            using(var path=RoundedPanel.Rounded(new Rectangle(1,1,30,30),7))
            using(var gradient=new LinearGradientBrush(new Rectangle(1,1,30,30),
                Color.FromArgb(11,34,63),badgeColor,35f))
            {
                graphics.SmoothingMode=SmoothingMode.AntiAlias;
                graphics.Clear(Color.Transparent);
                graphics.FillPath(gradient,path);
                using(var edge=new Pen(Color.FromArgb(150,255,255,255),1f)) graphics.DrawPath(edge,path);
                // One teal visual identity for both modes; only V/E changes.
                graphics.DrawString(letter,stateFont,Brushes.White,new RectangleF(2,2,28,28),format);
                IntPtr handle=bitmap.GetHicon();
                var icon=(Icon)Icon.FromHandle(handle).Clone();
                Native.DestroyIcon(handle);
                return icon;
            }
        }
        void EditDictionary(bool vietnamese)
        {
            // Never rewrite the text being edited with the global keyboard hook.
            // The modal operates entirely inside TelexMini (no Notepad).
            keyboard.Suspended=true;
            try {
                if(DictionaryEditor.Edit(this,vietnamese)) {
                    EnglishLexicon.Reload();
                    keyboard.SmartEnglish=keyboard.SmartEnglish;
                }
            } finally {
                SyncPerformance();
                UpdateMode();
            }
        }
        void SyncPerformance() {
            bool pause=gameActive || manualPause;
            keyboard.Suspended=pause;
            // Always classify password fields when V is selected.
            // Suspend metadata checks in manual E or when a game is foreground.
            // Keep focus metadata warm in manual English mode so switching
            // back to Vietnamese does not wait for a new UI Automation query.
            context.Enabled=!pause;
        }
        void OpenSharedUiOrFallback() {
            if(!SharedUiLauncher.OpenOrActivate()) RestoreWindow();
        }
        void RestoreWindow() {
            if(!Visible) Show();
            if(WindowState==FormWindowState.Minimized) WindowState=FormWindowState.Normal;
            ShowInTaskbar=true;
            Native.ShowWindow(Handle,9); // SW_RESTORE also reveals a hidden window.
            Activate();
            BringToFront();
        }
        void Toggle() {
            keyboard.Enabled=!keyboard.Enabled;
            UserPreferences.Set("VietnameseEnabled",keyboard.Enabled);
            SyncPerformance();UpdateMode();
        }
        void RefreshExternalSettings() {
            bool preferencesChanged=UserPreferences.ReloadIfChanged();
            bool dictionaryChanged=EnglishLexicon.ReloadIfChanged();
            if(!preferencesChanged && !dictionaryChanged)return;
            if(preferencesChanged) {
                bool enabled=UserPreferences.Bool("VietnameseEnabled",true);
                if(keyboard.Enabled!=enabled)keyboard.Enabled=enabled;
                AdvancedSettings.ApplyAutoStart(UserPreferences.Bool("AutoStart",false));
                autoEnglish.Checked=UserPreferences.Bool("AutoEnglish",autoEnglish.Checked);
                restoreWords.Checked=UserPreferences.Bool("RestoreInvalid",restoreWords.Checked);
                smartEnglish.Checked=UserPreferences.Bool("SmartEnglish",smartEnglish.Checked);
                keyboard.AutoEnglish=UserPreferences.Bool("AutoEnglish",autoEnglish.Checked);
                keyboard.RestoreInvalid=UserPreferences.Bool("RestoreInvalid",restoreWords.Checked);
                string language=UserPreferences.String("LanguagePriority","Balanced");
                keyboard.SmartEnglish=smartEnglish.Checked && language!="Vietnamese";
                keyboard.PreferEnglishExact=language=="English";
                keyboard.UseVni=UserPreferences.String("InputMethod","Telex")=="VNI";
                keyboard.SnippetsEnabled=UserPreferences.Bool("SnippetsEnabled",false);
                keyboard.ProfilesEnabled=UserPreferences.Bool("ProfilesEnabled",false);
                keyboard.ReloadProductivity();
                RegisterShortcut();
                if(chrome!=null)chrome.ReloadTheme();
                context.RequestCheck();
            }
            if(dictionaryChanged)context.RequestCheck();
        }
        void UpdateMode()
        {
            InputContextKind kind=keyboard.ContextKind;
            bool pause=gameActive || manualPause;
            bool v=!pause && ContextPolicy.UseVietnamese(keyboard.Enabled,keyboard.AutoEnglish,kind);
            bool automatic=!pause && keyboard.Enabled && !v &&
                (keyboard.AutoEnglish || kind==InputContextKind.Password ||
                 kind==InputContextKind.Checking || kind==InputContextKind.Unavailable);
            string signature=v+":"+automatic+":"+kind+":"+keyboard.Enabled+":"+keyboard.AutoEnglish+":"+pause+":"+keyboard.UseVni;
            if(signature==displayedMode) return; displayedMode=signature;
            if(chrome!=null) chrome.UpdateMode(v,automatic,pause,kind);
            toggle.Text=UiText.IsEnglish ?
                (pause ? "E · INPUT PAUSED" : v ? "V · VIETNAMESE" :
                 kind==InputContextKind.Password && keyboard.Enabled ? "E · PASSWORD" :
                 automatic ? "E · AUTOMATIC" : "E · ENGLISH") :
                (pause ? "E  ·  NHƯỜNG PHÍM" : v ? "V  ·  TIẾNG VIỆT" :
                 kind==InputContextKind.Password && keyboard.Enabled ? "E  ·  MẬT KHẨU" :
                 automatic ? "E  ·  TỰ ĐỘNG" : "E  ·  ENGLISH");
            toggle.BackColor=chrome!=null ? Color.FromArgb(226,255,246) :
                (v ? Color.FromArgb(18,122,86) : Color.FromArgb(79,91,110));
            toggle.ForeColor=chrome!=null ? Color.FromArgb(9,79,75) : Color.White;
            tray.Icon=v ? vietIcon : englishIcon;
            // Update both WM_GETICON slots explicitly: the small icon is used
            // by the taskbar/title bar while the large icon is used by Alt+Tab.
            Icon=AppIcons.Brand;
            if(IsHandleCreated) {
                Native.SendMessage(Handle,0x80,IntPtr.Zero,AppIcons.Brand.Handle);
                Native.SendMessage(Handle,0x80,new IntPtr(1),tray.Icon.Handle);
            }
            string reason=UiText.IsEnglish ?
                (kind==InputContextKind.Password ? "Password field" : kind==InputContextKind.Terminal ? "Terminal" :
                 kind==InputContextKind.Unavailable ? "Input field not detected" : "Detecting input field") :
                (kind==InputContextKind.Password ? "Ô mật khẩu" : kind==InputContextKind.Terminal ? "Terminal" :
                 kind==InputContextKind.Unavailable ? "Chưa nhận diện được ô nhập" : "Đang nhận diện ô nhập");
            tray.Text=UiText.IsEnglish ?
                (pause ? "TelexMini — Input paused" : v ? "TelexMini — Vietnamese" :
                 automatic ? "TelexMini — English: "+reason : "TelexMini — English (pass-through)") :
                (pause ? "Telex Mini — Đã gỡ hook, tạm dừng bộ gõ" : v ? "Telex Mini — Tiếng Việt" :
                 automatic ? "Telex Mini — English: "+reason : "Telex Mini — English (đã gỡ hook)");
            switchItem.Text=UiText.T(keyboard.Enabled ? "Dùng English cho mọi nơi" : "Dùng Tiếng Việt (trừ ô mật khẩu)");
            status.Text=UiText.IsEnglish ?
                (pause ? "Keyboard and mouse hooks paused\nInput detection paused\nTray menu: resume or pause" :
                 automatic ? reason+" · English mode\nVietnamese resumes in supported fields\nPress E for English everywhere" :
                 registered ? "Ctrl + Shift + Space to switch\nPassword fields always use English\nSmart Telex + English" :
                 "Shortcut is used by another app.\nPassword fields always use English\nUse the V/E button to switch") :
                (pause ? "Đã dừng hook bàn phím / chuột\nĐã dừng nhận diện ô nhập\nMenu khay: bật / tắt tạm dừng" :
                 automatic ? reason+" · tạm dùng Anh\nSẽ về V khi ô nhập phù hợp\nBấm E để dùng Anh mọi nơi" :
                 registered ? "Ctrl + Shift + Space để chuyển\nMật khẩu luôn dùng English\nTelex + English thông minh" :
                 "Phím tắt đang bị ứng dụng khác dùng.\nMật khẩu luôn dùng English\nBấm nút V/E để chuyển");
        }
        protected override void WndProc(ref Message m) { if(m.Msg==0x312 && m.WParam.ToInt32()==1) Toggle(); base.WndProc(ref m); }
        protected override void Dispose(bool disposing)
        {
            if(disposing && !cleaned) {
                cleaned=true;
                if(registered && IsHandleCreated) Native.UnregisterHotKey(Handle,1);
                registered=false;
                if(modeTimer!=null) modeTimer.Dispose();
                if(gameGuard!=null) gameGuard.Dispose();
                if(keyboard!=null) keyboard.Dispose();
                if(context!=null) context.Dispose();
                if(tray!=null) { tray.Visible=false; if(tray.ContextMenuStrip!=null) tray.ContextMenuStrip.Dispose(); tray.Dispose(); }
                if(vietIcon!=null) vietIcon.Dispose(); if(englishIcon!=null) englishIcon.Dispose();
            }
            base.Dispose(disposing);
        }
    }
    internal static class SharedUiLauncher
    {
        internal static bool OpenOrActivate() {
            string path=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"TelexMiniSettings.exe");
            if(!File.Exists(path))return false;
            try {
                foreach(var process in Process.GetProcessesByName("TelexMiniSettings")) {
                    using(process) {
                        if(process.MainWindowHandle!=IntPtr.Zero) {
                            Native.ShowWindow(process.MainWindowHandle,9);
                            Native.SetForegroundWindow(process.MainWindowHandle);
                            return true;
                        }
                    }
                }
                var info=new ProcessStartInfo(path) {
                    WorkingDirectory=AppDomain.CurrentDomain.BaseDirectory,
                    UseShellExecute=false
                };
                using(var process=Process.Start(info)) {
                    return process!=null;
                }
            } catch(Exception) {
                return false;
            }
        }
    }

    internal static class AppIcons
    {
        static readonly Icon brand=Load();
        static Icon Load() {
            try {return Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? SystemIcons.Application;}
            catch {return SystemIcons.Application;}
        }
        internal static Icon Brand {get {return brand;}}
    }
    internal static class Program
    {
        [STAThread] static void Main()
        {
            bool first;
            using(var mutex=new Mutex(true,"Local\\TelexMini.Portable.v1",out first))
            {
                if(!first) {
                    if(SharedUiLauncher.OpenOrActivate()) return;
                    using(var current=Process.GetCurrentProcess())
                    foreach(var process in Process.GetProcessesByName(current.ProcessName)) {
                        using(process) {
                            if(process.Id==current.Id) continue;
                            IntPtr window=Native.FindTopLevelWindowForProcess(process.Id);
                            if(window!=IntPtr.Zero) {
                                Native.ShowWindow(window,9);
                                Native.SetForegroundWindow(window);
                                return;
                            }
                        }
                    }
                    MessageBox.Show(UiText.T("Telex Mini đang chạy. Bấm biểu tượng V/E ở khay hệ thống."),
                        UiText.T("TelexMini — Smart Bilingual Typing"));
                    return;
                }
                Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
                try { using(var form=new MainForm()) Application.Run(form); }
                catch(Exception error) { MessageBox.Show(UiText.T("Không khởi động được Telex Mini:\n")+error.Message,UiText.T("TelexMini — Smart Bilingual Typing"),MessageBoxButtons.OK,MessageBoxIcon.Error); }
            }
        }
    }
}
