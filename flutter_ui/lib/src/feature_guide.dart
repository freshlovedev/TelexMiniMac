import 'package:flutter/material.dart';

import 'controller.dart';

/// Small, concrete instructions for every action in the shared desktop UI.
/// Keep the examples accurate: they describe the expected result when the
/// associated feature is enabled, rather than claiming every app is supported.
class GuideExample {
  const GuideExample({
    required this.titleVi,
    required this.titleEn,
    required this.stepsVi,
    required this.stepsEn,
    required this.before,
    required this.after,
    required this.whyVi,
    required this.whyEn,
  });

  final String titleVi;
  final String titleEn;
  final String stepsVi;
  final String stepsEn;
  final String before;
  final String after;
  final String whyVi;
  final String whyEn;

  String title(AppController c) => c.t(titleVi, titleEn);
  String steps(AppController c) => c.t(stepsVi, stepsEn);
  String why(AppController c) => c.t(whyVi, whyEn);
}

class FeatureGuideCatalog {
  static const _overview = <GuideExample>[
    GuideExample(
      titleVi: 'Chọn chế độ ưu tiên',
      titleEn: 'Choose language priority',
      stepsVi: 'Trong Tổng quan chọn Balanced / Ưu tiên Việt / Ưu tiên Anh. Mở Typing Lab để thử ba bộ ví dụ.',
      stepsEn: 'Select Balanced / Vietnamese first / English first on Overview; try examples in Typing Lab.',
      before: 'boost (Balanced)',
      after: 'boost; ưu tiên Việt → bốt',
      whyVi:
          'Áp dụng cho chế độ V và lưu chung với Cài đặt; E vẫn gõ nguyên văn.',
      whyEn: 'Applies to V mode across the app; E remains literal.',
    ),
    GuideExample(
      titleVi: 'Đổi V / E',
      titleEn: 'Switch V / E',
      stepsVi: 'Nhấn V hoặc E trong bảng Tổng quan hay biểu tượng khay hệ thống; cũng có thể dùng phím tắt trong Cài đặt.',
      stepsEn: 'Select V or E on Overview or in the tray, or use the configured shortcut.',
      before: 'V: tieengs',
      after: 'tiếng',
      whyVi: 'V xử lý Telex/VNI; E giữ nguyên ký tự để gõ tiếng Anh.',
      whyEn: 'V composes Vietnamese; E leaves English input unchanged.',
    ),
    GuideExample(
      titleVi: 'Chọn Telex / VNI',
      titleEn: 'Choose Telex / VNI',
      stepsVi:
          'Nhấn nút Kiểu gõ, chọn Telex hoặc VNI rồi thử trong ô Thử gõ ngay.',
      stepsEn:
          'Open Input method, choose Telex or VNI, and try the typing field.',
      before: 'Telex: ddang',
      after: 'đang',
      whyVi: 'Hai kiểu gõ có quy tắc dấu khác nhau. Ví dụ đang dùng Telex.',
      whyEn:
          'The two methods use different keystrokes; this example uses Telex.',
    ),
    GuideExample(
      titleVi: 'Bảo vệ tiếng Anh',
      titleEn: 'Protect English words',
      stepsVi: 'Bật Bảo vệ từ tiếng Anh rồi gõ một thuật ngữ vào ô thử.',
      stepsEn: 'Enable Protect English words, then type a technical term.',
      before: 'boost',
      after: 'boost',
      whyVi: 'Từ tiếng Anh đã nhận diện được giữ nguyên khi chế độ V đang bật.',
      whyEn: 'Recognized English words stay intact even in V mode.',
    ),
    GuideExample(
      titleVi: 'Khôi phục từ không hợp lệ',
      titleEn: 'Restore invalid words',
      stepsVi:
          'Bật Khôi phục từ không hợp lệ ở Tổng quan và gõ một từ tiếng Anh.',
      stepsEn:
          'Enable Restore invalid words on Overview and type an English word.',
      before: 'parameter',
      after: 'parameter',
      whyVi: 'Hạn chế dấu không mong muốn trong các từ không phải tiếng Việt.',
      whyEn: 'Reduces unwanted marks on non-Vietnamese input.',
    ),
    GuideExample(
      titleVi: 'Bảo vệ terminal',
      titleEn: 'Protect terminal input',
      stepsVi:
          'Bật Tự dùng English trong terminal, rồi thử một lệnh ở terminal.',
      stepsEn: 'Turn on English in terminal, then type a shell command.',
      before: 'git status',
      after: 'git status',
      whyVi: 'Lệnh và mã nguồn không nên bị bộ gõ thêm dấu.',
      whyEn: 'Commands and code should remain unchanged.',
    ),
    GuideExample(
      titleVi: 'Mở công cụ phụ',
      titleEn: 'Open a tool',
      stepsVi:
          'Nhấn biểu tượng mở danh sách tại Gõ tắt, Từ điển hoặc Ký tự nhanh.',
      stepsEn: 'Click the list shortcut on Snippets, Dictionary, or Symbols.',
      before: 'Tổng quan → Gõ tắt',
      after: 'Danh sách gõ tắt',
      whyVi: 'Tất cả công cụ nằm trong cùng một cửa sổ quản lý.',
      whyEn: 'All tools live inside the same settings window.',
    ),
  ];

