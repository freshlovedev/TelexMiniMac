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
        RoundedPanel Card() {
            return new RoundedPanel {Dock=DockStyle.Fill,CornerRadius=15,
                StartColor=UiPalette.Card,EndColor=UiPalette.Card,Outline=UiPalette.Border,
                Margin=new Padding(0,0,0,12)};
        }
        Label LabelText(string text,float size,bool bold,Color color) {
            return new Label {Text=text,AutoSize=true,Font=new Font("Segoe UI",size,bold?FontStyle.Bold:FontStyle.Regular),
                ForeColor=color,BackColor=Color.Transparent,Margin=new Padding(0,0,0,5)};
        }
        ProductivitySettings() {
            Text=UiText.T("TelexMini — Gõ tắt & ứng dụng");
            Icon=AppIcons.Brand;StartPosition=FormStartPosition.CenterParent;
            ClientSize=new Size(760,760);MinimumSize=new Size(650,650);
            Font=new Font("Segoe UI",9.5f);AutoScaleMode=AutoScaleMode.Dpi;
            var root=new TableLayoutPanel {Dock=DockStyle.Fill,Padding=new Padding(22,18,22,16),
                ColumnCount=1,RowCount=5};
            root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute,66));
            root.RowStyles.Add(new RowStyle(SizeType.Percent,48));
            root.RowStyles.Add(new RowStyle(SizeType.Percent,42));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute,88));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute,48));
            Controls.Add(root);

            var heading=new Panel {Dock=DockStyle.Fill};
            heading.Controls.Add(new Label {Text=UiText.T("Gõ tắt & Ứng dụng"),
                Font=new Font("Segoe UI",19,FontStyle.Bold),ForeColor=UiPalette.Ink,
                Location=new Point(0,0),AutoSize=true});
            heading.Controls.Add(new Label {Text=UiText.T("Quản lý cụm từ thay thế và quy tắc nhập riêng cho từng ứng dụng."),
                ForeColor=UiPalette.Muted,Location=new Point(1,38),AutoSize=true});
            root.Controls.Add(heading,0,0);

            var snippetsCard=Card();root.Controls.Add(snippetsCard,0,1);
            var sLayout=new TableLayoutPanel {Dock=DockStyle.Fill,Padding=new Padding(17,13,17,12),
                ColumnCount=1,RowCount=3};
            sLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,30));
            sLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,27));
            sLayout.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            snippetsCard.Controls.Add(sLayout);
            var sHead=new FlowLayoutPanel {Dock=DockStyle.Fill,WrapContents=false};
            sHead.Controls.Add(LabelText(UiText.T("Gõ tắt"),11,true,UiPalette.Ink));
            snippetsOn=new CheckBox {Text=UiText.T("Bật mở rộng sau dấu cách / Enter / Tab"),
                Checked=UserPreferences.Bool("SnippetsEnabled",false),AutoSize=true,Margin=new Padding(16,2,0,0)};
            sHead.Controls.Add(snippetsOn);sLayout.Controls.Add(sHead,0,0);
            sLayout.Controls.Add(LabelText(UiText.T("Mỗi dòng: phím tắt a-z [Tab] văn bản. Ví dụ: dc → được."),
                8.7f,false,UiPalette.Muted),0,1);
            snippets=new TextBox {Multiline=true,ScrollBars=ScrollBars.Both,Dock=DockStyle.Fill,
                Font=new Font("Consolas",10.5f),AcceptsTab=true,WordWrap=false};
            snippets.Text=Read(Productivity.SnippetsPath);sLayout.Controls.Add(snippets,0,2);

            var profilesCard=Card();root.Controls.Add(profilesCard,0,2);
            var pLayout=new TableLayoutPanel {Dock=DockStyle.Fill,Padding=new Padding(17,13,17,12),
                ColumnCount=1,RowCount=3};
            pLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,30));
            pLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,27));
            pLayout.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            profilesCard.Controls.Add(pLayout);
            var pHead=new FlowLayoutPanel {Dock=DockStyle.Fill,WrapContents=false};
            pHead.Controls.Add(LabelText(UiText.T("Quy tắc theo ứng dụng"),11,true,UiPalette.Ink));
            profilesOn=new CheckBox {Text=UiText.T("Kích hoạt hồ sơ ứng dụng"),
                Checked=UserPreferences.Bool("ProfilesEnabled",false),AutoSize=true,Margin=new Padding(16,2,0,0)};
            pHead.Controls.Add(profilesOn);pLayout.Controls.Add(pHead,0,0);
            pLayout.Controls.Add(LabelText(UiText.T("Mỗi dòng: process.exe [Tab] English / Vietnamese / Balanced"),
                8.7f,false,UiPalette.Muted),0,1);
            profiles=new TextBox {Multiline=true,ScrollBars=ScrollBars.Both,Dock=DockStyle.Fill,
                Font=new Font("Consolas",10.5f),AcceptsTab=true,WordWrap=false};
            profiles.Text=Read(Productivity.ProfilesPath);pLayout.Controls.Add(profiles,0,2);

            var spellingCard=Card();root.Controls.Add(spellingCard,0,3);
            var spell=new TableLayoutPanel {Dock=DockStyle.Fill,Padding=new Padding(15,10,15,8),
                ColumnCount=1,RowCount=2};
            spell.RowStyles.Add(new RowStyle(SizeType.Absolute,30));
            spell.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            spellingCard.Controls.Add(spell);
            spell.Controls.Add(LabelText(UiText.T("Gợi ý chính tả · Tra cứu thủ công, offline"),9.5f,true,UiPalette.Ink),0,0);
            var spellLine=new FlowLayoutPanel {Dock=DockStyle.Fill,WrapContents=false};
            var spellingInput=new TextBox {Width=190,Height=30};
            var spellingButton=new Button {Text=UiText.T("Gợi ý"),Width=88,Height=30};
            var spellingResult=new Label {Text=UiText.T("Không tự động sửa nội dung."),
                AutoSize=true,ForeColor=UiPalette.Muted,Margin=new Padding(12,7,0,0)};
            spellLine.Controls.Add(spellingInput);spellLine.Controls.Add(spellingButton);spellLine.Controls.Add(spellingResult);
            spell.Controls.Add(spellLine,0,1);
            spellingButton.Click+=delegate {
                var result=SpellAdvisor.Suggest(spellingInput.Text);
                spellingResult.Text=result.Length==0?UiText.T("Không có gợi ý trong từ điển nhỏ."):
                    UiText.T("Gợi ý: ")+string.Join(" · ",result);
            };

            var footer=new Panel {Dock=DockStyle.Fill};
            footer.Controls.Add(new Label {Text=UiText.T("Chỉ lưu phím tắt và tên ứng dụng. Không ghi nội dung đã gõ."),
                ForeColor=UiPalette.Muted,Location=new Point(0,7),AutoSize=true});
            var cancel=new Button {Text=UiText.T("Hủy"),Width=90,Height=34,Anchor=AnchorStyles.Top|AnchorStyles.Right};
            var save=new Button {Text=UiText.T("Lưu và áp dụng"),Width=150,Height=34,Anchor=AnchorStyles.Top|AnchorStyles.Right};
            footer.Controls.Add(cancel);footer.Controls.Add(save);
            footer.Resize+=delegate {save.Location=new Point(footer.ClientSize.Width-save.Width,0);
                cancel.Location=new Point(save.Left-cancel.Width-9,0);};
            root.Controls.Add(footer,0,4);
            cancel.Click+=delegate{Close();};
            save.Click+=delegate {
                try {
                    var parsed=Productivity.ReadSnippetsFromText(snippets.Text);
                    string profilesText=Productivity.ValidateProfiles(profiles.Text);
                    Productivity.SaveSnippets(parsed);Productivity.SaveProfiles(profilesText);
                    UserPreferences.Set("SnippetsEnabled",snippetsOn.Checked);
                    UserPreferences.Set("ProfilesEnabled",profilesOn.Checked);
                    DialogResult=DialogResult.OK;Close();
                } catch(Exception ex) {
                    MessageBox.Show(this,UiText.T(ex.Message),UiText.T("TelexMini — Gõ tắt & ứng dụng"),
                        MessageBoxButtons.OK,MessageBoxIcon.Warning);
                }
            };
            UiPalette.Apply(this);
            foreach(Control c in new Control[]{snippetsCard,profilesCard,spellingCard}) {
                c.BackColor=UiPalette.Card;
                foreach(Control child in c.Controls) child.BackColor=Color.Transparent;
            }
            snippets.BackColor=UiPalette.Field;profiles.BackColor=UiPalette.Field;
            save.BackColor=UiPalette.Accent;save.ForeColor=Color.White;save.FlatAppearance.BorderSize=0;
        }
    }

    internal sealed class SymbolPicker:Form
    {
        internal SymbolPicker() {
            Text=UiText.T("TelexMini — Ký tự nhanh");Icon=AppIcons.Brand;
            StartPosition=FormStartPosition.CenterParent;ClientSize=new Size(460,320);
            Font=new Font("Segoe UI",11);AutoScaleMode=AutoScaleMode.Dpi;
            var root=new TableLayoutPanel {Dock=DockStyle.Fill,Padding=new Padding(16),RowCount=2,ColumnCount=1};
            root.RowStyles.Add(new RowStyle(SizeType.Percent,100));root.RowStyles.Add(new RowStyle(SizeType.Absolute,34));
            Controls.Add(root);
            var wrap=new FlowLayoutPanel {Dock=DockStyle.Fill,AutoScroll=true,Padding=new Padding(5)};
            root.Controls.Add(wrap,0,0);
            foreach(string symbol in Productivity.Symbols) {
                string value=symbol;
                var button=new Button {Text=value,Width=58,Height=48,Margin=new Padding(4),Font=new Font("Segoe UI",16)};
                button.Click+=delegate {Clipboard.SetText(value);Close();};wrap.Controls.Add(button);
            }
            root.Controls.Add(new Label {Text=UiText.T("Nhấp ký tự để sao chép, sau đó Ctrl+V để chèn."),
                Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleLeft},0,1);
            UiPalette.Apply(this);
        }
    }
}