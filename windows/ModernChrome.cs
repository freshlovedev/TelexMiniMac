using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace TelexMini
{
    internal sealed class RoundedPanel : Panel
    {
        internal Color StartColor=Color.White, EndColor=Color.White, Outline=Color.Transparent;
        internal int CornerRadius=18;
        internal RoundedPanel() {
            SetStyle(ControlStyles.AllPaintingInWmPaint|ControlStyles.UserPaint|
                     ControlStyles.OptimizedDoubleBuffer|ControlStyles.ResizeRedraw,true);
        }
        internal static GraphicsPath Rounded(Rectangle bounds,int radius) {
            int d=Math.Min(radius*2,Math.Min(bounds.Width,bounds.Height));
            var path=new GraphicsPath();
            if(d<=0){path.AddRectangle(bounds);return path;}
            path.AddArc(bounds.Left,bounds.Top,d,d,180,90);
            path.AddArc(bounds.Right-d,bounds.Top,d,d,270,90);
            path.AddArc(bounds.Right-d,bounds.Bottom-d,d,d,0,90);
            path.AddArc(bounds.Left,bounds.Bottom-d,d,d,90,90);
            path.CloseFigure();return path;
        }
        protected override void OnResize(EventArgs e) {
            base.OnResize(e);
            if(Width>0&&Height>0) using(var p=Rounded(new Rectangle(0,0,Width,Height),CornerRadius))
                Region=new Region(p);
        }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
            var b=new Rectangle(1,1,Math.Max(1,Width-3),Math.Max(1,Height-3));
            using(var p=Rounded(b,CornerRadius)) {
                if(StartColor==EndColor) using(var brush=new SolidBrush(StartColor)) e.Graphics.FillPath(brush,p);
                else using(var brush=new LinearGradientBrush(b,StartColor,EndColor,18f)) e.Graphics.FillPath(brush,p);
                if(Outline.A>0) using(var pen=new Pen(Outline,1f)) e.Graphics.DrawPath(pen,p);
            }
        }
    }

    // Fluent-inspired local WinForms UI. No WebView, remote assets or telemetry.
    internal sealed class ModernChrome
    {
        readonly Form form;
        readonly Button modeButton;
        readonly Label status;
        Label heroTag,heroTitle,modeCaption,modeReason,footer;
        readonly CheckBox autoEnglish,restoreWords,smartEnglish;
        readonly Button hideButton,exitButton;
        Button themeButton;
        RoundedPanel hero,leftCard,rightCard,previewCard,privacyCard;
        readonly Panel sidebar,main;
        FlowLayoutPanel navigation,content,cardsRow;
        TextBox inputPreview;
        readonly List<Button> navButtons=new List<Button>();
        readonly Action openEnglish,openVietnamese,reload,advanced,productivity,symbols;
        bool dark;
        Color page,card,field,muted,ink,outline,accent,blue;
        int activeNavigation;

        internal ModernChrome(Form owner,Button toggle,Label statusLabel,CheckBox auto,CheckBox restore,CheckBox smart,
                              Button hide,Button exit,Action openEnglish,Action openVietnamese,Action reload,
                              Action advanced=null,Action productivity=null,Action symbols=null)
        {
            form=owner;modeButton=toggle;status=statusLabel;hideButton=hide;exitButton=exit;
            autoEnglish=auto;restoreWords=restore;smartEnglish=smart;
            this.openEnglish=openEnglish;this.openVietnamese=openVietnamese;this.reload=reload;
            this.advanced=advanced;this.productivity=productivity;this.symbols=symbols;
            dark=UserPreferences.Bool("DarkTheme",false);

            form.SuspendLayout();
            form.Controls.Clear();
            form.Text=UiText.T("TelexMini — Smart Bilingual Typing");
            form.ClientSize=new Size(1180,780);
            form.MinimumSize=new Size(1000,700);
            form.MaximumSize=new Size(1800,1200);
            form.AutoScaleMode=AutoScaleMode.Dpi;
            form.FormBorderStyle=FormBorderStyle.Sizable;
            form.MaximizeBox=true;
            form.TopMost=false;
            form.StartPosition=FormStartPosition.CenterScreen;
            form.Font=new Font("Segoe UI",9.5f);

            var shell=new TableLayoutPanel {
                Dock=DockStyle.Fill,Margin=Padding.Empty,Padding=Padding.Empty,
                ColumnCount=2,RowCount=1
            };
            shell.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,232));
            shell.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            shell.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            form.Controls.Add(shell);

            sidebar=new Panel {Dock=DockStyle.Fill,Margin=Padding.Empty,Padding=Padding.Empty};
            main=new Panel {Dock=DockStyle.Fill,Margin=Padding.Empty,Padding=Padding.Empty,AutoScroll=true};
            shell.Controls.Add(sidebar,0,0);shell.Controls.Add(main,1,0);

            BuildSidebar();
            BuildMain();
            form.ResumeLayout(true);
            ApplyTheme();
        }

        void BuildSidebar() {
            var layout=new TableLayoutPanel {
                Dock=DockStyle.Fill,Padding=new Padding(15,19,15,15),Margin=Padding.Empty,
                ColumnCount=1,RowCount=5
            };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute,72));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute,30));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute,118));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute,25));
            sidebar.Controls.Add(layout);

            var brand=new Panel {Dock=DockStyle.Fill};
            var logo=new RoundedPanel {Location=new Point(2,4),Size=new Size(48,48),CornerRadius=15,
                StartColor=Color.FromArgb(0,139,137),EndColor=Color.FromArgb(0,205,190)};
            brand.Controls.Add(logo);
            logo.Controls.Add(MakeLabel("T",new Rectangle(0,1,48,44),Color.White,24,true,ContentAlignment.MiddleCenter));
            brand.Controls.Add(MakeLabel("telexmini",new Rectangle(61,3,145,27),Color.White,16,true));
            brand.Controls.Add(MakeLabel("BILINGUAL INPUT",new Rectangle(62,31,132,18),
                Color.FromArgb(150,174,198),7.2f,true));
            layout.Controls.Add(brand,0,0);

            layout.Controls.Add(MakeLabel(UiText.T("KHÔNG GIAN"),new Rectangle(3,0,190,22),
                Color.FromArgb(137,159,181),8.1f,true),0,1);

            navigation=new FlowLayoutPanel {
                Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,
                AutoScroll=true,Padding=new Padding(0,4,0,0),Margin=Padding.Empty
            };
            layout.Controls.Add(navigation,0,2);
            AddNavigation(UiText.T("◈  Tổng quan"),delegate {SetActive(0);main.AutoScrollPosition=new Point(0,0);inputPreview.Focus();});
            AddNavigation(UiText.T("＋  Từ điển Anh"),delegate {SetActive(1);if(this.openEnglish!=null)this.openEnglish();SetActive(0);});
            AddNavigation(UiText.T("≡  Ưu tiên Telex"),delegate {SetActive(2);if(this.openVietnamese!=null)this.openVietnamese();SetActive(0);});
            AddNavigation(UiText.T("⚡  Gõ tắt"),delegate {SetActive(3);if(this.productivity!=null)this.productivity();SetActive(0);});
            AddNavigation(UiText.T("⌘  Ký tự nhanh"),delegate {SetActive(4);if(this.symbols!=null)this.symbols();SetActive(0);});
            AddNavigation(UiText.T("⚙  Cài đặt"),delegate {SetActive(5);if(this.advanced!=null)this.advanced();SetActive(0);});

            privacyCard=new RoundedPanel {Dock=DockStyle.Fill,CornerRadius=15};
            layout.Controls.Add(privacyCard,0,3);
            privacyCard.Controls.Add(MakeLabel(UiText.T("RIÊNG TƯ"),new Rectangle(14,13,180,18),
                Color.FromArgb(82,218,188),8.2f,true));
            privacyCard.Controls.Add(MakeLabel(UiText.T("Không lưu nội dung gõ\nKhông gửi dữ liệu lên mạng"),
                new Rectangle(14,39,184,52),Color.FromArgb(188,204,219),8.3f,false));
            layout.Controls.Add(MakeLabel("WINDOWS DESKTOP",new Rectangle(3,3,190,19),
                Color.FromArgb(121,145,168),7.8f,true),0,4);
        }

        void AddNavigation(string text,Action action) {
            var button=new Button {
                Text=text,Width=198,Height=43,Margin=new Padding(0,3,0,3),
                FlatStyle=FlatStyle.Flat,TextAlign=ContentAlignment.MiddleLeft,
                Padding=new Padding(13,0,6,0),Font=new Font("Segoe UI Semibold",9.2f,FontStyle.Bold),
                Cursor=Cursors.Hand,TabStop=true
            };
            button.FlatAppearance.BorderSize=0;
            button.Click+=delegate {action();};
            navigation.Controls.Add(button);navButtons.Add(button);
        }

        void BuildMain() {
            var root=new TableLayoutPanel {
                Dock=DockStyle.Fill,Margin=Padding.Empty,Padding=Padding.Empty,
                ColumnCount=1,RowCount=3
            };
            root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute,116));
            root.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute,48));
            main.Controls.Add(root);

            var header=new Panel {Dock=DockStyle.Fill,Padding=new Padding(30,17,30,12)};
            root.Controls.Add(header,0,0);
            header.Controls.Add(MakeLabel(UiText.T("TELEXMINI / BẢNG ĐIỀU KHIỂN"),
                new Rectangle(0,8,500,18),Color.Empty,8.3f,true));
            header.Controls.Add(MakeLabel(UiText.T("Gõ theo cách của bạn."),
                new Rectangle(0,27,560,46),Color.Empty,20.5f,true));
            header.Controls.Add(MakeLabel(UiText.T("Hai ngôn ngữ. Một trải nghiệm liền mạch."),
                new Rectangle(1,76,520,20),Color.Empty,9.6f,false));
            themeButton=MakeButton(UiText.T("☾  Giao diện"),new Size(142,39));
            themeButton.Anchor=AnchorStyles.Top|AnchorStyles.Right;
            themeButton.Location=new Point(Math.Max(535,header.ClientSize.Width-142),28);
            header.Controls.Add(themeButton);
            header.Resize+=delegate {themeButton.Left=Math.Max(535,header.ClientSize.Width-themeButton.Width);};
            themeButton.Click+=delegate {
                dark=!dark;UserPreferences.Set("DarkTheme",dark);ApplyTheme();
            };

            content=new FlowLayoutPanel {
                Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,
                AutoScroll=true,Padding=new Padding(28,18,28,24),Margin=Padding.Empty
            };
            root.Controls.Add(content,0,1);

            hero=new RoundedPanel {Width=880,Height=202,Margin=new Padding(0,0,0,18),
                CornerRadius=21,BackColor=Color.FromArgb(0,139,137)};
            content.Controls.Add(hero);
            heroTag=MakeLabel(UiText.T("CHẾ ĐỘ HIỆN TẠI"),new Rectangle(24,19,300,19),
                Color.FromArgb(197,246,236),8.4f,true);
            hero.Controls.Add(heroTag);
            heroTitle=MakeLabel(UiText.T("Chuyển chế độ tức thì"),
                new Rectangle(24,47,420,29),Color.White,15.2f,true);
            hero.Controls.Add(heroTitle);
            modeButton.Location=new Point(23,111);modeButton.Size=new Size(286,59);
            modeButton.FlatStyle=FlatStyle.Flat;modeButton.FlatAppearance.BorderSize=0;
            modeButton.Font=new Font("Segoe UI Semibold",14,FontStyle.Bold);
            modeButton.ForeColor=Color.FromArgb(8,67,70);modeButton.Cursor=Cursors.Hand;
            modeButton.Anchor=AnchorStyles.Left|AnchorStyles.Bottom;
            hero.Controls.Add(modeButton);
            modeCaption=MakeLabel(UiText.T("CỤC BỘ · RIÊNG TƯ · NHANH"),
                new Rectangle(355,50,470,20),Color.FromArgb(196,243,235),8.3f,true);
            hero.Controls.Add(modeCaption);
            modeReason=MakeLabel(UiText.T("Không thu thập nội dung bạn gõ"),
                new Rectangle(355,79,470,24),Color.White,11.5f,true);
            hero.Controls.Add(modeReason);
            status.Location=new Point(355,110);status.Size=new Size(470,64);
            status.Font=new Font("Segoe UI",9.2f);status.ForeColor=Color.FromArgb(224,239,246);
            status.BackColor=Color.Transparent;status.TextAlign=ContentAlignment.TopLeft;
            hero.Controls.Add(status);
            hero.Resize+=delegate {
                int right=Math.Max(335,hero.ClientSize.Width-hero.Width/2);
                modeCaption.Left=right;modeReason.Left=right;status.Left=right;
                modeCaption.Width=hero.Width-right-24;modeReason.Width=hero.Width-right-24;
                status.Width=hero.Width-right-24;
            };

            var section=MakeLabel(UiText.T("TÙY CHỈNH TRẢI NGHIỆM"),
                new Rectangle(0,0,450,23),Color.Empty,11.2f,true);
            content.Controls.Add(section);

            cardsRow=new FlowLayoutPanel {
                Width=880,Height=190,AutoSize=false,WrapContents=false,
                FlowDirection=FlowDirection.LeftToRight,Margin=new Padding(0,9,0,18),
                Padding=Padding.Empty
            };
            content.Controls.Add(cardsRow);

            leftCard=new RoundedPanel {Size=new Size(410,174),CornerRadius=17,
                Margin=new Padding(0,0,16,0)};
            cardsRow.Controls.Add(leftCard);
            leftCard.Controls.Add(MakeLabel(UiText.T("NGÔN NGỮ & NHẬN DIỆN"),
                new Rectangle(19,16,360,19),Color.Empty,8.6f,true));
            smartEnglish.Text=UiText.T("Bảo vệ từ tiếng Anh (offline)");
            restoreWords.Text=UiText.T("Khôi phục từ không hợp lệ");
            smartEnglish.Visible=true;restoreWords.Visible=true;
            smartEnglish.Location=new Point(17,52);smartEnglish.Size=new Size(370,29);
            restoreWords.Location=new Point(17,91);restoreWords.Size=new Size(370,29);
            leftCard.Controls.Add(smartEnglish);leftCard.Controls.Add(restoreWords);
            leftCard.Controls.Add(MakeLabel(UiText.T("Nhận diện offline, đặt dấu ngay khi gõ"),
                new Rectangle(19,136,370,20),Color.Empty,8.2f,false));

            rightCard=new RoundedPanel {Size=new Size(410,174),CornerRadius=17,
                Margin=new Padding(0,0,0,0)};
            cardsRow.Controls.Add(rightCard);
            rightCard.Controls.Add(MakeLabel(UiText.T("TƯƠNG THÍCH & AN TOÀN"),
                new Rectangle(19,16,360,19),Color.Empty,8.3f,true));
            autoEnglish.Location=new Point(17,52);autoEnglish.Size=new Size(370,29);
            rightCard.Controls.Add(autoEnglish);
            rightCard.Controls.Add(MakeLabel(UiText.T("Mật khẩu: tự dùng tiếng Anh"),
                new Rectangle(20,96,360,22),Color.FromArgb(49,188,153),10f,true));
            rightCard.Controls.Add(MakeLabel(UiText.T("Không xử lý nội dung ô mật khẩu"),
                new Rectangle(20,126,360,20),Color.Empty,8.4f,false));

            previewCard=new RoundedPanel {Width=880,Height=105,CornerRadius=16,
                Margin=new Padding(0,0,0,15)};
            content.Controls.Add(previewCard);
            previewCard.Controls.Add(MakeLabel(UiText.T("THỬ GÕ NGAY"),
                new Rectangle(18,12,250,18),Color.Empty,8.2f,true));
            inputPreview=new TextBox {
                Location=new Point(18,43),Size=new Size(830,36),
                BorderStyle=BorderStyle.FixedSingle,Font=new Font("Segoe UI",11.5f),
                ShortcutsEnabled=true
            };
            previewCard.Controls.Add(inputPreview);
            content.Resize+=delegate {LayoutContent();};
            main.Resize+=delegate {LayoutContent();};

            var footerPanel=new Panel {Dock=DockStyle.Fill,Padding=new Padding(28,5,28,5)};
            root.Controls.Add(footerPanel,0,2);
            footer=MakeLabel(EnglishLexicon.WordCount.ToString("N0")+UiText.T(" từ nền · Hoạt động offline"),
                new Rectangle(0,6,400,22),Color.Empty,8.2f,false);
            footerPanel.Controls.Add(footer);
            hideButton.Text=UiText.T("Thu xuống khay");hideButton.Size=new Size(144,34);
            hideButton.Anchor=AnchorStyles.Top|AnchorStyles.Right;
            exitButton.Text=UiText.T("Thoát");exitButton.Size=new Size(86,34);
            exitButton.Anchor=AnchorStyles.Top|AnchorStyles.Right;
            footerPanel.Controls.Add(hideButton);footerPanel.Controls.Add(exitButton);
            footerPanel.Resize+=delegate {
                exitButton.Location=new Point(footerPanel.ClientSize.Width-28-exitButton.Width,1);
                hideButton.Location=new Point(exitButton.Left-10-hideButton.Width,1);
                footer.Width=Math.Max(200,hideButton.Left-18);
            };
        }

        void LayoutContent() {
            if(content==null||main==null)return;
            int width=Math.Max(620,main.ClientSize.Width-56);
            content.Width=Math.Max(620,main.ClientSize.Width);
            hero.Width=width;
            cardsRow.Width=width;
            leftCard.Width=Math.Max(300,(width-16)/2);
            rightCard.Width=leftCard.Width;
            smartEnglish.Width=leftCard.Width-40;restoreWords.Width=leftCard.Width-40;
            autoEnglish.Width=rightCard.Width-40;
            previewCard.Width=width;
            inputPreview.Width=Math.Max(300,width-40);
            int right=Math.Max(335,hero.ClientSize.Width/2);
            heroTitle.Width=Math.Max(290,right-48);
            modeCaption.Left=right;modeReason.Left=right;status.Left=right;
            modeCaption.Width=hero.Width-right-24;modeReason.Width=hero.Width-right-24;
            status.Width=hero.Width-right-24;
        }

        static Label MakeLabel(string text,Rectangle bounds,Color color,float size,bool bold,
                               ContentAlignment alignment=ContentAlignment.MiddleLeft) {
            return new Label {
                Text=text,Location=bounds.Location,Size=bounds.Size,
                ForeColor=color,BackColor=Color.Transparent,TextAlign=alignment,
                Font=new Font("Segoe UI",size,bold?FontStyle.Bold:FontStyle.Regular),
                AutoEllipsis=true
            };
        }
        static Button MakeButton(string text,Size size) {
            var b=new Button {Text=text,Size=size,FlatStyle=FlatStyle.Flat,
                Font=new Font("Segoe UI Semibold",9.3f,FontStyle.Bold),
                Cursor=Cursors.Hand,TabStop=true};
            b.FlatAppearance.BorderSize=0;return b;
        }
        void SetActive(int index) {
            activeNavigation=index;
            ApplyNavigationTheme();
        }
        void ApplyNavigationTheme() {
            for(int i=0;i<navButtons.Count;i++) {
                var b=navButtons[i];
                b.BackColor=i==activeNavigation?Color.FromArgb(17,105,105):Color.FromArgb(13,31,48);
                b.ForeColor=i==activeNavigation?Color.FromArgb(116,245,222):Color.FromArgb(217,231,242);
                b.FlatAppearance.MouseOverBackColor=Color.FromArgb(24,57,72);
            }
        }
        internal void ReloadTheme() {
            dark=UserPreferences.Bool("DarkTheme",false);ApplyTheme();
        }
        void ApplyTheme() {
            page=dark?Color.FromArgb(15,25,40):Color.FromArgb(246,249,252);
            card=dark?Color.FromArgb(20,34,54):Color.White;
            field=dark?Color.FromArgb(25,43,65):Color.FromArgb(238,244,250);
            outline=dark?Color.FromArgb(39,57,79):Color.FromArgb(220,230,240);
            ink=dark?Color.FromArgb(234,242,251):Color.FromArgb(22,50,74);
            muted=dark?Color.FromArgb(158,178,206):Color.FromArgb(104,126,150);
            accent=dark?Color.FromArgb(55,214,194):Color.FromArgb(22,156,149);
            blue=dark?Color.FromArgb(74,124,255):Color.FromArgb(59,110,245);

            form.BackColor=page;main.BackColor=page;
            // Keep branded navigation dark in both themes; content surfaces
            // switch independently for consistent white-on-navy contrast.
            sidebar.BackColor=dark?Color.FromArgb(10,19,34):Color.FromArgb(16,31,50);
            foreach(Control child in sidebar.Controls) ApplyTree(child,true);
            foreach(Control child in main.Controls) ApplyTree(child,false);

            hero.StartColor=dark?Color.FromArgb(0,105,111):Color.FromArgb(0,145,137);
            hero.EndColor=dark?Color.FromArgb(15,68,91):Color.FromArgb(28,126,168);
            hero.BackColor=hero.StartColor;hero.Outline=dark?Color.FromArgb(30,143,145):Color.FromArgb(174,224,222);
            foreach(RoundedPanel panel in new[]{leftCard,rightCard,previewCard,privacyCard}) {
                panel.StartColor=panel.EndColor=card;panel.BackColor=card;
                panel.Outline=outline;
            }
            themeButton.BackColor=card;themeButton.ForeColor=ink;
            themeButton.Text=UiText.T(dark?"☀  Sáng":"☾  Tối");
            modeButton.BackColor=Color.FromArgb(226,255,247);
            modeButton.ForeColor=Color.FromArgb(8,49,62);
            modeButton.FlatAppearance.MouseOverBackColor=Color.FromArgb(198,248,238);
            heroTag.ForeColor=Color.FromArgb(196,243,235);
            modeCaption.ForeColor=Color.FromArgb(196,243,235);
            modeReason.ForeColor=Color.White;
            status.ForeColor=Color.FromArgb(224,239,246);
            footer.ForeColor=muted;
            foreach(var c in new[]{smartEnglish,restoreWords,autoEnglish}) {
                c.FlatStyle=FlatStyle.Flat;c.UseVisualStyleBackColor=false;
                c.ForeColor=ink;c.BackColor=card;c.Font=new Font("Segoe UI",9.2f);
                c.TextAlign=ContentAlignment.MiddleLeft;
            }
            inputPreview.BackColor=field;inputPreview.ForeColor=ink;
            foreach(var b in new[]{hideButton,exitButton}) {
                b.BackColor=card;b.ForeColor=ink;b.FlatStyle=FlatStyle.Flat;
                b.FlatAppearance.BorderSize=1;b.FlatAppearance.BorderColor=outline;
                b.FlatAppearance.MouseOverBackColor=field;
            }
            ApplyNavigationTheme();
            form.Invalidate(true);
        }
        void ApplyTree(Control root,bool inSidebar) {
            foreach(Control child in root.Controls) {
                var label=child as Label;
                if(label!=null) {
                    if(inSidebar) {
                        label.ForeColor=label.Font.Size<8.5f?Color.FromArgb(143,165,187):
                            Color.FromArgb(225,236,246);
                    } else if(label.Parent==hero) {
                        // Hero labels keep their explicit high-contrast colors.
                    } else if(label.ForeColor==Color.FromArgb(49,188,153)) label.ForeColor=accent;
                    else label.ForeColor=label.Font.Size<9f?muted:ink;
                }
                var check=child as CheckBox;
                if(check!=null){check.ForeColor=ink;check.BackColor=card;}
                var text=child as TextBox;
                if(text!=null){text.BackColor=field;text.ForeColor=ink;}
                var button=child as Button;
                if(button!=null && !navButtons.Contains(button)) {
                    button.BackColor=card;button.ForeColor=ink;
                }
                if(child is Panel) ApplyTree(child,inSidebar);
            }
        }
        internal void UpdateMode(bool active,bool automatic,bool paused,InputContextKind kind) {
            if(paused) {
                modeReason.Text=UiText.T("Đang nhường phím cho game / remote");
                modeCaption.Text=UiText.T("HOOK BÀN PHÍM ĐÃ TẮT");
            } else if(kind==InputContextKind.Password) {
                modeReason.Text=UiText.T("Mật khẩu được giữ nguyên");
                modeCaption.Text=UiText.T("BẢO VỆ MẬT KHẨU");
            } else if(automatic) {
                modeReason.Text=UiText.T("Tạm dừng xử lý khi nhận diện ô nhập");
                modeCaption.Text=UiText.T("CHẾ ĐỘ AN TOÀN");
            } else if(active) {
                modeReason.Text=UiText.T("Gõ tiếng Việt và tiếng Anh tự nhiên");
                modeCaption.Text=UiText.T("CỤC BỘ · RIÊNG TƯ · NHANH");
            } else {
                modeReason.Text=UiText.T("Tất cả phím được gửi nguyên bản");
                modeCaption.Text=UiText.T("CHẾ ĐỘ TIẾNG ANH");
            }
        }
    }
}