  static const _english = <GuideExample>[
    GuideExample(
      titleVi: 'Thêm từ tiếng Anh',
      titleEn: 'Add an English word',
      stepsVi: 'Nhấn Thêm từ, nhập boost (a-z), rồi nhấn Thêm.',
      stepsEn: 'Select Add word, enter boost (a-z), and confirm.',
      before: 'boost',
      after: 'boost',
      whyVi: 'Từ được thêm vào danh sách bảo vệ khỏi chuyển đổi tiếng Việt.',
      whyEn: 'The word is added to the English-protection list.',
    ),
    GuideExample(
      titleVi: 'Thêm nhanh từ gợi ý',
      titleEn: 'Use a suggested word',
      stepsVi: 'Nhấn thẻ parameter có dấu + để thêm trực tiếp.',
      stepsEn: 'Click the parameter suggestion chip to add it.',
      before: 'parameter',
      after: 'parameter',
      whyVi: 'Không cần gõ lại từ gợi ý; từ được lưu vào danh sách.',
      whyEn: 'Suggestions can be added without retyping.',
    ),
    GuideExample(
      titleVi: 'Tìm từ đã thêm',
      titleEn: 'Search saved words',
      stepsVi: 'Nhập boost vào ô Tìm từ để lọc danh sách.',
      stepsEn: 'Type boost into Search words to filter the list.',
      before: 'Tìm: boo',
      after: 'boost',
      whyVi: 'Chỉ những từ khớp với nội dung tìm kiếm được hiển thị.',
      whyEn: 'Only matching words remain visible.',
    ),
    GuideExample(
      titleVi: 'Xóa từ',
      titleEn: 'Remove a word',
      stepsVi: 'Nhấn biểu tượng thùng rác ở hàng boost.',
      stepsEn: 'Click the trash icon next to boost.',
      before: 'boost (đã thêm)',
      after: 'boost (đã xóa)',
      whyVi: 'Từ không còn thuộc danh sách ngoại lệ tiếng Anh cá nhân.',
      whyEn: 'The word is removed from the personal English exception list.',
    ),
  ];

  static const _vietnamese = <GuideExample>[
    GuideExample(
      titleVi: 'Ưu tiên từ tiếng Việt',
      titleEn: 'Prioritize Vietnamese',
      stepsVi: 'Nhấn Thêm từ, nhập been (dạng phím Telex) rồi xác nhận.',
      stepsEn: 'Click Add word, enter been (Telex keystrokes), and confirm.',
      before: 'been',
      after: 'bên',
      whyVi:
          'Giúp ưu tiên cách hiểu tiếng Việt ở những từ dễ lẫn với tiếng Anh.',
      whyEn: 'Prioritizes Vietnamese on ambiguous keystroke sequences.',
    ),
    GuideExample(
      titleVi: 'Dùng từ gợi ý',
      titleEn: 'Use suggestions',
      stepsVi: 'Nhấn thẻ boons có dấu + trong vùng Ví dụ gợi ý.',
      stepsEn: 'Click the boons suggestion chip.',
      before: 'boons',
      after: 'bốn',
      whyVi: 'Các ngoại lệ thêm vào có thể chỉnh lại bằng nút xóa và thêm mới.',
      whyEn: 'You can remove and re-add personalized exceptions.',
    ),
    GuideExample(
      titleVi: 'Tìm và xóa ngoại lệ',
      titleEn: 'Find and remove an exception',
      stepsVi: 'Tìm been rồi nhấn biểu tượng xóa ở hàng tương ứng.',
      stepsEn: 'Search been, then click the matching row’s delete icon.',
      before: 'been (ưu tiên)',
      after: 'been (không còn ưu tiên riêng)',
      whyVi: 'Trả cách xử lý về những quy tắc mặc định của bộ gõ.',
      whyEn: 'Returns the word to normal input-engine rules.',
    ),
  ];

