using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace TelexMini
{
    // One translation source for every Windows desktop surface.
    internal static class UiText
    {
        static readonly Dictionary<string,string> English=new Dictionary<string,string>(StringComparer.Ordinal) {
            {"TelexMini — Smart Bilingual Typing","TelexMini — Smart Bilingual Typing"},
            {"Ưu tiên","Priority"},{"Hiện nút chuyển","Show main window"},{"Mở TelexMini","Open TelexMini"},{"Kiểm tra bản cập nhật...","Check for updates..."},
            {"Từ","words"},{"Đã xóa khỏi danh sách. Bấm Lưu để áp dụng.","Removed from the list. Save to apply."},
            {"Không lưu được từ điển:\n","Could not save dictionary:\n"},
            {"TelexMini — Tiếng Việt","TelexMini — Vietnamese"},
            {"Telex Mini — Tiếng Việt","TelexMini — Vietnamese"},
            {"Telex Mini — Đã gỡ hook, tạm dừng bộ gõ","TelexMini — Input paused"},
            {"Telex Mini — English (đã gỡ hook)","TelexMini — English (pass-through)"},
            {"Không thay được ký tự","Could not replace text"},
            {"Ứng dụng đích có thể đang chạy quyền quản trị. Xem HUONG-DAN.md.","The target app may run as administrator. See HUONG-DAN.md."},
            {"Từ phải dài 1–64 ký tự, chỉ gồm a-z.","Word must be 1–64 characters and contain a-z only."},
            {"Đã thay đổi. Bấm Lưu để áp dụng.","Changes made. Save to apply."},
            {"Cài đặt gõ song ngữ","Bilingual typing settings"},
            {"Gợi ý: ","Suggestions: "},
            {"Không có gợi ý trong từ điển nhỏ.","No suggestion in the compact dictionary."},
            {"TelexMini — Ký tự nhanh","TelexMini — Quick symbols"},
            {"Nhấp ký tự để sao chép, sau đó Ctrl+V để chèn.","Select a symbol to copy, then press Ctrl+V to insert."},
            {"KHÔNG GIAN","WORKSPACE"},{"◈  Tổng quan","◈  Overview"},
            {"TÙY CHỈNH TRẢI NGHIỆM","PERSONALIZE YOUR EXPERIENCE"},
            {"NGÔN NGỮ & NHẬN DIỆN","LANGUAGE & RECOGNITION"},
            {"⚙  Cài đặt","⚙  Settings"},{"＋  Từ điển Anh","＋  English dictionary"},
            {"≡  Ưu tiên Telex","≡  Vietnamese priority"},{"↻  Nạp lại từ điển","↻  Reload dictionaries"},
            {"⚙  Cài đặt nâng cao","⚙  Advanced settings"},{"⚡  Gõ tắt","⚡  Snippets"},
            {"⚡  Gõ tắt & ứng dụng","⚡  Snippets & apps"},
            {"⌘  Ký tự nhanh","⌘  Quick symbols"},{"RIÊNG TƯ","PRIVATE BY DESIGN"},{"WINDOWS DESKTOP","DESKTOP · WINDOWS"},
            {"Không lưu nội dung gõ\nKhông gửi dữ liệu lên mạng","No typing history\nNo data sent online"},
            {"DESKTOP · WINDOWS","DESKTOP · WINDOWS"},{"OVERVIEW / BẢNG ĐIỀU KHIỂN","OVERVIEW / DASHBOARD"},
            {"Gõ theo cách của bạn.","Type your way."},{"Hai ngôn ngữ. Một trải nghiệm liền mạch.","Two languages. One seamless experience."},
            {"☾  Giao diện","☾  Appearance"},{"☀  Sáng","☀  Light"},{"☾  Tối","☾  Dark"},
            {"CHẾ ĐỘ HIỆN TẠI","CURRENT MODE"},{"Chuyển chế độ chỉ với một cú nhấn","Switch input mode with one click"},
            {"Chuyển chế độ tức thì","Switch modes instantly"},
            {"CỤC BỘ · RIÊNG TƯ · NHANH","LOCAL · PRIVATE · FAST"},{"Không thu thập nội dung bạn gõ","Your typed content stays private"},
            {"Tùy chỉnh trải nghiệm","Personalize your experience"},{"NGÔN NGỮ","LANGUAGE"},
            {"Nhận diện offline, đặt dấu ngay khi gõ","Offline recognition with instant accents"},
            {"TƯƠNG THÍCH & AN TOÀN","COMPATIBILITY & SAFETY"},{"Mật khẩu: tự dùng tiếng Anh","Password fields always use English"},
            {"Không xử lý nội dung ô mật khẩu","Secure fields are never processed"},
            {"THỬ GÕ NGAY","TRY TYPING"},{"Thu xuống khay","Minimize to tray"},{"Thoát","Quit"},
            {" từ nền · Hoạt động offline"," base words · Offline"},
            {"Đang nhường phím cho game / remote","Yielding input to game / remote"},
            {"Mật khẩu được giữ nguyên","Password input is protected"},
            {"Tạm dừng xử lý khi nhận diện ô nhập","Input context is being checked"},
            {"Gõ tiếng Việt và tiếng Anh tự nhiên","Natural Vietnamese and English typing"},
            {"Tất cả phím được gửi nguyên bản","All keystrokes pass through unchanged"},
            {"HOOK BÀN PHÍM ĐÃ TẮT","INPUT HOOKS OFF"},{"BẢO VỆ MẬT KHẨU","PASSWORD PROTECTION"},
            {"CHẾ ĐỘ AN TOÀN","SAFE MODE"},{"CHẾ ĐỘ TIẾNG ANH","ENGLISH MODE"},
            {"E  ·  NHƯỜNG PHÍM","E · INPUT PAUSED"},{"V  ·  TIẾNG VIỆT","V · VIETNAMESE"},
            {"E  ·  MẬT KHẨU","E · PASSWORD"},{"E  ·  TỰ ĐỘNG","E · AUTOMATIC"},{"E  ·  ENGLISH","E · ENGLISH"},
            {"Ô mật khẩu","Password field"},{"Chưa nhận diện được ô nhập","Input field not detected"},
            {"Đang nhận diện ô nhập","Detecting input field"},{"Terminal","Terminal"},
            {"Telex Mini — English: ","TelexMini — English: "},
            {"Dùng English cho mọi nơi","Use English everywhere"},{"Dùng Tiếng Việt (trừ ô mật khẩu)","Use Vietnamese (except password fields)"},
            {"Đã dừng hook bàn phím / chuột\nĐã dừng nhận diện ô nhập\nMenu khay: bật / tắt tạm dừng","Keyboard and mouse hooks paused\nInput detection paused\nTray menu: resume or pause"},
            {"Sẽ về V khi ô nhập phù hợp\nBấm E để dùng Anh mọi nơi","Vietnamese resumes in supported fields\nPress E to use English everywhere"},
            {"Ctrl + Shift + Space để chuyển\nMật khẩu luôn dùng English\nTelex + English thông minh","Ctrl + Shift + Space to switch\nPassword fields always use English\nSmart Telex + English"},
            {"Phím tắt đang bị ứng dụng khác dùng.\nMật khẩu luôn dùng English\nBấm nút V/E để chuyển","Shortcut is used by another app.\nPassword fields always use English\nUse the V/E button to switch"},
            {"Telex Mini đang chạy. Bấm biểu tượng V/E ở khay hệ thống.","TelexMini is already running. Use the V/E tray icon."},
            {"Không khởi động được Telex Mini:\n","Could not start TelexMini:\n"},
            {"Tự dùng English trong terminal","Use English automatically in terminal"},
            {"Khôi phục từ không hợp lệ","Restore invalid words"},{"Bảo vệ từ tiếng Anh (offline)","Protect English words (offline)"},
            {"Kiểu gõ: Telex / VNI","Typing method: Telex / VNI"},
            {"Ưu tiên tiếng Việt","Vietnamese first"},{"Ưu tiên tiếng Anh","English first"},
            {"Cân bằng","Balanced"},{"Phím tắt chuyển V/E","V/E shortcut"},{"Giao diện","Interface"},
            {"Tiếng Việt","Vietnamese"},{"Tự khởi động cùng Windows","Start with Windows"},
            {"Portable Mode (dữ liệu cạnh EXE, cần khởi động lại)","Portable mode (data beside EXE; restart required)"},
            {"Ứng dụng bỏ qua (tên tiến trình, cách nhau bằng dấu phẩy)","Excluded apps (process names, comma-separated)"},
            {"Cấu hình và từ điển lưu trên máy, không ghi lịch sử gõ.","Settings and dictionaries stay local. No typing history."},
            {"Lưu và áp dụng","Save and apply"},{"Hủy","Cancel"},{"Xuất","Export"},{"Nhập","Import"},
            {"Đã chuyển nơi lưu cấu hình. Hãy thoát và mở lại TelexMini.","Storage location changed. Restart TelexMini to apply."},
            {"Hãy chọn thư mục khác với thư mục cấu hình gốc.","Choose a folder other than the active settings folder."},
            {"Đã nhập cấu hình và từ điển.","Settings and dictionaries imported."},{"Đã xuất cấu hình.","Settings exported."},
            {"TelexMini — Gõ tắt & ứng dụng","TelexMini — Snippets & app profiles"},
            {"NĂNG SUẤT — OFFLINE","PRODUCTIVITY — OFFLINE"},
            {"Bật gõ tắt sau dấu cách / Enter / Tab","Expand snippets after Space / Enter / Tab"},
            {"Mỗi dòng: phím tắt a-z [Tab] văn bản. Ví dụ: dc<TAB>được. Mặc định tắt.","One rule per line: a-z shortcut [Tab] replacement. Example: dc<TAB>được. Off by default."},
            {"Bật cấu hình theo ứng dụng","Enable per-app profiles"},
            {"Mỗi dòng: process.exe [Tab] English / Vietnamese / Balanced","One rule per line: process.exe [Tab] English / Vietnamese / Balanced"},
            {"Chỉ lưu phím tắt và tên ứng dụng. Không ghi nội dung đã gõ.","Only shortcuts and app names are stored. Typed content is never logged."},
            {"Gợi ý sửa:","Spelling suggestions:"},{"Gợi ý (không tự sửa)","Suggest (no auto-correction)"},
            {"Chỉ tra cứu khi bấm nút · Offline","Manual lookup only · Offline"},
            {"TelexMini · Ưu tiên tiếng Việt","TelexMini · Vietnamese priority"},
            {"TelexMini · Từ điển tiếng Anh","TelexMini · English dictionary"},
            {"Ưu tiên Telex","Vietnamese priority"},{"Từ điển tiếng Anh","English dictionary"},
            {"Các chuỗi phím cần ưu tiên xử lý như tiếng Việt.","Key sequences that should be treated as Vietnamese."},
            {"Thêm, sửa, xóa từ. Bộ gõ sẽ nhận diện ngay sau khi lưu.","Add, edit or remove words. Changes apply after saving."},
            {"Thêm / sửa","Add / update"},{"Xóa từ","Remove"},{"Chỉ hỗ trợ một từ a-z trên mỗi dòng.","One a-z word per line."},
            {"Lưu","Save"},{"Bạn có thay đổi chưa lưu. Đóng mà không lưu?","You have unsaved changes. Close without saving?"},
            {"Không đọc được từ điển: ","Could not read dictionary: "},
            {"Dữ liệu chưa hợp lệ","Invalid data"},{"Gõ tắt phải phân cách bằng Tab.","Separate each shortcut and replacement with a Tab."},
            {"Phím tắt hoặc nội dung không hợp lệ.","Invalid shortcut or replacement."},
            {"Tối đa 256 gõ tắt.","A maximum of 256 snippets is allowed."},
            {"Profile phải có tên ứng dụng, Tab, chế độ.","Each profile needs an app name, Tab, and mode."},
            {"Profile chỉ nhận English/Vietnamese/Balanced.","Profile mode must be English, Vietnamese or Balanced."},
            {"Tên ứng dụng không hợp lệ.","Invalid application name."},{"Tối đa 200 ứng dụng.","A maximum of 200 app profiles is allowed."},
        };
        internal static bool IsEnglish {get {return UserPreferences.String("UILanguage","vi")=="en";}}
        internal static string T(string value) {
            if(!IsEnglish || value==null)return value;
            string translated;
            return English.TryGetValue(value,out translated)?translated:value;
        }
    }

    internal static class UiPalette
    {
        internal static bool Dark {get{return UserPreferences.Bool("DarkTheme",false);}}
        internal static Color Page {get{return Dark?Color.FromArgb(15,25,40):Color.FromArgb(246,249,252);}}
        internal static Color Card {get{return Dark?Color.FromArgb(25,39,57):Color.White;}}
        internal static Color Field {get{return Dark?Color.FromArgb(31,47,66):Color.FromArgb(241,246,250);}}
        internal static Color Ink {get{return Dark?Color.FromArgb(235,244,250):Color.FromArgb(24,43,62);}}
        internal static Color Muted {get{return Dark?Color.FromArgb(155,177,195):Color.FromArgb(105,125,145);}}
        internal static Color Accent {get{return Dark?Color.FromArgb(57,221,194):Color.FromArgb(0,145,137);}}
        internal static Color Border {get{return Dark?Color.FromArgb(48,68,88):Color.FromArgb(222,231,239);}}
        internal static Color Sidebar {get{return Color.FromArgb(13,31,48);}}

        internal static void Apply(Form form)
        {
            form.Icon=AppIcons.Brand;
            form.Font=new Font("Segoe UI",9.5f);
            form.BackColor=Page;form.ForeColor=Ink;
            form.AutoScaleMode=AutoScaleMode.Dpi;
            foreach(Control child in form.Controls) ApplyChild(child,false);
        }
        static void ApplyChild(Control child,bool nested)
        {
            var label=child as Label;
            if(label!=null) {
                bool heading=label.Font.Size>=15f;
                bool accent=label.ForeColor==Color.FromArgb(81,229,183) ||
                    label.ForeColor==Color.FromArgb(18,147,133) ||
                    label.ForeColor==Color.FromArgb(49,188,153);
                label.ForeColor=accent?Accent:(heading?Ink:(label.Font.Size<9.2f?Muted:Ink));
                label.BackColor=Color.Transparent;
            }
            var text=child as TextBox;
            if(text!=null){text.BackColor=Field;text.ForeColor=Ink;text.BorderStyle=BorderStyle.FixedSingle;}
            var list=child as ListBox;
            if(list!=null){list.BackColor=Field;list.ForeColor=Ink;border(list);}
            var combo=child as ComboBox;
            if(combo!=null){combo.BackColor=Field;combo.ForeColor=Ink;combo.FlatStyle=FlatStyle.Flat;}
            var check=child as CheckBox;
            if(check!=null){check.BackColor=Color.Transparent;check.ForeColor=Ink;}
            var button=child as Button;
            if(button!=null){
                button.BackColor=Card;button.ForeColor=Ink;button.FlatStyle=FlatStyle.Flat;
                button.FlatAppearance.BorderColor=Border;button.FlatAppearance.BorderSize=1;
                button.FlatAppearance.MouseOverBackColor=Field;
                button.Font=new Font("Segoe UI Semibold",9.2f,FontStyle.Bold);
                button.Cursor=Cursors.Hand;
            }
            var panel=child as Panel;
            if(panel!=null) {
                if(panel is TableLayoutPanel || panel is FlowLayoutPanel) panel.BackColor=Page;
                foreach(Control nestedChild in panel.Controls) ApplyChild(nestedChild,true);
            }
        }
        static void border(ListBox list) { }
    }
}
