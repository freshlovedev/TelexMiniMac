using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace TelexMini
{
    // First-party local dictionary editor. It stores explicit dictionary entries only.
    internal sealed class DictionaryEditor : Form
    {
        readonly string path;
        readonly bool vietnamese;
        readonly ListBox wordList;
        readonly TextBox searchBox,wordBox;
        readonly Label count,message;
        readonly HashSet<string> words=new HashSet<string>(StringComparer.Ordinal);
        bool changed;

        internal static Form CreateForTests(bool vietnamese,string testPath) {
            return new DictionaryEditor(vietnamese,testPath);
        }
        internal static bool Edit(IWin32Window owner,bool vietnamese) {
            using(var dialog=new DictionaryEditor(vietnamese))return dialog.ShowDialog(owner)==DialogResult.OK;
        }
        DictionaryEditor(bool isVietnamese):this(isVietnamese,null){}
        DictionaryEditor(bool isVietnamese,string testPath) {
            vietnamese=isVietnamese;
            path=testPath??(vietnamese?EnglishLexicon.VietnamesePath:EnglishLexicon.EnglishPath);
            Text=UiText.T(vietnamese?"TelexMini · Ưu tiên tiếng Việt":"TelexMini · Từ điển tiếng Anh");
            Icon=AppIcons.Brand;StartPosition=FormStartPosition.CenterParent;
            ClientSize=new Size(720,690);MinimumSize=new Size(620,560);
            FormBorderStyle=FormBorderStyle.Sizable;MaximizeBox=true;ShowInTaskbar=false;
            AutoScaleMode=AutoScaleMode.Dpi;Font=new Font("Segoe UI",9.5f);
            BackColor=UiPalette.Page;ForeColor=UiPalette.Ink;KeyPreview=true;

            var root=new TableLayoutPanel {Dock=DockStyle.Fill,Padding=new Padding(24,20,24,18),
                ColumnCount=1,RowCount=5,BackColor=UiPalette.Page};
            root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute,76));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute,48));
            root.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute,62));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute,58));
            Controls.Add(root);

            var header=new Panel {Dock=DockStyle.Fill,BackColor=Color.Transparent};
            var title=new Label {Text=UiText.T(vietnamese?"Ưu tiên Telex":"Từ điển tiếng Anh"),
                Font=new Font("Segoe UI",20,FontStyle.Bold),ForeColor=UiPalette.Ink,
                Location=new Point(0,0),AutoSize=true};
            var subtitle=new Label {Text=UiText.T(vietnamese?
                "Các chuỗi phím cần được xử lý ưu tiên như tiếng Việt.":
                "Bảo vệ tên riêng, thuật ngữ và từ chuyên ngành khỏi bị chuyển đổi."),
                Font=new Font("Segoe UI",9.2f),ForeColor=UiPalette.Muted,
                Location=new Point(1,42),AutoSize=true};
            header.Controls.Add(title);header.Controls.Add(subtitle);root.Controls.Add(header,0,0);

            var findRow=new TableLayoutPanel {Dock=DockStyle.Fill,ColumnCount=2,RowCount=1,
                Margin=Padding.Empty,BackColor=Color.Transparent};
            findRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            findRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,150));
            searchBox=new TextBox {Dock=DockStyle.Fill,Margin=new Padding(0,5,14,5),
                Font=new Font("Segoe UI",10)};
            count=new Label {Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleRight,
                Font=new Font("Segoe UI",8.8f),ForeColor=UiPalette.Muted,Margin=Padding.Empty};
            findRow.Controls.Add(searchBox,0,0);findRow.Controls.Add(count,1,0);
            root.Controls.Add(findRow,0,1);

            var listCard=UiPalette.CreateCard(15);listCard.Dock=DockStyle.Fill;
            listCard.Padding=new Padding(9);root.Controls.Add(listCard,0,2);
            wordList=new ListBox {Dock=DockStyle.Fill,IntegralHeight=false,HorizontalScrollbar=true,
                BackColor=UiPalette.Card,ForeColor=UiPalette.Ink,Font=new Font("Segoe UI",10),
                BorderStyle=BorderStyle.None,Margin=Padding.Empty};
            listCard.Controls.Add(wordList);

            var editor=new TableLayoutPanel {Dock=DockStyle.Fill,ColumnCount=3,RowCount=1,
                Margin=Padding.Empty,BackColor=Color.Transparent};
            editor.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            editor.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,118));
            editor.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,112));
            wordBox=new TextBox {Dock=DockStyle.Fill,Margin=new Padding(0,10,12,5),
                Font=new Font("Segoe UI",10)};
            var add=ActionButton(UiText.T("Thêm / sửa"),true);
            var remove=ActionButton(UiText.T("Xóa từ"),false);
            editor.Controls.Add(wordBox,0,0);editor.Controls.Add(add,1,0);editor.Controls.Add(remove,2,0);
            root.Controls.Add(editor,0,3);

            var footer=new TableLayoutPanel {Dock=DockStyle.Fill,ColumnCount=3,RowCount=1,
                Margin=Padding.Empty,BackColor=Color.Transparent};
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,96));
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,122));
            message=new Label {Text=UiText.T("Mỗi dòng một từ gồm a-z. Không lưu lịch sử gõ."),
                Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleLeft,Font=new Font("Segoe UI",8.5f),
                ForeColor=UiPalette.Muted,AutoEllipsis=true};
            var cancel=ActionButton(UiText.T("Hủy"),false);
            var save=ActionButton(UiText.T("Lưu thay đổi"),true);
            footer.Controls.Add(message,0,0);footer.Controls.Add(cancel,1,0);footer.Controls.Add(save,2,0);
            root.Controls.Add(footer,0,4);

            LoadWords();
            searchBox.TextChanged+=delegate {RefreshList();};
            wordList.SelectedIndexChanged+=delegate {
                if(wordList.SelectedItem!=null)wordBox.Text=wordList.SelectedItem.ToString();
            };
            add.Click+=delegate {AddWord();};remove.Click+=delegate {RemoveWord();};
            save.Click+=delegate {SaveWords();};cancel.Click+=delegate {Close();};
            wordBox.KeyDown+=delegate(object sender,KeyEventArgs e) {
                if(e.KeyCode==Keys.Enter){e.SuppressKeyPress=true;AddWord();}
            };
            FormClosing+=delegate(object sender,FormClosingEventArgs e) {
                if(!changed||DialogResult==DialogResult.OK)return;
                var answer=MessageBox.Show(this,UiText.T("Bạn có thay đổi chưa lưu. Đóng mà không lưu?"),
                    UiText.T("TelexMini — Smart Bilingual Typing"),MessageBoxButtons.YesNo,MessageBoxIcon.Question);
                if(answer==DialogResult.No)e.Cancel=true;
            };
            UiPalette.Apply(this);
            listCard.StartColor=listCard.EndColor=UiPalette.Card;listCard.Outline=UiPalette.Border;
            wordList.BackColor=UiPalette.Card;wordList.ForeColor=UiPalette.Ink;
            UiPalette.StyleTextBox(searchBox);UiPalette.StyleTextBox(wordBox);
            UiPalette.StyleButton(add,true);UiPalette.StyleButton(remove);UiPalette.StyleButton(cancel);
            UiPalette.StyleButton(save,true);
        }

        static Button ActionButton(string text,bool primary) {
            var button=new Button {Dock=DockStyle.Fill,Text=text,Margin=new Padding(5,6,0,5)};
            UiPalette.StyleButton(button,primary);return button;
        }
        static bool IsWord(string word) {
            if(word.Length==0||word.Length>64)return false;
            foreach(char c in word)if(c<'a'||c>'z')return false;
            return true;
        }
        void LoadWords() {
            try {
                string legacy=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
                    vietnamese?"VietnameseOverrides.txt":"EnglishWords.txt");
                foreach(string file in new[]{File.Exists(path)?path:legacy}) {
                    if(!File.Exists(file))continue;
                    foreach(string line in File.ReadAllLines(file,Encoding.UTF8)) {
                        string word=line.Trim().ToLowerInvariant();if(IsWord(word))words.Add(word);
                    }
                }
                RefreshList();
            } catch(Exception ex) {message.Text=UiText.T("Không đọc được từ điển: ")+ex.Message;}
        }
        void RefreshList() {
            string filter=searchBox.Text.Trim().ToLowerInvariant();
            string selected=wordList.SelectedItem as string;
            wordList.BeginUpdate();wordList.Items.Clear();
            foreach(string word in words.OrderBy(s=>s,StringComparer.Ordinal))
                if(word.Contains(filter))wordList.Items.Add(word);
            if(selected!=null&&wordList.Items.Contains(selected))wordList.SelectedItem=selected;
            wordList.EndUpdate();count.Text=wordList.Items.Count+" / "+words.Count+" "+UiText.T("Từ");
        }
        void AddWord() {
            string word=wordBox.Text.Trim().ToLowerInvariant();
            if(!IsWord(word)){message.Text=UiText.T("Từ phải dài 1–64 ký tự, chỉ gồm a-z.");return;}
            string selected=wordList.SelectedItem as string;
            if(selected!=null&&selected!=word&&words.Contains(selected))words.Remove(selected);
            if(words.Add(word)||(selected!=null&&selected!=word))changed=true;
            searchBox.Clear();RefreshList();wordList.SelectedItem=word;
            message.Text=UiText.T("Đã thay đổi. Bấm Lưu để áp dụng.");
        }
        void RemoveWord() {
            string selected=wordList.SelectedItem as string;if(selected==null)return;
            if(words.Remove(selected))changed=true;
            wordBox.Clear();RefreshList();message.Text=UiText.T("Đã xóa khỏi danh sách. Bấm Lưu để áp dụng.");
        }
        void SaveWords() {
            try {
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                string tmp=path+".tmp";
                File.WriteAllLines(tmp,words.OrderBy(s=>s,StringComparer.Ordinal).ToArray(),new UTF8Encoding(false));
                if(File.Exists(path))File.Replace(tmp,path,null);else File.Move(tmp,path);
                DialogResult=DialogResult.OK;Close();
            } catch(Exception ex) {
                MessageBox.Show(this,UiText.T("Không lưu được từ điển:\n")+ex.Message,
                    UiText.T("TelexMini — Smart Bilingual Typing"),MessageBoxButtons.OK,MessageBoxIcon.Error);
            }
        }
    }
}