  static const _snippets = <GuideExample>[
    GuideExample(
      titleVi: 'Bật chức năng gõ tắt',
      titleEn: 'Enable snippets',
      stepsVi: 'Bật Mở rộng gõ tắt, sau đó tạo một mục bằng nút Thêm gõ tắt.',
      stepsEn:
          'Enable snippet expansion, then create an entry with Add snippet.',
      before: 'dc + Space',
      after: 'Địa chỉ: ',
      whyVi: 'Gõ tắt cần được bật để áp dụng trong ô nhập hỗ trợ.',
      whyEn: 'Expansion must be enabled and the text field must support it.',
    ),
    GuideExample(
      titleVi: 'Tạo gõ tắt mới',
      titleEn: 'Create a snippet',
      stepsVi:
          'Nhấn Thêm gõ tắt → Phím tắt: sdt → Nội dung: Số điện thoại: → Lưu.',
      stepsEn: 'Choose Add snippet → Shortcut: sdt → Expansion: Phone: → Save.',
      before: 'sdt + Space',
      after: 'Số điện thoại: ',
      whyVi: 'Đoạn văn bản dài được thay thế bằng vài phím ngắn.',
      whyEn: 'A short trigger expands to the saved text.',
    ),
    GuideExample(
      titleVi: 'Chỉnh sửa gõ tắt',
      titleEn: 'Edit a snippet',
      stepsVi: 'Nhấn biểu tượng bút chì bên cạnh sdt, đổi nội dung rồi Lưu.',
      stepsEn: 'Click the pencil beside sdt, change its expansion, and Save.',
      before: 'sdt → Số điện thoại:',
      after: 'sdt → Điện thoại:',
      whyVi: 'Danh sách cập nhật ngay khi lưu.',
      whyEn: 'The saved row updates immediately.',
    ),
    GuideExample(
      titleVi: 'Xóa gõ tắt',
      titleEn: 'Delete a snippet',
      stepsVi: 'Nhấn biểu tượng thùng rác ở hàng sdt.',
      stepsEn: 'Click the trash button on the sdt row.',
      before: 'sdt (đã lưu)',
      after: 'sdt (đã xóa)',
      whyVi: 'Phím tắt đã xóa sẽ không còn mở rộng nội dung đó.',
      whyEn: 'Deleted triggers no longer expand that entry.',
    ),
    GuideExample(
      titleVi: 'Thêm ví dụ một chạm',
      titleEn: 'Add a ready example',
      stepsVi: 'Nhấn thẻ dc → Địa chỉ: ở cuối màn hình để thêm mục mẫu.',
      stepsEn: 'Click the dc → Address: sample chip near the bottom.',
      before: 'dc',
      after: 'Địa chỉ:',
      whyVi: 'Ví dụ được đưa vào danh sách và có thể sửa theo nhu cầu.',
      whyEn: 'The example is saved as an editable entry.',
    ),
    GuideExample(
      titleVi: 'Biến ngày giờ',
      titleEn: 'Date/time macros',
      stepsVi: 'Tạo mục hn với nội dung Hôm nay: {date}; lưu và gõ hn + Space.',
      stepsEn: 'Create hn with Today: {date}; save, then type hn + Space.',
      before: 'hn + Space',
      after: 'Hôm nay: [ngày hiện tại]',
      whyVi: 'Biến {date}, {time}, {datetime} lấy thời gian tại lúc mở rộng.',
      whyEn: 'Date/time macros resolve when the snippet expands.',
    ),
    GuideExample(
      titleVi: 'Hoàn tác mở rộng',
      titleEn: 'Smart Undo',
      stepsVi: 'Sau khi gõ dc + Space, nhấn Backspace ngay trong ô nhập được hỗ trợ.',
      stepsEn: 'After dc + Space expands, press Backspace immediately in a supported field.',
      before: 'Địa chỉ: ',
      after: 'dc',
      whyVi: 'Giúp lấy lại phím tắt khi vô tình mở rộng; không phải ứng dụng nào cũng hỗ trợ.',
      whyEn:
          'Restores an accidental expansion where the target app supports it.',
    ),
    GuideExample(
      titleVi: 'Lọc danh sách',
      titleEn: 'Filter shortcuts',
      stepsVi: 'Nhập sdt vào ô tìm kiếm; nhấn X để xóa bộ lọc.',
      stepsEn: 'Type sdt in Search, then clear the field to reset the filter.',
      before: 'Danh sách nhiều mục',
      after: 'Chỉ những mục khớp sdt',
      whyVi: 'Tìm theo cả phím tắt lẫn nội dung thay thế.',
      whyEn: 'Search matches triggers and expansions.',
    ),
  ];

  static const _symbols = <GuideExample>[
    GuideExample(
      titleVi: 'Chọn nhóm ký tự',
      titleEn: 'Choose a category',
      stepsVi: 'Bấm Toán học để hiển thị các ký hiệu toán.',
      stepsEn: 'Click Mathematics to show math symbols.',
      before: 'Phổ biến',
      after: '±   ∞   ≠   ≤   ≥',
      whyVi: 'Đổi nhóm để tìm ký tự nhanh hơn.',
      whyEn: 'Switch categories to find symbols faster.',
    ),
    GuideExample(
      titleVi: 'Sao chép ký tự',
      titleEn: 'Copy a symbol',
      stepsVi:
          'Nhấn ký tự ✓ trong danh sách, chuyển sang tài liệu rồi nhấn Ctrl+V.',
      stepsEn: 'Click ✓, switch to a document, then press Ctrl+V.',
      before: 'Nhấn ✓',
      after: 'Ctrl+V → ✓',
      whyVi: 'Ký tự được sao chép vào clipboard khi bạn chủ động bấm.',
      whyEn: 'The symbol is copied only when you click it.',
    ),
  ];

  static const _applications = <GuideExample>[
    GuideExample(
      titleVi: 'Chọn tệp ứng dụng',
      titleEn: 'Choose an application',
      stepsVi: 'Nhấn Chọn EXE, chọn ứng dụng .exe hợp lệ rồi xác nhận.',
      stepsEn: 'Click Choose EXE, select a valid application executable, and confirm.',
      before: 'notepad.exe',
      after: 'notepad.exe trong danh sách',
      whyVi: 'Không cần nhớ tên process nếu đã có tệp chương trình.',
      whyEn: 'Select a program file instead of remembering its process name.',
    ),
    GuideExample(
      titleVi: 'Thêm process thủ công',
      titleEn: 'Add a process manually',
      stepsVi: 'Nhấn Thêm ứng dụng, nhập notepad.exe rồi nhấn Lưu.',
      stepsEn: 'Click Add application, enter notepad.exe, and Save.',
      before: 'notepad.exe',
      after: 'Đã thêm vào danh sách',
      whyVi: 'Danh sách quản lý ứng dụng được lưu cục bộ.',
      whyEn: 'The managed-app list is stored locally.',
    ),
    GuideExample(
      titleVi: 'Bỏ qua bộ gõ',
      titleEn: 'Exclude an application',
      stepsVi: 'Đánh dấu Bỏ qua ở hàng notepad.exe nếu không muốn bộ gõ tác động trong ứng dụng đó.',
      stepsEn:
          'Check Ignore beside notepad.exe to avoid transforming its input.',
      before: 'notepad.exe: xử lý V/E',
      after: 'notepad.exe: bỏ qua',
      whyVi: 'Tùy chọn này áp dụng theo process đã chọn.',
      whyEn: 'The exclusion applies only to the selected process.',
    ),
    GuideExample(
      titleVi: 'Hồ sơ theo ứng dụng',
      titleEn: 'Per-app language profile',
      stepsVi: 'Bật Quy tắc riêng theo ứng dụng rồi chọn English ở hàng ứng dụng lập trình.',
      stepsEn:
          'Enable Per-application rules and choose English for a coding app.',
      before: 'Default',
      after: 'English',
      whyVi: 'Hồ sơ chỉ áp dụng khi tùy chọn hồ sơ đang bật.',
      whyEn: 'Profiles take effect only when per-app rules are enabled.',
    ),
    GuideExample(
      titleVi: 'Xem process đang chạy',
      titleEn: 'View running processes',
      stepsVi: 'Chọn Process đang chạy, nhấn Quét lại để cập nhật; dùng ô tìm nếu danh sách dài.',
      stepsEn:
          'Choose Running processes, click Refresh, and filter with Search.',
      before: 'Danh sách Đã thêm',
      after: 'Các process đang hoạt động',
      whyVi: 'Dễ chọn đúng ứng dụng đang sử dụng.',
      whyEn: 'Helps identify the current app process.',
    ),
    GuideExample(
      titleVi: 'Sửa / xóa mục',
      titleEn: 'Edit or remove an entry',
      stepsVi: 'Nhấn bút chì để đổi tên process; nhấn thùng rác để bỏ mục khỏi danh sách.',
      stepsEn: 'Click the pencil to edit or the trash icon to remove an entry.',
      before: 'notepad.exe (đã lưu)',
      after: 'Mục được sửa hoặc xóa',
      whyVi: 'Không cần chỉnh sửa tệp cấu hình bên ngoài.',
      whyEn: 'Manage entries without editing configuration files.',
    ),
  ];

