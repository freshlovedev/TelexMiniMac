using System;
using System.IO;
using System.Drawing;
using System.Text;
using System.Windows.Forms;

namespace TelexMini
{
    // Explicit, opt-in productivity configuration. No keystroke logging.
    internal sealed class ProductivitySettings:Form
    {
        readonly CheckBox snippetsOn,profilesOn;
        readonly TextBox snippets,profiles;
        internal static bool Open(IWin32Window owner) {
            using(var form=new ProductivitySettings()) return form.ShowDialog(owner)==DialogResult.OK;
        }
        static string Read(string file) {
            try {return File.Exists(file)?File.ReadAllText(file,Encoding.UTF8):"";}
            catch(IOException){return "";}
        }
        ProductivitySettings() {
            Text="TelexMini — Gõ tắt & ứng dụng";
            Font=new Font("Segoe UI",10);
            StartPosition=FormStartPosition.CenterParent;
            ClientSize=new Size(720,720);MinimumSize=new Size(600,600);
            BackColor=Color.FromArgb(17,28,44);ForeColor=Color.White;
            var layout=new TableLayoutPanel {Dock=DockStyle.Fill,Padding=new Padding(16),
                ColumnCount=1,RowCount=11};
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            for(int i=0;i<11;i++) layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            layout.RowStyles[3]=new RowStyle(SizeType.Percent,50);
            layout.RowStyles[6]=new RowStyle(SizeType.Percent,50);
            Controls.Add(layout);
            layout.Controls.Add(new Label {Text="NĂNG SUẤT — OFFLINE",Font=new Font("Segoe UI",16,FontStyle.Bold),
                AutoSize=true,ForeColor=Color.FromArgb(81,229,183)},0,0);
            snippetsOn=new CheckBox {Text="Bật gõ tắt sau dấu cách / Enter / Tab",
                AutoSize=true,Checked=UserPreferences.Bool("SnippetsEnabled",false),ForeColor=Color.White};
            layout.Controls.Add(snippetsOn,0,1);
            layout.Controls.Add(new Label {Text="Mỗi dòng: phím tắt a-z [Tab] văn bản. Ví dụ: dc<TAB>được. Mặc định tắt.",
                AutoSize=true,ForeColor=Color.LightGray},0,2);
            snippets=new TextBox {Multiline=true,ScrollBars=ScrollBars.Both,Dock=DockStyle.Fill,
                Font=new Font("Consolas",11),AcceptsTab=true,WordWrap=false};
            snippets.Text=Read(Productivity.SnippetsPath);
            layout.Controls.Add(snippets,0,3);
            profilesOn=new CheckBox {Text="Bật cấu hình theo ứng dụng",
                AutoSize=true,Checked=UserPreferences.Bool("ProfilesEnabled",false),ForeColor=Color.White};
            layout.Controls.Add(profilesOn,0,4);
            layout.Controls.Add(new Label {Text="Mỗi dòng: process.exe [Tab] English / Vietnamese / Balanced",
                AutoSize=true,ForeColor=Color.LightGray},0,5);
            profiles=new TextBox {Multiline=true,ScrollBars=ScrollBars.Both,Dock=DockStyle.Fill,
                Font=new Font("Consolas",11),AcceptsTab=true,WordWrap=false};
            profiles.Text=Read(Productivity.ProfilesPath);
            layout.Controls.Add(profiles,0,6);
            layout.Controls.Add(new Label {Text="Chỉ lưu phím tắt và tên ứng dụng. Không ghi nội dung đã gõ.",
                ForeColor=Color.LightGray,AutoSize=true},0,7);
            var actions=new FlowLayoutPanel {FlowDirection=FlowDirection.RightToLeft,Dock=DockStyle.Fill};
            var save=new Button {Text="Lưu và áp dụng",Width=145,Height=36};
            var cancel=new Button {Text="Hủy",Width=90,Height=36};
            actions.Controls.Add(save);actions.Controls.Add(cancel);
            var spellingLine=new FlowLayoutPanel {Dock=DockStyle.Fill,Height=35,WrapContents=false};
            spellingLine.Controls.Add(new Label {Text="Gợi ý sửa:",AutoSize=true,
                ForeColor=Color.White,Margin=new Padding(0,7,10,0)});
            var spellingInput=new TextBox {Width=190};
            var spellingButton=new Button {Text="Gợi ý (không tự sửa)",Width=175,Height=31};
            spellingLine.Controls.Add(spellingInput);spellingLine.Controls.Add(spellingButton);
            layout.Controls.Add(spellingLine,0,8);
            var spellingResult=new Label {Text="Chỉ tra cứu khi bấm nút · Offline",
                Dock=DockStyle.Fill,ForeColor=Color.LightGray,AutoSize=true};
            layout.Controls.Add(spellingResult,0,9);
            spellingButton.Click+=delegate {
                var result=SpellAdvisor.Suggest(spellingInput.Text);
                spellingResult.Text=result.Length==0?"Không có gợi ý trong từ điển nhỏ.":
                    "Gợi ý: "+string.Join(" · ",result);
            };
            layout.Controls.Add(actions,0,10);
            cancel.Click+=delegate{Close();};
            save.Click+=delegate {
                try {
                    var parsed=Productivity.ReadSnippetsFromText(snippets.Text);
                    // Invalid rows fail closed rather than silently mutating user data.
                    string profilesText=Productivity.ValidateProfiles(profiles.Text);
                    Productivity.SaveSnippets(parsed);
                    Productivity.SaveProfiles(profilesText);
                    UserPreferences.Set("SnippetsEnabled",snippetsOn.Checked);
                    UserPreferences.Set("ProfilesEnabled",profilesOn.Checked);
                    DialogResult=DialogResult.OK;Close();
                } catch(Exception ex) {
                    MessageBox.Show(this,ex.Message,"TelexMini",MessageBoxButtons.OK,MessageBoxIcon.Warning);
                }
            };
        }
    }
    internal sealed class SymbolPicker:Form
    {
        internal SymbolPicker() {
            Text="TelexMini — Ký tự nhanh";
            StartPosition=FormStartPosition.CenterScreen;
            ClientSize=new Size(430,300);TopMost=true;
            Font=new Font("Segoe UI",12);
            var wrap=new FlowLayoutPanel {Dock=DockStyle.Fill,AutoScroll=true,Padding=new Padding(10)};
            Controls.Add(wrap);
            foreach(string symbol in Productivity.Symbols) {
                string value=symbol;
                var button=new Button {Text=value,Width=55,Height=45,Margin=new Padding(3)};
                button.Click+=delegate {
                    Clipboard.SetText(value);
                    Close();
                };
                wrap.Controls.Add(button);
            }
            var tip=new Label {Text="Nhấp ký tự để sao chép, sau đó Ctrl+V để chèn.",
                Width=400,Height=28};wrap.Controls.Add(tip);
        }
    }
}
