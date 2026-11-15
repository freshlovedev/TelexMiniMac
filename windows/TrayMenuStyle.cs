using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace TelexMini
{
    // Native tray popup shares the desktop application's navy/teal palette.
    internal static class TrayMenuStyle
    {
        internal static bool Dark = false;
        internal static Color Base { get { return Dark ? Color.FromArgb(13,31,48) : Color.FromArgb(249,252,255); } }
        internal static Color Elevated { get { return Dark ? Color.FromArgb(20,46,64) : Color.FromArgb(234,247,245); } }
        internal static Color Highlight { get { return Dark ? Color.FromArgb(0,125,122) : Color.FromArgb(216,244,239); } }
        internal static Color TextColor { get { return Dark ? Color.FromArgb(241,249,252) : Color.FromArgb(24,48,65); } }
        internal static Color Muted { get { return Dark ? Color.FromArgb(155,186,201) : Color.FromArgb(96,123,139); } }
        internal static Color Divider { get { return Dark ? Color.FromArgb(46,77,96) : Color.FromArgb(212,228,235); } }

        internal static void ApplyTheme(ContextMenuStrip menu, bool dark)
        {
            Dark = dark;
            menu.BackColor = Base;
            menu.ForeColor = TextColor;
            foreach(ToolStripItem item in menu.Items) {
                item.BackColor = Base;
                item.ForeColor = item is ToolStripLabel ? (Dark ? Color.FromArgb(123,237,220) : Color.FromArgb(0,112,106)) : TextColor;
                var command = item as ToolStripMenuItem;
                if(command != null && command.Tag is string) {
                    if(command.Image != null) command.Image.Dispose();
                    command.Image = Glyph((string)command.Tag);
                }
            }
            menu.Invalidate(true);
        }

        internal static ContextMenuStrip Create()
        {
            var menu = new ContextMenuStrip();
            menu.RenderMode = ToolStripRenderMode.Professional;
            menu.Renderer = new TrayRenderer();
            menu.BackColor = Base;
            menu.ForeColor = TextColor;
            menu.Font = new Font("Segoe UI", 10.5f, FontStyle.Regular);
            menu.ShowImageMargin = true;
            menu.ShowCheckMargin = false;
            menu.ImageScalingSize = new Size(21, 21);
            menu.Padding = new Padding(5, 7, 5, 7);
            menu.AutoSize = true;
            ApplyTheme(menu, false);
            return menu;
        }

        internal static void AddHeader(ContextMenuStrip menu)
        {
            var header = new ToolStripLabel("  TelexMini   ·   BỘ GÕ SONG NGỮ");
            header.Font = new Font("Segoe UI", 10.5f, FontStyle.Bold);
            header.ForeColor = Color.FromArgb(123, 237, 220);
            header.AutoSize = false;
            header.Size = new Size(310, 39);
            header.TextAlign = ContentAlignment.MiddleLeft;
            header.Image = AppIcons.Brand.ToBitmap();
            header.ImageAlign = ContentAlignment.MiddleLeft;
            header.ImageScaling = ToolStripItemImageScaling.SizeToFit;
            menu.Items.Add(header);
            menu.Items.Add(new ToolStripSeparator());
        }

        internal static ToolStripMenuItem Add(ContextMenuStrip menu, string label, string symbol, EventHandler action)
        {
            var item = new ToolStripMenuItem(label);
            item.AutoSize = false;
            item.Size = new Size(310, 37);
            item.TextAlign = ContentAlignment.MiddleLeft;
            item.Tag = symbol;
            item.Image = Glyph(symbol);
            item.ImageAlign = ContentAlignment.MiddleCenter;
            item.ForeColor = TextColor;
            item.Font = new Font("Segoe UI", 10.5f);
            if(action != null) item.Click += action;
            menu.Items.Add(item);
            return item;
        }

        internal static Bitmap Glyph(string symbol)
        {
            var bmp = new Bitmap(24, 24);
            using(var g = Graphics.FromImage(bmp))
            using(var bg = new SolidBrush((Dark ? Color.FromArgb(25,82,99) : Color.FromArgb(225,246,243))))
            using(var outline = new Pen((Dark ? Color.FromArgb(71,190,184) : Color.FromArgb(75,164,157)), 1f))
            using(var path = RoundedPanel.Rounded(new Rectangle(1, 1, 22, 22), 6))
            using(var f = new Font("Segoe UI Symbol", symbol.Length > 1 ? 9f : 12.5f, FontStyle.Bold, GraphicsUnit.Pixel))
            using(var fg = new SolidBrush((Dark ? Color.FromArgb(204,252,244) : Color.FromArgb(0,104,101))))
            using(var fmt = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
                g.FillPath(bg, path);
                g.DrawPath(outline, path);
                g.DrawString(symbol, f, fg, new RectangleF(1, 1, 22, 22), fmt);
            }
            return bmp;
        }

        sealed class TrayRenderer : ToolStripProfessionalRenderer
        {
            protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e)
            {
                using(var b = new SolidBrush(Base)) e.Graphics.FillRectangle(b, e.AffectedBounds);
            }

            protected override void OnRenderImageMargin(ToolStripRenderEventArgs e)
            {
                using(var b = new SolidBrush(Base)) e.Graphics.FillRectangle(b, e.AffectedBounds);
            }

            protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e)
            {
                using(var p = new Pen(Divider)) {
                    var rect = new Rectangle(0, 0, e.ToolStrip.Width - 1, e.ToolStrip.Height - 1);
                    e.Graphics.DrawRectangle(p, rect);
                }
            }

            protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e)
            {
                var bounds = new Rectangle(3, 1, e.Item.Width - 6, e.Item.Height - 2);
                using(var bg = new SolidBrush(e.Item.Selected ? Highlight : Base))
                using(var path = RoundedPanel.Rounded(bounds, 8))
                    e.Graphics.FillPath(bg, path);
            }

            protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
            {
                e.TextColor = e.Item.Enabled ? (e.Item.Selected && Dark ? Color.White : TextColor) : Muted;
                base.OnRenderItemText(e);
            }

            protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e)
            {
                var y = e.Item.Height / 2;
                using(var p = new Pen(Divider))
                    e.Graphics.DrawLine(p, 13, y, e.Item.Width - 13, y);
            }

            protected override void OnRenderItemCheck(ToolStripItemImageRenderEventArgs e)
            {
                var rect = new Rectangle(e.ImageRectangle.X + 4, e.ImageRectangle.Y + 4, 12, 12);
                using(var p = new Pen(Color.FromArgb(86, 248, 197), 2.4f)) {
                    p.StartCap = LineCap.Round;
                    p.EndCap = LineCap.Round;
                    e.Graphics.DrawLines(p, new [] {
                        new Point(rect.X, rect.Y + 6),
                        new Point(rect.X + 4, rect.Y + 10),
                        new Point(rect.X + 12, rect.Y)
                    });
                }
            }
        }
    }
}