  static const _textTools = <GuideExample>[
    GuideExample(
      titleVi: 'Bỏ dấu tiếng Việt',
      titleEn: 'Remove Vietnamese marks',
      stepsVi: 'Nhập “Tiếng Việt”, chọn Bỏ dấu tiếng Việt, nhấn Áp dụng.',
      stepsEn:
          'Enter “Tiếng Việt”, choose Remove Vietnamese marks, then Apply.',
      before: 'Tiếng Việt',
      after: 'Tieng Viet',
      whyVi:
          'Chuyển chữ có dấu thành chữ Latin không dấu ngay trong ô soạn thảo.',
      whyEn: 'Strips Vietnamese marks from the editor text.',
    ),
    GuideExample(
      titleVi: 'Unicode NFC',
      titleEn: 'Normalize Unicode NFC',
      stepsVi:
          'Nhập chữ a + dấu sắc kết hợp, chọn Unicode NFC rồi nhấn Áp dụng.',
      stepsEn:
          'Enter a + combining acute accent, choose Unicode NFC, then Apply.',
      before: 'a + dấu kết hợp',
      after: 'á (dạng NFC)',
      whyVi:
          'Chuẩn hóa biểu diễn Unicode, không phải chức năng tự sửa chính tả.',
      whyEn: 'Normalizes Unicode representation; it does not spell-check.',
    ),
    GuideExample(
      titleVi: 'CHỮ HOA',
      titleEn: 'UPPERCASE',
      stepsVi: 'Nhập xin chào, chọn CHỮ HOA rồi nhấn Áp dụng.',
      stepsEn: 'Enter xin chào, select UPPERCASE, then Apply.',
      before: 'xin chào',
      after: 'XIN CHÀO',
      whyVi: 'Chuyển toàn bộ chữ cái sang in hoa.',
      whyEn: 'Makes the entire selection uppercase.',
    ),
    GuideExample(
      titleVi: 'chữ thường',
      titleEn: 'lowercase',
      stepsVi: 'Nhập XIN CHÀO, chọn chữ thường rồi nhấn Áp dụng.',
      stepsEn: 'Enter XIN CHÀO, select lowercase, then Apply.',
      before: 'XIN CHÀO',
      after: 'xin chào',
      whyVi: 'Chuyển toàn bộ chữ cái sang in thường.',
      whyEn: 'Converts selected text to lowercase.',
    ),
    GuideExample(
      titleVi: 'Viết Hoa Từng Từ',
      titleEn: 'Title Case',
      stepsVi: 'Nhập xin chào, chọn Viết Hoa Từng Từ rồi nhấn Áp dụng.',
      stepsEn: 'Enter xin chào, select Title Case, then Apply.',
      before: 'xin chào',
      after: 'Xin Chào',
      whyVi: 'Phù hợp tên tiêu đề ngắn.',
      whyEn: 'Useful for short headings.',
    ),
    GuideExample(
      titleVi: 'Viết hoa đầu câu',
      titleEn: 'Sentence case',
      stepsVi: 'Nhập xin. chào!, chọn Viết hoa đầu câu rồi Áp dụng.',
      stepsEn: 'Enter xin. chào!, select Sentence case, then Apply.',
      before: 'xin. chào!',
      after: 'Xin. Chào!',
      whyVi: 'Viết hoa sau các dấu kết thúc câu được hỗ trợ.',
      whyEn: 'Capitalizes at supported sentence boundaries.',
    ),
    GuideExample(
      titleVi: 'Dọn khoảng trắng',
      titleEn: 'Clean whitespace',
      stepsVi: 'Nhập “xin   chào”, chọn Dọn khoảng trắng và Áp dụng.',
      stepsEn: 'Enter “xin   chào”, choose Clean whitespace and Apply.',
      before: 'xin   chào',
      after: 'xin chào',
      whyVi: 'Rút gọn các khoảng trắng thừa.',
      whyEn: 'Removes redundant whitespace.',
    ),
    GuideExample(
      titleVi: 'Chuẩn hóa Markdown',
      titleEn: 'Normalize Markdown',
      stepsVi: 'Nhập “• điều một”, chọn Chuẩn hóa Markdown và Áp dụng.',
      stepsEn: 'Enter “• điều một”, choose Normalize Markdown, then Apply.',
      before: '• điều một',
      after: '- điều một',
      whyVi: 'Chuẩn hóa ký hiệu danh sách phổ biến.',
      whyEn: 'Normalizes supported list markers.',
    ),
    GuideExample(
      titleVi: 'Chỉ đổi phần bôi đen',
      titleEn: 'Transform selected text',
      stepsVi: 'Nhập “xin chào bạn”, bôi đen “chào”, chọn CHỮ HOA rồi Áp dụng.',
      stepsEn:
          'Enter “xin chào bạn”, select “chào”, choose UPPERCASE, then Apply.',
      before: 'xin [chào] bạn',
      after: 'xin CHÀO bạn',
      whyVi: 'Nếu không bôi đen, thao tác áp dụng cho toàn bộ ô.',
      whyEn: 'Without a selection, Apply transforms the whole field.',
    ),
    GuideExample(
      titleVi: 'Dán clipboard',
      titleEn: 'Paste clipboard',
      stepsVi: 'Sao chép đoạn văn với Ctrl+C, mở Công cụ văn bản rồi nhấn Dán clipboard.',
      stepsEn: 'Copy with Ctrl+C, open Text tools, then click Paste clipboard.',
      before: 'Clipboard: Xin chào',
      after: 'Ô soạn thảo: Xin chào',
      whyVi: 'Ứng dụng chỉ đọc clipboard khi bạn bấm nút này.',
      whyEn: 'The clipboard is read only when you explicitly click Paste.',
    ),
    GuideExample(
      titleVi: 'Sao chép kết quả',
      titleEn: 'Copy result',
      stepsVi: 'Sau khi xử lý, nhấn Sao chép kết quả rồi Ctrl+V vào tài liệu.',
      stepsEn:
          'After Apply, click Copy result and press Ctrl+V in the document.',
      before: 'Kết quả: Tieng Viet',
      after: 'Ctrl+V → Tieng Viet',
      whyVi: 'Sao chép nội dung hiện tại trong ô; không tự thay chữ ở ứng dụng khác.',
      whyEn: 'Copies the current editor content; does not edit other apps automatically.',
    ),
    GuideExample(
      titleVi: 'Xóa ô soạn thảo',
      titleEn: 'Clear editor',
      stepsVi: 'Nhấn Xóa ô để xóa nội dung thử hiện tại.',
      stepsEn: 'Click Clear to empty the current editor.',
      before: 'Xin chào',
      after: '(ô trống)',
      whyVi: 'Chỉ xóa văn bản trong ô của công cụ.',
      whyEn: 'Clears only the text-tools editor.',
    ),
  ];

