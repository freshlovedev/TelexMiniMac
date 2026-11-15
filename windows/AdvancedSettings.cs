using System;
using System.IO;
using System.Linq;
using System.Drawing;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

namespace TelexMini
{
    // The settings dialog never reads keystrokes. Paths and process names only.
    internal sealed class AdvancedSettings : Form
    {
        const string RunKey=@"Software\Microsoft\Windows\CurrentVersion\Run";
        readonly ComboBox method,shortcut,priority,uiLanguageCombo;
        readonly TextBox excluded;
        readonly CheckBox start,portable;
        readonly Label hint;
        internal static bool Open(IWin32Window owner) {
            using(var form=new AdvancedSettings()) return form.ShowDialog(owner)==DialogResult.OK;
        }
        internal static void ApplyAutoStart(bool enabled) { AutoStart=enabled; }
        static bool AutoStart {
            get {
                try {using(var k=Registry.CurrentUser.OpenSubKey(RunKey)) {
                    return k!=null && k.GetValue("TelexMini")!=null;
                }} catch(Exception) {return false;}
            }
            set {
                using(var k=Registry.CurrentUser.CreateSubKey(RunKey)) {
                    if(value) k.SetValue("TelexMini", "\""+Application.ExecutablePath+"\"");
                    else k.DeleteValue("TelexMini",false);
                }
            }
        }
        AdvancedSettings() {
            Text=UiText.T("TelexMini — Smart Bilingual Typing")+" · "+UiText.T("⚙  Cài đặt nâng cao");
            Icon=AppIcons.Brand;
            StartPosition=FormStartPosition.CenterParent;
            ClientSize=new Size(610,555);MinimumSize=new Size(560,520);
            BackColor=Color.FromArgb(17,28,44);ForeColor=Color.White;
            Font=new Font("Segoe UI",10);AutoScaleMode=AutoScaleMode.Dpi;
            var panel=new TableLayoutPanel {
                Dock=DockStyle.Fill,Padding=new Padding(20),ColumnCount=1,RowCount=10,AutoScroll=true
            };
            panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            for(int i=0;i<10;i++) panel.RowStyles.Add(new RowStyle(SizeType.Absolute,i==7?70:i==9?62:41));
            Controls.Add(panel);
            panel.Controls.Add(new Label {Text=UiText.T("Cài đặt gõ song ngữ"),Font=new Font("Segoe UI",17,FontStyle.Bold),
                Dock=DockStyle.Fill,ForeColor=Color.FromArgb(81,229,183)},0,0);
            panel.Controls.Add(new Label {Text=UiText.T("Kiểu gõ: Telex / VNI"),Dock=DockStyle.Fill},0,1);
            method=new ComboBox {Dock=DockStyle.Fill,DropDownStyle=ComboBoxStyle.DropDownList};
            method.Items.AddRange(new object[]{"Telex","VNI"});
            method.SelectedIndex=UserPreferences.String("InputMethod","Telex")=="VNI"?1:0;
            var inputChoices=new FlowLayoutPanel {Dock=DockStyle.Fill,WrapContents=false,
                FlowDirection=FlowDirection.LeftToRight};
            method.Width=145;method.Dock=DockStyle.None;
            priority=new ComboBox {Width=205,DropDownStyle=ComboBoxStyle.DropDownList};
            priority.Items.AddRange(new object[]{UiText.T("Cân bằng"),UiText.T("Ưu tiên tiếng Việt"),UiText.T("Ưu tiên tiếng Anh")});
            string language=UserPreferences.String("LanguagePriority","Balanced");
            priority.SelectedIndex=language=="Vietnamese"?1:language=="English"?2:0;
            inputChoices.Controls.Add(method);
            inputChoices.Controls.Add(new Label {Text=UiText.T("Ưu tiên"),AutoSize=true,
                ForeColor=Color.White,Margin=new Padding(12,6,6,0)});
            inputChoices.Controls.Add(priority);
            panel.Controls.Add(inputChoices,0,2);
            panel.Controls.Add(new Label {Text=UiText.T("Phím tắt chuyển V/E"),Dock=DockStyle.Fill},0,3);
            shortcut=new ComboBox {Dock=DockStyle.Fill,DropDownStyle=ComboBoxStyle.DropDownList};
            shortcut.Items.AddRange(new object[]{"Ctrl + Shift + Space","Ctrl + Alt + V","Alt + Shift + V"});
            shortcut.SelectedIndex=Math.Max(0,shortcut.Items.IndexOf(UserPreferences.String("Hotkey","Ctrl + Shift + Space")));
            uiLanguageCombo=new ComboBox {DropDownStyle=ComboBoxStyle.DropDownList,Width=140};
            uiLanguageCombo.Items.AddRange(new object[]{UiText.T("Tiếng Việt"),"English"});
            uiLanguageCombo.SelectedIndex=UserPreferences.String("UILanguage","vi")=="en"?1:0;
            var shortcutLine=new FlowLayoutPanel {Dock=DockStyle.Fill,WrapContents=false};
            shortcut.Dock=DockStyle.None;shortcut.Width=185;
            shortcutLine.Controls.Add(shortcut);
            shortcutLine.Controls.Add(new Label {Text=UiText.T("Giao diện"),AutoSize=true,
                ForeColor=Color.White,Margin=new Padding(12,6,4,0)});
            shortcutLine.Controls.Add(uiLanguageCombo);
            panel.Controls.Add(shortcutLine,0,4);
            start=new CheckBox {Text=UiText.T("Tự khởi động cùng Windows"),Checked=AutoStart,
                Dock=DockStyle.Fill,ForeColor=Color.White};
            panel.Controls.Add(start,0,5);
            portable=new CheckBox {Text=UiText.T("Portable Mode (dữ liệu cạnh EXE, cần khởi động lại)"),
                Checked=AppStorage.IsPortable,Dock=DockStyle.Fill,ForeColor=Color.White};
            panel.Controls.Add(portable,0,6);
            var excludedPanel=new FlowLayoutPanel {Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false};
            excludedPanel.Controls.Add(new Label {Text=UiText.T("Ứng dụng bỏ qua (tên tiến trình, cách nhau bằng dấu phẩy)"),
                AutoSize=true,ForeColor=Color.White});
            excluded=new TextBox {Width=520,Text=UserPreferences.String("ExcludedApps","")};
            excludedPanel.Controls.Add(excluded);
            panel.Controls.Add(excludedPanel,0,7);
            hint=new Label {Dock=DockStyle.Fill,ForeColor=Color.FromArgb(159,189,205),
                Text=UiText.T("Cấu hình và từ điển lưu trên máy, không ghi lịch sử gõ.")};
            panel.Controls.Add(hint,0,8);
            var actions=new FlowLayoutPanel {Dock=DockStyle.Fill,FlowDirection=FlowDirection.RightToLeft};
            var save=new Button {Text=UiText.T("Lưu và áp dụng"),Width=135,Height=34};
            var cancel=new Button {Text=UiText.T("Hủy"),Width=70,Height=34};
            var export=new Button {Text=UiText.T("Xuất"),Width=75,Height=34};
            var import=new Button {Text=UiText.T("Nhập"),Width=75,Height=34};
            actions.Controls.Add(save);actions.Controls.Add(cancel);
            actions.Controls.Add(export);actions.Controls.Add(import);
            panel.Controls.Add(actions,0,9);
            cancel.Click+=delegate {Close();};
            save.Click+=delegate {
                try {
                    AutoStart=start.Checked;
                    if(portable.Checked!=AppStorage.IsPortable) {
                        if(portable.Checked) AppStorage.EnablePortable();
                        else AppStorage.DisablePortable();
                        MessageBox.Show(this,UiText.T("Đã chuyển nơi lưu cấu hình. Hãy thoát và mở lại TelexMini."),
                            "TelexMini",MessageBoxButtons.OK,MessageBoxIcon.Information);
                    }
                    UserPreferences.Set("InputMethod",method.SelectedItem.ToString());
                    UserPreferences.Set("LanguagePriority",
                        priority.SelectedIndex==1?"Vietnamese":
                        priority.SelectedIndex==2?"English":"Balanced");
                    UserPreferences.Set("Hotkey",shortcut.SelectedItem.ToString());
                    UserPreferences.Set("UILanguage",uiLanguageCombo.SelectedIndex==1?"en":"vi");
                    string names=string.Join(",",excluded.Text.Split(',')
                        .Select(s=>s.Trim()).Where(s=>s.Length>0 &&
                         s.All(c=>char.IsLetterOrDigit(c)||c=='.'||c=='_'||c=='-')).Distinct().ToArray());
                    UserPreferences.Set("ExcludedApps",names);
                    DialogResult=DialogResult.OK;Close();
                } catch(Exception ex) {MessageBox.Show(this,UiText.T(ex.Message),UiText.T("TelexMini — Smart Bilingual Typing"),MessageBoxButtons.OK,MessageBoxIcon.Error);}
            };
            export.Click+=delegate {Backup(false);};
            import.Click+=delegate {Backup(true);};
            UiPalette.Apply(this);
        }
        void Backup(bool restore) {
            using(var chooser=new FolderBrowserDialog()) {
                chooser.Description=restore?UiText.T("Nhập"):UiText.T("Xuất");
                if(chooser.ShowDialog(this)!=DialogResult.OK) return;
                try {
                    string dir=AppStorage.DirectoryPath;
                    Directory.CreateDirectory(dir);
                    if(Path.GetFullPath(dir).TrimEnd('\\').Equals(
                        Path.GetFullPath(chooser.SelectedPath).TrimEnd('\\'),
                        StringComparison.OrdinalIgnoreCase)) {
                        MessageBox.Show(this,UiText.T("Hãy chọn thư mục khác với thư mục cấu hình gốc."),
                            "TelexMini",MessageBoxButtons.OK,MessageBoxIcon.Warning);
                        return;
                    }
                    foreach(var name in new[]{"preferences.ini","EnglishWords.txt","VietnameseOverrides.txt","snippets.tsv","profiles.tsv"}) {
                        string from=Path.Combine(restore?chooser.SelectedPath:dir,name);
                        string to=Path.Combine(restore?dir:chooser.SelectedPath,name);
                        if(!File.Exists(from)) continue;
                        if(restore && name=="snippets.tsv")
                            Productivity.ReadSnippetsFromText(File.ReadAllText(from,Encoding.UTF8));
                        if(restore && name=="profiles.tsv")
                            Productivity.ValidateProfiles(File.ReadAllText(from,Encoding.UTF8));
                        string temp=to+".import";
                        File.Copy(from,temp,true);
                        try {
                            if(File.Exists(to)) File.Replace(temp,to,null);
                            else File.Move(temp,to);
                        } finally {
                            if(File.Exists(temp)) File.Delete(temp);
                        }
                    }
                    if(restore) {
                        ConfigSync.ReadFrom(chooser.SelectedPath);
                        UserPreferences.Reload();EnglishLexicon.Reload();
                        MessageBox.Show(this,UiText.T("Đã nhập cấu hình và từ điển."),
                            "TelexMini",MessageBoxButtons.OK,MessageBoxIcon.Information);
                        DialogResult=DialogResult.OK;Close();
                    } else {
                        ConfigSync.WriteTo(chooser.SelectedPath);
                        MessageBox.Show(this,UiText.T("Đã xuất cấu hình."),
                            "TelexMini",MessageBoxButtons.OK,MessageBoxIcon.Information);
                    }
                } catch(Exception ex) {
                    MessageBox.Show(this,UiText.T(ex.Message),UiText.T("TelexMini — Smart Bilingual Typing"),MessageBoxButtons.OK,MessageBoxIcon.Error);
                }
            }
        }
    }
}
