using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

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
        Native.WinEventProc focusEventProc;
        IntPtr foregroundEventHook,focusEventHook;
        FileSystemWatcher preferencesWatcher;
        ModernChrome chrome;
        bool gameActive, manualPause;
        string displayedMode="";
        Icon vietIcon, englishIcon;
        bool registered, cleaned;
        string activeHotkey;
        string lastExclusionPolicy;
        readonly bool sharedUiInstalled;
        internal MainForm()
        {
            sharedUiInstalled=File.Exists(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"TelexMiniSettings.exe"));
            // Never flash an obsolete native settings window in the Flutter bundle.
            Shown+=delegate {
                if(sharedUiInstalled) {
                    Hide();
                    ShowInTaskbar=false;
                    if(!SharedUiLauncher.OpenOrActivate() && tray!=null)
                        tray.ShowBalloonTip(2200,"TelexMini",
                            "Giao diện Flutter chưa khởi động; bộ gõ vẫn hoạt động trong khay.",
                            ToolTipIcon.Warning);
                }
            };
            Text="Telex Mini"; ClientSize=new Size(334,306); FormBorderStyle=FormBorderStyle.FixedSingle;
            MaximizeBox=false; ShowInTaskbar=!sharedUiInstalled;
            Opacity=sharedUiInstalled ? 0 : 1;
            StartPosition=FormStartPosition.CenterScreen; TopMost=!sharedUiInstalled;
            BackColor=Color.FromArgb(246,248,251); Font=new Font("Segoe UI",10);
            vietIcon=MakeIcon("V",Color.FromArgb(0,183,164)); englishIcon=MakeIcon("E",Color.FromArgb(0,183,164));
            Icon=AppIcons.Brand;
            toggle=new Button { Location=new Point(18,18), Size=new Size(298,56), FlatStyle=FlatStyle.Flat,
                Font=new Font("Segoe UI",15,FontStyle.Bold), ForeColor=Color.White, Cursor=Cursors.Hand, TabStop=false };
            toggle.FlatAppearance.BorderSize=0;
            status=new Label { Location=new Point(18,83), Size=new Size(298,68), TextAlign=ContentAlignment.MiddleCenter };
            hide=new Button { Text=UiText.T("Thu xuống khay"), Location=new Point(18,262), Size=new Size(175,28), TabStop=false };
            exit=new Button { Text=UiText.T("Thoát"), Location=new Point(203,262), Size=new Size(113,28), TabStop=false };
            // Flutter owns the settings surface. Do not allocate hidden
            // WinForms child HWNDs/GDI resources in tray-only mode.
            if(!sharedUiInstalled)Controls.AddRange(new Control[] { toggle,status,hide,exit });
            autoEnglish=new CheckBox { Text=UiText.T("Tự dùng English trong terminal"), Location=new Point(18,157), Size=new Size(298,25),
                Checked=UserPreferences.Bool("AutoEnglish",false), TabStop=false };
            restoreWords=new CheckBox { Text=UiText.T("Khôi phục từ không hợp lệ"), Location=new Point(18,186), Size=new Size(298,25),
                Checked=UserPreferences.Bool("RestoreInvalid",true), TabStop=false };
            smartEnglish=new CheckBox { Text=UiText.T("Bảo vệ từ tiếng Anh (offline)"), Location=new Point(18,215), Size=new Size(298,25),
                Checked=UserPreferences.Bool("SmartEnglish",true), TabStop=false };
            if(!sharedUiInstalled)Controls.AddRange(new Control[] { autoEnglish,restoreWords,smartEnglish });
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
            keyboard.ReloadProductivity();
            autoEnglish.CheckedChanged+=delegate { keyboard.AutoEnglish=autoEnglish.Checked; UserPreferences.Set("AutoEnglish",autoEnglish.Checked); keyboard.Enabled=keyboard.Enabled; SyncPerformance(); UpdateMode(); };
            restoreWords.CheckedChanged+=delegate { keyboard.RestoreInvalid=restoreWords.Checked; UserPreferences.Set("RestoreInvalid",restoreWords.Checked); };
            smartEnglish.CheckedChanged+=delegate {
                keyboard.SmartEnglish=smartEnglish.Checked &&
                    UserPreferences.String("LanguagePriority","Balanced")!="Vietnamese";
                UserPreferences.Set("SmartEnglish",smartEnglish.Checked); UpdateMode();
            };
            var menu=TrayMenuStyle.Create();
            TrayMenuStyle.AddHeader(menu);
            switchItem=TrayMenuStyle.Add(menu,"","V",delegate(object s,EventArgs e) { Toggle(); });
            pauseItem=TrayMenuStyle.Add(menu,UiText.T("Tạm dừng hoàn toàn: game / remote"),"Ⅱ",null);
            pauseItem.CheckOnClick=true;
            pauseItem.CheckedChanged+=delegate { manualPause=pauseItem.Checked; SyncPerformance(); UpdateMode(); };
            menu.Items.Add(new ToolStripSeparator());
            TrayMenuStyle.Add(menu,UiText.T("Từ điển tiếng Anh")+"...","A",delegate(object s,EventArgs e) { OpenFlutterPage("englishDictionary"); });
            TrayMenuStyle.Add(menu,UiText.T("Ưu tiên Telex")+"...","V",delegate(object s,EventArgs e) { OpenFlutterPage("vietnamesePriority"); });
            TrayMenuStyle.Add(menu,UiText.T("↻  Nạp lại từ điển"),"↻",delegate(object s,EventArgs e) { EnglishLexicon.Reload(); keyboard.SmartEnglish=keyboard.SmartEnglish; UpdateMode(); });
            TrayMenuStyle.Add(menu,UiText.T("⚙  Cài đặt nâng cao")+"...","⚙",delegate(object s,EventArgs e) { OpenFlutterPage("settings"); });
            TrayMenuStyle.Add(menu,UiText.T("Gõ tắt")+"...","+",delegate(object s,EventArgs e) { OpenFlutterPage("snippets"); });
            TrayMenuStyle.Add(menu,UiText.T("Ứng dụng & process")+"...","▦",delegate(object s,EventArgs e) { OpenFlutterPage("applications"); });
            TrayMenuStyle.Add(menu,UiText.T("⌘  Ký tự nhanh")+"...","Ω",delegate(object s,EventArgs e) { OpenFlutterPage("symbols"); });
            menu.Items.Add(new ToolStripSeparator());
            TrayMenuStyle.Add(menu,UiText.T("Khôi phục hook bàn phím"),"↻",delegate(object s,EventArgs e) { RepairInputHooks(true); });
            TrayMenuStyle.Add(menu,UiText.T("Kiểm tra bản cập nhật..."),"↻",delegate(object s,EventArgs e) {
                try {
                    System.Diagnostics.Process.Start("https://github.com/muahacodon321-boop/TelexMiniMac/releases");
                } catch(Exception ex) {
                    MessageBox.Show(this,ex.Message,"TelexMini",MessageBoxButtons.OK,MessageBoxIcon.Information);
                }
            });
            TrayMenuStyle.Add(menu,UiText.T("Chẩn đoán & sao lưu"),"✓",delegate(object s,EventArgs e) { OpenFlutterPage("diagnostics"); });
            TrayMenuStyle.Add(menu,UiText.T("Mở TelexMini"),"T",delegate(object s,EventArgs e) { OpenSharedUiOrFallback(); });
            menu.Items.Add(new ToolStripSeparator());
            TrayMenuStyle.Add(menu,UiText.T("Thoát"),"×",delegate(object s,EventArgs e) { Close(); });
            menu.Opening+=delegate { TrayMenuStyle.ApplyTheme(menu,UserPreferences.Bool("DarkTheme",false)); };
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
            lastExclusionPolicy=UserPreferences.String("ExcludedApps","");
            modeTimer=new System.Windows.Forms.Timer { Interval=800 };
            gameGuard=new GameGuard(delegate(bool active) { gameActive=active; SyncPerformance(); UpdateMode(); });
            modeTimer.Tick+=delegate { RefreshExternalSettings(); gameGuard.Check(); UpdateMode(); ServeDiagnosticsRequest(); }; modeTimer.Start();
            AttachRuntimeNotifications();
            if(!sharedUiInstalled)RebuildChrome();
            SyncPerformance();
            UpdateMode();
        }
        void AttachRuntimeNotifications() {
            try {
                focusEventProc=OnNativeFocusChanged;
                foregroundEventHook=Native.SetWinEventHook(0x0003,0x0003,IntPtr.Zero,focusEventProc,0,0,0);
                focusEventHook=Native.SetWinEventHook(0x8005,0x8005,IntPtr.Zero,focusEventProc,0,0,0);
            } catch(System.ComponentModel.Win32Exception) {}
            try {
                Directory.CreateDirectory(AppStorage.DirectoryPath);
                preferencesWatcher=new FileSystemWatcher(AppStorage.DirectoryPath,"preferences.ini") {
                    NotifyFilter=NotifyFilters.LastWrite|NotifyFilters.FileName|NotifyFilters.CreationTime,
                    SynchronizingObject=this
                };
                preferencesWatcher.Changed+=OnPreferencesFileChanged;
                preferencesWatcher.Created+=OnPreferencesFileChanged;
                preferencesWatcher.Renamed+=OnPreferencesFileChanged;
                preferencesWatcher.EnableRaisingEvents=true;
            } catch(IOException) {} catch(UnauthorizedAccessException) {}
            SystemEvents.SessionSwitch+=OnWindowsSessionSwitch;
            SystemEvents.PowerModeChanged+=OnWindowsPowerMode;
        }
        void OnPreferencesFileChanged(object sender,FileSystemEventArgs args) {
            if(cleaned)return;
            RefreshExternalSettings();
            UpdateMode();
        }
        void OnNativeFocusChanged(IntPtr hook,uint eventType,IntPtr window,
                                  int objectId,int childId,uint thread,uint time) {
            if(cleaned)return;
            if(eventType==0x0003 && gameGuard!=null) gameGuard.Check();
            if(context!=null) context.RequestCheck();
            UpdateMode();
        }
        void OnWindowsSessionSwitch(object sender,SessionSwitchEventArgs args) {
            if(args.Reason!=SessionSwitchReason.SessionUnlock &&
               args.Reason!=SessionSwitchReason.ConsoleConnect &&
               args.Reason!=SessionSwitchReason.RemoteConnect)return;
            RequestSafeHookRecovery();
        }
        void OnWindowsPowerMode(object sender,PowerModeChangedEventArgs args) {
            if(args.Mode==PowerModes.Resume)RequestSafeHookRecovery();
        }
        void RequestSafeHookRecovery() {
            if(cleaned || !IsHandleCreated)return;
            try {
                BeginInvoke((Action)delegate { if(!cleaned)RepairInputHooks(false); });
            } catch(InvalidOperationException) {}
        }
        void RepairInputHooks(bool notify) {
            bool ok=keyboard.TryRepairHooks();
            SyncPerformance();
            context.RequestCheck();
            UpdateMode();
            if(notify && tray!=null) {
                tray.ShowBalloonTip(1700,"TelexMini",ok ?
                    "Hook đã được khởi tạo lại (không thay đổi chế độ V/E)." :
                    "Windows chưa cho phép khởi tạo hook; phím gốc vẫn được chuyển tiếp.",
                    ok ? ToolTipIcon.Info : ToolTipIcon.Warning);
            }
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
            string chosen=UserPreferences.String("Hotkey","Ctrl + Shift + Space");
            if(registered && chosen==activeHotkey)return;
            if(registered) Native.UnregisterHotKey(Handle,1);
            activeHotkey=chosen;
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
            if(SharedUiLauncher.OpenOrActivate())return;
            if(sharedUiInstalled) {
                if(tray!=null)tray.ShowBalloonTip(2200,"TelexMini",
                    "Không mở được Flutter Settings. Bộ gõ trong tray vẫn chạy.",
                    ToolTipIcon.Warning);
            } else RestoreWindow();
        }
        void ServeDiagnosticsRequest() {
            // Respond on demand; only timing aggregates, never keys or text.
            try {
                string folder=AppStorage.DirectoryPath;
                string request=Path.Combine(folder,"diagnostics.request");
                if(!File.Exists(request)) return;
                File.Delete(request);
                File.WriteAllText(Path.Combine(folder,"diagnostics.metrics"),keyboard.HookDiagnostics(),new UTF8Encoding(false));
            } catch(IOException) {} catch(UnauthorizedAccessException) {}
        }
        void OpenFlutterPage(string page) {
            try {
                string folder=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),"TelexMini","FlutterUI");
                Directory.CreateDirectory(folder);
                File.WriteAllText(Path.Combine(folder,"navigation.txt"),page,new UTF8Encoding(false));
            } catch(IOException) {} catch(UnauthorizedAccessException) {}
            OpenSharedUiOrFallback();
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
                keyboard.SyncBackend();
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
                string exclusions=UserPreferences.String("ExcludedApps","");
                if(lastExclusionPolicy!=exclusions) {
                    lastExclusionPolicy=exclusions;
                    gameGuard.RefreshPolicy();
                    context.RequestCheck();
                }
            }
            if(dictionaryChanged) {
                // Snippet/profile changes signal the same reload flag; do not
                // invalidate password focus metadata for a dictionary edit.
                keyboard.ReloadProductivity();
                keyboard.ReloadNativeDictionary();
            }
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
                SystemEvents.SessionSwitch-=OnWindowsSessionSwitch;
                SystemEvents.PowerModeChanged-=OnWindowsPowerMode;
                if(preferencesWatcher!=null)preferencesWatcher.Dispose();
                if(foregroundEventHook!=IntPtr.Zero)Native.UnhookWinEvent(foregroundEventHook);
                if(focusEventHook!=IntPtr.Zero)Native.UnhookWinEvent(focusEventHook);
                if(modeTimer!=null) modeTimer.Dispose();
                if(gameGuard!=null) gameGuard.Dispose();
                if(keyboard!=null) keyboard.Dispose();
                if(context!=null) context.Dispose();
                if(tray!=null) { tray.Visible=false; if(tray.ContextMenuStrip!=null) tray.ContextMenuStrip.Dispose(); tray.Dispose(); }
                if(sharedUiInstalled) {
                    // Unparented config controls have no WinForms owner to
                    // dispose them when the tray engine finally exits.
                    foreach(Control item in new Control[] {toggle,status,hide,exit,autoEnglish,restoreWords,smartEnglish})
                        if(item!=null)item.Dispose();
                }
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