  static const _typingLab = <GuideExample>[
    GuideExample(
      titleVi: 'Balanced — song ngữ',
      titleEn: 'Balanced — bilingual',
      stepsVi: 'Bật V, chọn Telex và Balanced; gõ been hoặc boost rồi nhấn Kiểm tra.',
      stepsEn: 'Enable V with Telex and Balanced; type been or boost and press Check.',
      before: 'been / boost',
      after: 'bên / boost',
      whyVi:
          'Cân bằng chuyển dấu tiếng Việt và bảo vệ từ tiếng Anh quen thuộc.',
      whyEn: 'Balances Vietnamese composition with English word protection.',
    ),
    GuideExample(
      titleVi: 'Ưu tiên Việt',
      titleEn: 'Vietnamese first',
      stepsVi: 'Bật V, chọn Ưu tiên Việt; thử boost, sau đó bấm Kiểm tra.',
      stepsEn: 'Enable V and Vietnamese first; try boost, then Check.',
      before: 'boost',
      after: 'bốt',
      whyVi: 'Ưu tiên chuyển Telex sang tiếng Việt, kể cả một số từ Anh.',
      whyEn: 'Favors Vietnamese composition, even for some English words.',
    ),
    GuideExample(
      titleVi: 'Ưu tiên Anh',
      titleEn: 'English first',
      stepsVi: 'Bật V, chọn Ưu tiên Anh; thử been hoặc now rồi Kiểm tra.',
      stepsEn: 'Enable V and English first; type been or now, then Check.',
      before: 'been / now',
      after: 'been / now',
      whyVi: 'Giữ từ Anh đã biết; những chuỗi không nhận là từ Anh vẫn có thể chuyển dấu.',
      whyEn: 'Keeps recognized English; unknown sequences may still compose.',
    ),
    GuideExample(
      titleVi: 'Kiểm tra một chuỗi Telex',
      titleEn: 'Check a Telex sequence',
      stepsVi: 'Gõ các phím hiển thị vào ô trống, nhấn Kiểm tra rồi xem Đạt/Chưa đúng.',
      stepsEn: 'Type the shown keys into the field, click Check, and inspect Pass/Fail.',
      before: 'w',
      after: 'ư',
      whyVi: 'Kiểm tra đầu ra thật trên ô nhập, không tự tạo kết quả giả.',
      whyEn: 'Tests the actual input produced in a real editable field.',
    ),
    GuideExample(
      titleVi: 'Thử lại',
      titleEn: 'Retry a case',
      stepsVi: 'Nhấn Thử lại để xóa ô hiện tại rồi gõ lại chuỗi đang kiểm tra.',
      stepsEn: 'Click Retry to clear the current case, then type again.',
      before: 'Kết quả chưa đúng',
      after: 'Ô trống để thử lại',
      whyVi: 'Không đổi sang bài kế tiếp.',
      whyEn: 'Keeps the same test case.',
    ),
    GuideExample(
      titleVi: 'Chuyển bài và xem điểm',
      titleEn: 'Next case and score',
      stepsVi: 'Nhấn Bài tiếp hoặc nhấn một thẻ tình huống; nhìn chỉ số Đạt/tổng ở đầu.',
      stepsEn: 'Click Next or a case chip; see passed/total at the top.',
      before: 'w → ư',
      after: 'now → nơ',
      whyVi: 'Mỗi tình huống đo một quy tắc khác nhau; không ghi lịch sử gõ.',
      whyEn: 'Each case checks a different rule; typing history is not stored.',
    ),
  ];

  static const _diagnostics = <GuideExample>[
    GuideExample(
      titleVi: 'Chạy chẩn đoán',
      titleEn: 'Run diagnostics',
      stepsVi: 'Nhấn Kiểm tra tại Input Diagnostics rồi xem trạng thái Native bridge.',
      stepsEn: 'Click Run diagnostics, then inspect Native bridge status.',
      before: 'Chưa kiểm tra',
      after: 'Connected hoặc Disconnected',
      whyVi: 'Chỉ đo trạng thái và độ trễ nội bộ; không đo thời gian từ phím tới màn hình.',
      whyEn:
          'Reports internal connectivity/timing, not end-to-end key latency.',
    ),
    GuideExample(
      titleVi: 'Đọc thông số p95 / p99',
      titleEn: 'Read p95 / p99',
      stepsVi:
          'Sau khi kiểm tra, xem Hook p95/p99 để hiểu mức thời gian callback.',
      stepsEn: 'After diagnostics, inspect Hook p95/p99 callback timing.',
      before: 'Hook p95: —',
      after: 'Hook p95: [số ms đo được]',
      whyVi:
          'Số càng nhỏ càng tốt, nhưng không đại diện toàn bộ độ trễ hiển thị.',
      whyEn: 'Lower is better, but this is not total key-to-screen time.',
    ),
    GuideExample(
      titleVi: 'Tạo bản sao lưu',
      titleEn: 'Create a backup',
      stepsVi: 'Nhấn Tạo bản sao lưu, sau đó xem bản mới trong danh sách.',
      stepsEn: 'Click Create backup, then locate the new file in the list.',
      before: 'Cấu hình hiện tại',
      after: 'Tệp JSON sao lưu cục bộ',
      whyVi: 'Có thể chứa nội dung gõ tắt; hãy giữ tệp sao lưu riêng tư.',
      whyEn: 'May contain snippets; keep backup files private.',
    ),
    GuideExample(
      titleVi: 'Khôi phục bản đã chọn',
      titleEn: 'Restore a backup',
      stepsVi: 'Chọn một bản trong danh sách, nhấn Khôi phục bản đã chọn rồi xác nhận.',
      stepsEn: 'Select a backup, click Restore selected, and confirm.',
      before: 'Cấu hình hiện tại',
      after: 'Cấu hình của bản sao lưu',
      whyVi: 'Thao tác có thể ghi đè tùy chỉnh hiện tại; cần xác nhận trước.',
      whyEn: 'Can replace current preferences; confirmation is required.',
    ),
    GuideExample(
      titleVi: 'Xóa bản sao lưu',
      titleEn: 'Delete a backup',
      stepsVi: 'Chọn bản cần xóa, nhấn Xóa bản đã chọn rồi xác nhận.',
      stepsEn: 'Select a backup, click Delete selected, and confirm.',
      before: 'Bản sao lưu cũ',
      after: 'Đã xóa khỏi danh sách',
      whyVi: 'Chỉ xóa tệp sao lưu được chọn, không xóa bộ gõ.',
      whyEn: 'Deletes only the selected backup file.',
    ),
    GuideExample(
      titleVi: 'Kiểm tra cập nhật',
      titleEn: 'Check for updates',
      stepsVi: 'Nhấn Kiểm tra bản mới hoặc Xem bản phát hành để mở thông tin trên trình duyệt.',
      stepsEn:
          'Choose Check for updates or View releases to open release details.',
      before: 'Bản đang dùng',
      after: 'Thông tin bản mới nếu có',
      whyVi: 'Kiểm tra theo yêu cầu, không tự cài gói tải về.',
      whyEn: 'On-demand check; downloaded packages are never auto-installed.',
    ),
  ];

  static const _settings = <GuideExample>[
    GuideExample(
      titleVi: 'Kiểu gõ Telex / VNI',
      titleEn: 'Telex / VNI input',
      stepsVi: 'Mở danh sách Kiểu gõ, chọn Telex hoặc VNI; thay đổi được lưu.',
      stepsEn: 'Open Input method, choose Telex or VNI; the choice is saved.',
      before: 'Telex: ddang',
      after: 'đang',
      whyVi: 'Chọn kiểu gõ quen thuộc; ví dụ minh họa đang dùng Telex.',
      whyEn: 'Choose the input scheme you know; example uses Telex.',
    ),
    GuideExample(
      titleVi: 'Ưu tiên ngôn ngữ',
      titleEn: 'Language priority',
      stepsVi: 'Chọn Balanced để dùng song ngữ, Vietnamese để thiên về tiếng Việt, English để thiên về tiếng Anh.',
      stepsEn: 'Choose Balanced, Vietnamese, or English according to the input you use.',
      before: 'Balanced: been',
      after: 'bên (khi ưu tiên tiếng Việt)',
      whyVi: 'Mức ưu tiên ảnh hưởng cách giải quyết các từ có thể hiểu theo hai ngôn ngữ.',
      whyEn: 'Priority influences ambiguous bilingual sequences.',
    ),
    GuideExample(
      titleVi: 'Phím chuyển V/E',
      titleEn: 'V/E shortcut',
      stepsVi: 'Chọn phím tắt như Ctrl + Shift + Space, rồi bấm tổ hợp khi đang nhập.',
      stepsEn: 'Choose a shortcut such as Ctrl + Shift + Space and press it while typing.',
      before: 'V',
      after: 'E (nhấn phím tắt)',
      whyVi: 'Chuyển chế độ gõ mà không phải mở bảng Cài đặt.',
      whyEn: 'Switches input mode without opening Settings.',
    ),
    GuideExample(
      titleVi: 'Bảo vệ tiếng Anh',
      titleEn: 'Protect English',
      stepsVi: 'Bật Bảo vệ từ tiếng Anh, sau đó gõ boost.',
      stepsEn: 'Turn on Protect English words, then type boost.',
      before: 'boost',
      after: 'boost',
      whyVi: 'Giảm nguy cơ chuyển nhầm thuật ngữ tiếng Anh.',
      whyEn: 'Reduces accidental transformations of English vocabulary.',
    ),
    GuideExample(
      titleVi: 'Khôi phục từ không hợp lệ',
      titleEn: 'Restore invalid input',
      stepsVi: 'Bật Khôi phục từ không hợp lệ nếu thường gõ lẫn thuật ngữ.',
      stepsEn: 'Enable Restore invalid words when typing mixed-language terms.',
      before: 'parameter',
      after: 'parameter',
      whyVi: 'Hạn chế dấu không hợp lệ khi nhận diện từ.',
      whyEn: 'Removes invalid transformations when possible.',
    ),
    GuideExample(
      titleVi: 'Sửa nhanh từ',
      titleEn: 'Instant Word Repair',
      stepsVi: 'Bật tính năng, gõ xong một từ và dấu cách rồi nhấn Ctrl+Alt+Backspace.',
      stepsEn: 'Enable the feature; after a word and space press Ctrl+Alt+Backspace.',
      before: 'Từ vừa hoàn tất',
      after: 'Chọn lại cách xử lý từ',
      whyVi: 'Dùng ngay khi từ vừa gõ có kết quả không mong muốn, ở ô nhập được hỗ trợ.',
      whyEn: 'Helps correct the just-completed word in supported fields.',
    ),
    GuideExample(
      titleVi: 'Từ điển tự học',
      titleEn: 'Adaptive Dictionary',
      stepsVi: 'Bật Từ điển tự học; khi chủ động sửa từ, bộ gõ mới xem xét ghi nhận.',
      stepsEn: 'Enable Adaptive Dictionary; learning is tied to explicit corrections.',
      before: 'Từ bị nhầm',
      after: 'Ưu tiên hơn sau khi sửa có xác nhận',
      whyVi: 'Không âm thầm ghi lại toàn bộ nội dung bạn gõ.',
      whyEn: 'It does not silently store everything you type.',
    ),
    GuideExample(
      titleVi: 'Dấu câu thông minh',
      titleEn: 'Smart Punctuation',
      stepsVi:
          'Bật Dấu câu thông minh rồi thử gõ câu có dấu chấm và khoảng trắng.',
      stepsEn: 'Enable Smart Punctuation and test a sentence boundary.',
      before: 'xin chào.  tôi',
      after: 'Xin chào. Tôi',
      whyVi: 'Tùy xử lý theo ngữ cảnh và khả năng tương thích của ô nhập.',
      whyEn: 'Behavior depends on context and supported fields.',
    ),
    GuideExample(
      titleVi: 'Giữ English trong terminal',
      titleEn: 'Keep English in terminals',
      stepsVi:
          'Bật Tự dùng English trong terminal để tránh đổi lệnh khi gõ mã.',
      stepsEn:
          'Enable English in terminal to protect commands and source code.',
      before: 'git status',
      after: 'git status',
      whyVi: 'Giảm chuyển đổi chữ không mong muốn trong terminal.',
      whyEn: 'Reduces unwanted transformation of commands.',
    ),
    GuideExample(
      titleVi: 'Khởi động cùng Windows',
      titleEn: 'Launch at sign-in',
      stepsVi: 'Bật Khởi động cùng hệ thống, nhấn Lưu thay đổi; đăng nhập lại để kiểm tra.',
      stepsEn: 'Enable Launch at login, Save, then sign in again to verify.',
      before: 'Windows đăng nhập',
      after: 'TelexMini tự khởi động (nếu bật)',
      whyVi: 'Tùy chọn hoạt động theo cơ chế khởi động của Windows.',
      whyEn: 'Uses the Windows sign-in startup mechanism.',
    ),
    GuideExample(
      titleVi: 'Hồ sơ ứng dụng',
      titleEn: 'Per-app profiles',
      stepsVi: 'Bật Hồ sơ theo ứng dụng, nhấn Mở quản lý và đặt English cho ứng dụng cần.',
      stepsEn: 'Enable Per-app profiles, open the manager, and set an app to English.',
      before: 'Process: Default',
      after: 'Process: English',
      whyVi: 'Từng ứng dụng có thể dùng cách gõ riêng.',
      whyEn: 'Different programs can use different input policies.',
    ),
    GuideExample(
      titleVi: 'Ngôn ngữ giao diện',
      titleEn: 'Interface language',
      stepsVi:
          'Chọn Tiếng Việt hoặc English từ danh sách rồi xem nhãn đổi theo.',
      stepsEn: 'Choose Tiếng Việt or English and watch UI labels update.',
      before: 'Cài đặt',
      after: 'Settings',
      whyVi: 'Chỉ đổi ngôn ngữ menu, không tự đổi chế độ gõ V/E.',
      whyEn: 'Changes the interface language, not typing mode.',
    ),
    GuideExample(
      titleVi: 'Lưu thay đổi',
      titleEn: 'Save changes',
      stepsVi: 'Sau khi chỉnh tùy chọn, nhấn Lưu thay đổi để ghi cấu hình.',
      stepsEn: 'After changing preferences, click Save changes.',
      before: 'Tùy chọn vừa sửa',
      after: 'Cấu hình đã lưu',
      whyVi: 'Các nút gạt cũng tự lưu; nút này giúp chủ động xác nhận lại.',
      whyEn: 'Switches also save automatically; this button explicitly saves again.',
    ),
  ];

  static const _about = <GuideExample>[
    GuideExample(
      titleVi: 'Tìm hiểu mục tiêu TelexMini',
      titleEn: 'Discover TelexMini',
      stepsVi:
          'Đọc câu chuyện, lý do tạo ứng dụng và các lợi ích ngay bên dưới.',
      stepsEn: 'Read the story, motivation, and practical benefits below.',
      before: 'Nhiều lần sửa chữ khi gõ song ngữ',
      after: 'Một bộ gõ hướng đến sự đơn giản',
      whyVi: 'Trải nghiệm cá nhân của tác giả, không phải đánh giá tất cả bộ gõ khác.',
      whyEn:
          'The author’s experience, not a claim about every other input app.',
    ),
    GuideExample(
      titleVi: 'Ủng hộ tác giả',
      titleEn: 'Support the creator',
      stepsVi: 'Nhấn Truy cập ygometa.me để mở trang web trong trình duyệt mặc định.',
      stepsEn:
          'Click Visit ygometa.me to open the website in your default browser.',
      before: 'Trang About',
      after: 'https://ygometa.me',
      whyVi: 'Ủng hộ hoàn toàn tự nguyện; ứng dụng vẫn dùng được nếu không truy cập.',
      whyEn: 'Support is optional; the app works without opening the website.',
    ),
  ];

  static List<GuideExample> forPage(AppPage page) => switch (page) {
    AppPage.overview => _overview,
    AppPage.englishDictionary => _english,
    AppPage.vietnamesePriority => _vietnamese,
    AppPage.snippets => _snippets,
    AppPage.symbols => _symbols,
    AppPage.applications => _applications,
    AppPage.textTools => _textTools,
    AppPage.typingLab => _typingLab,
    AppPage.diagnostics => _diagnostics,
    AppPage.settings => _settings,
    AppPage.about => _about,
  };
}

/// In-page, not a separate popup. Show a real example even when collapsed,
/// and allow detailed guidance without leaving the current task.
class FeatureGuide extends StatefulWidget {
  const FeatureGuide({super.key, required this.controller, required this.page});
  final AppController controller;
  final AppPage page;

  @override
  State<FeatureGuide> createState() => _FeatureGuideState();
}

class _FeatureGuideState extends State<FeatureGuide> {
  bool expanded = false;
  int selected = 0;

  IconData _sectionIcon() => switch (widget.page) {
    AppPage.overview => Icons.home_outlined,
    AppPage.englishDictionary => Icons.menu_book_rounded,
    AppPage.vietnamesePriority => Icons.translate_rounded,
    AppPage.snippets => Icons.layers_outlined,
    AppPage.symbols => Icons.functions_rounded,
    AppPage.applications => Icons.grid_view_rounded,
    AppPage.textTools => Icons.auto_fix_high_rounded,
    AppPage.typingLab => Icons.keyboard_rounded,
    AppPage.diagnostics => Icons.bug_report_rounded,
    AppPage.settings => Icons.settings_rounded,
    AppPage.about => Icons.info_rounded,
  };

  IconData _exampleIcon(int index) {
    const choices = [
      Icons.touch_app_rounded,
      Icons.edit_note_rounded,
      Icons.check_circle_outline_rounded,
      Icons.tune_rounded,
      Icons.keyboard_alt_outlined,
      Icons.copy_all_rounded,
      Icons.help_outline_rounded,
    ];
    return choices[index % choices.length];
  }

  @override
  void didUpdateWidget(FeatureGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      expanded = false;
      selected = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final cases = FeatureGuideCatalog.forPage(widget.page);
    final current = cases[selected.clamp(0, cases.length - 1)];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? const Color(0xFF35556A) : const Color(0xFFCBE7E3);
    final foreground = dark ? const Color(0xFFCDEBE8) : const Color(0xFF176761);
    final surface = dark ? const Color(0xFF183340) : const Color(0xFFECF8F6);
    return Container(
      key: Key('page-guide-${widget.page.name}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('page-guide-toggle'),
            borderRadius: BorderRadius.circular(9),
            onTap: () => setState(() => expanded = !expanded),
            child: Row(
              children: [
                Container(
                  key: const Key('page-guide-icon'),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: foreground,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_sectionIcon(), size: 19, color: surface),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    c.t('Ví dụ & cách sử dụng', 'Examples & how to use'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                ),
                Text(
                  c.t(
                    'Xem ${cases.length} hướng dẫn',
                    'View ${cases.length} guides',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: foreground,
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          if (!expanded) ...[
            Row(
              children: [
                Icon(_exampleIcon(selected), size: 16, color: foreground),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${current.title(c)}: ${current.before}  →  ${current.after}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              current.steps(c),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            SizedBox(
              height: 72,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < cases.length; i++)
                      ChoiceChip(
                        key: Key('guide-choice-${widget.page.name}-$i'),
                        avatar: Icon(
                          _exampleIcon(i),
                          size: 15,
                          color: foreground,
                        ),
                        label: Text(
                          cases[i].title(c),
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        selected: i == selected,
                        visualDensity: VisualDensity.compact,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => selected = i),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(_exampleIcon(selected), size: 17, color: foreground),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    current.title(c),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${c.t('1. Thao tác', '1. Steps')}: ${current.steps(c)}',
              style: const TextStyle(fontSize: 11.5),
            ),
            const SizedBox(height: 4),
            Text(
              '${c.t('2. Ví dụ', '2. Example')}: ${current.before}  →  ${current.after}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${c.t('3. Giải thích', '3. Why')}: ${current.why(c)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
