import 'dart:io';

import 'package:flutter/material.dart';
import 'controller.dart';
import 'widgets.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => PageFrame(
    controller: controller,
    title: controller.t('Gõ theo cách của bạn.', 'Type your way.'),
    subtitle: controller.t('Hai ngôn ngữ. Một trải nghiệm liền mạch.',
      'Two languages. One seamless experience.'),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _HeroMode(controller: controller),
            const SizedBox(height: 13),
            SectionTitle(controller.t('TÙY CHỈNH TRẢI NGHIỆM',
              'PERSONALIZE YOUR EXPERIENCE')),
            LayoutBuilder(builder: (context, box) {
              final first = SurfaceCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeading(
                    icon: Icons.spellcheck_rounded,
                    label: controller.t('NHẬN DIỆN NGÔN NGỮ','LANGUAGE RECOGNITION'),
                  ),
                  const SizedBox(height: 7),
                  PreferenceSwitch(
                    title: controller.t('Bảo vệ từ tiếng Anh','Protect English words'),
                    subtitle: controller.t('Từ điển offline, nhận diện ngay khi gõ',
                      'Offline dictionary, real-time recognition'),
                    value: controller.smartEnglish,
                    onChanged: (v) { controller.smartEnglish = v; controller.save(); },
                  ),
                  const Divider(height: 9),
                  PreferenceSwitch(
                    title: controller.t('Khôi phục từ không hợp lệ','Restore invalid words'),
                    subtitle: controller.t('Giữ nguyên từ không phải tiếng Việt',
                      'Preserve non-Vietnamese words'),
                    value: controller.restoreInvalid,
                    onChanged: (v) { controller.restoreInvalid = v; controller.save(); },
                  ),
                ],
              ));
              final second = SurfaceCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeading(
                    icon: Icons.verified_user_outlined,
                    label: controller.t('TƯƠNG THÍCH AN TOÀN','SAFE COMPATIBILITY'),
                  ),
                  const SizedBox(height: 7),
                  if (Platform.isWindows) ...[
                    PreferenceSwitch(
                      title: controller.t('English trong terminal','English in terminals'),
                      subtitle: controller.t('Giữ nguyên lệnh và mã nguồn',
                        'Keep commands and source code unchanged'),
                      value: controller.terminalEnglish,
                      onChanged: (v) { controller.terminalEnglish = v; controller.save(); },
                    ),
                    const Divider(height: 9),
                  ],
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.lock_outline_rounded, size: 18, color: teal),
                    const SizedBox(width: 9),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(controller.t('Mật khẩu luôn dùng tiếng Anh',
                          'Passwords always use English'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(controller.t('Không đọc nội dung ô mật khẩu',
                          'Password fields are never read'),
                          style: const TextStyle(color: muted, fontSize: 11)),
                      ],
                    )),
                  ]),
                ],
              ));
              return box.maxWidth < 710
                ? Column(children: [first, const SizedBox(height: 10), second])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: first),
                    const SizedBox(width: 12),
                    Expanded(child: second),
                  ]);
            }),
            const SizedBox(height: 11),
            SurfaceCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _CardHeading(icon: Icons.keyboard_alt_outlined,
                  label: controller.t('THỬ GÕ NGAY','TRY TYPING')),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => controller.previewText = v,
                  decoration: InputDecoration(
                    hintText: controller.t('Gõ thử tiếng Việt và tiếng Anh...',
                      'Try Vietnamese and English here...'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 5),
                Text(controller.t('Thử: tieengs → tiếng  ·  vieetj → Việt',
                  'Try: tieengs → tiếng  ·  vieetj → Việt'),
                  style: const TextStyle(color: muted, fontSize: 10.5)),
              ]),
            ),
            const SizedBox(height: 11),
            Row(children: [
              Icon(
                controller.nativeConnected
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
                size: 15,
                color: controller.nativeConnected ? teal : const Color(0xFFB37B24),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(
                controller.nativeConnected
                  ? controller.t('Đã kết nối bộ máy gõ · Hoạt động offline',
                    'Native engine connected · Offline')
                  : controller.t('Chưa kết nối bộ máy gõ hệ thống',
                    'Native input engine not connected'),
                style: const TextStyle(color: muted, fontSize: 11),
              )),
              Text(controller.t('Không lưu lịch sử gõ', 'No typing history'),
                style: const TextStyle(color: muted, fontSize: 10.5)),
            ]),
          ]),
        ),
      ),
    ),
  );
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: teal, size: 17),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(
      color: muted, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .3)),
  ]);
}

class _HeroMode extends StatelessWidget {
  const _HeroMode({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(17),
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF008D85), Color(0xFF267EA9)],
      ),
    ),
    child: LayoutBuilder(builder: (context, box) {
      final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.language_rounded, color: Color(0xFFB5FFF0), size: 16),
          const SizedBox(width: 7),
          Text(controller.t('CHẾ ĐỘ GÕ','INPUT MODE'),
            style: const TextStyle(color: Color(0xFFC4F3EB),
              fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
        ]),
        const SizedBox(height: 8),
        Text(controller.t('Chuyển ngôn ngữ tức thì','Instant language switch'),
          style: const TextStyle(color: Colors.white,
            fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SizedBox(width: 265, height: 42, child: FilledButton(
          onPressed: () => controller.setVietnameseEnabled(!controller.vietnameseEnabled),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE3FFF9),
            foregroundColor: const Color(0xFF06474A),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.swap_horiz_rounded, size: 19),
            const SizedBox(width: 8),
            Flexible(child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                controller.vietnameseEnabled
                  ? controller.t('V  ·  TIẾNG VIỆT','V  ·  VIETNAMESE')
                  : controller.t('E  ·  TIẾNG ANH','E  ·  ENGLISH'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            )),
          ]),
        )),
      ]);
      final right = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.shield_outlined, size: 17, color: Color(0xFFB5FFF0)),
          const SizedBox(width: 7),
          Text(controller.t('AN TOÀN & RIÊNG TƯ','SAFE & PRIVATE'),
            style: const TextStyle(color: Color(0xFFC4F3EB),
              fontSize: 10.5, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 9),
        Text(controller.t('Gõ tự nhiên, không gián đoạn',
          'Natural typing, no interruptions'),
          style: const TextStyle(color: Colors.white,
            fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text(
          controller.t('Mật khẩu tự chuyển English  ·  Hoạt động offline\nTelex / VNI  ·  Đồng bộ phím tắt',
            'Passwords use English  ·  Fully offline\nTelex / VNI  ·  Shortcut synchronization'),
          style: const TextStyle(color: Color(0xFFE5F5F7), fontSize: 11.5, height: 1.6),
        ),
      ]);
      return box.maxWidth < 620
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            left, const SizedBox(height: 17), right,
          ])
        : Row(children: [
            Expanded(flex: 5, child: left),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: right),
          ]);
    }),
  );
}

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key, required this.controller, required this.vietnamese});
  final AppController controller;
  final bool vietnamese;
  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final words = widget.vietnamese ? c.vietnameseWords : c.englishWords;
    final filtered = words.where((w) => w.contains(query.toLowerCase())).toList()..sort();
    final title = widget.vietnamese ? c.t('Ưu tiên Telex','Vietnamese priority') : c.t('Từ điển tiếng Anh','English dictionary');
    return PageFrame(
      controller: c,
      title: title,
      subtitle: widget.vietnamese
        ? c.t('Các từ cần được ưu tiên xử lý theo quy tắc tiếng Việt.','Words that should prefer Vietnamese composition.')
        : c.t('Bảo vệ tên riêng, thuật ngữ và từ chuyên ngành khỏi bị chuyển đổi.','Protect names, terms and technical words from conversion.'),
      child: LayoutBuilder(builder: (context, space) {
        final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: TextField(
            onChanged: (v) => setState(() => query=v),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: c.t('Tìm từ...','Search words...')),
          )),
          const SizedBox(width: 12),
          PrimaryAction(label: c.t('Thêm từ','Add word'), icon: Icons.add, onPressed: _add),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.tips_and_updates_outlined, color: teal, size: 16),
          const SizedBox(width: 6),
          Text(c.t('Ví dụ gợi ý · nhấn + để thêm', 'Suggested examples · click + to add'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
        ]),
        const SizedBox(height: 5),
        Wrap(spacing: 6, runSpacing: 4, children: (widget.vietnamese
          ? <String>['been', 'boons', 'chayj', 'kieeur']
          : <String>['boost', 'parameter', 'download', 'setup', 'exe']
        ).map((word) => ActionChip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.add_circle_outline_rounded, size: 15, color: teal),
          label: Text(word, style: const TextStyle(fontSize: 11)),
          onPressed: () => c.addWord(word, vietnamese: widget.vietnamese),
        )).toList()),
        const SizedBox(height: 9),
        Expanded(child: SurfaceCard(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(children: [
                Text('${filtered.length} / ${words.length} ${c.t('từ','words')}', style: const TextStyle(color: muted, fontSize: 11)),
                const Spacer(),
                Text(c.t('Lưu cục bộ','Stored locally'), style: const TextStyle(color: muted, fontSize: 11)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.menu_book_outlined, size: 34, color: muted),
                    const SizedBox(height: 10),
                    Text(c.t('Chưa có từ tùy chỉnh','No custom words yet'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(c.t('Thêm từ đầu tiên bằng nút phía trên','Add your first word using the button above'),
                      style: const TextStyle(color: muted, fontSize: 11)),
                  ]))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 10, endIndent: 10),
                    itemBuilder: (context, index) {
                      final word = filtered[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.text_fields_rounded, color: teal, size: 18),
                        title: Text(word, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        trailing: IconButton(
                          tooltip: c.t('Xóa từ','Remove word'),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          onPressed: () => c.removeWord(word, vietnamese: widget.vietnamese),
                        ),
                      );
                    },
                  ),
            ),
          ]),
        )),
      ]);
        // The Windows logical height can drop below 300 px when a 125–150%
        // scale is applied to a compact Settings window. Keep the search and
        // list inside an explicit scroll area rather than overflowing.
        return space.maxHeight < 450
          ? SingleChildScrollView(child: SizedBox(height: 460, child: content))
          : content;
      }),
    );
  }

  Future<void> _add() async {
    final c = widget.controller;
    final input = TextEditingController();
    final word = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(c.t('Thêm từ mới','Add a word')),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: InputDecoration(hintText: c.t('Chỉ gồm ký tự a-z','Letters a-z only')),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(c.t('Hủy','Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, input.text), child: Text(c.t('Thêm','Add'))),
        ],
      ),
    );
    if (word != null) await c.addWord(word, vietnamese: widget.vietnamese);
    input.dispose();
  }
}

class SnippetsPage extends StatefulWidget {
  const SnippetsPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<SnippetsPage> createState() => _SnippetsPageState();
}

class _SnippetsPageState extends State<SnippetsPage> {
  late final TextEditingController textController;
  final Map<String, String> examples = const {
    'dc': 'được',
    'ntn': 'như thế nào',
    'sdt': 'Số điện thoại:',
    'eml': 'Email:',
    'camon': 'Cảm ơn bạn!',
  };

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: widget.controller.snippetText);
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  void addExample(String key, String value) {
    final lines = textController.text.split('\n');
    if (lines.any((line) => line.split('\t').first.trim() == key)) return;
    final existing = textController.text.trimRight();
    textController.text = existing.isEmpty ? '$key\t$value' : '$existing\n$key\t$value';
    widget.controller.snippetText = textController.text;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return PageFrame(
      controller: controller,
      title: controller.t('Gõ tắt thông minh', 'Smart snippets'),
      subtitle: controller.t('Bấm + để thêm ví dụ, chỉnh sửa rồi lưu.', 'Add an example, edit, then save.'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PreferenceSwitch(
            title: controller.t('Bật mở rộng gõ tắt','Enable snippet expansion'),
            subtitle: controller.t('Sau dấu cách, Enter hoặc Tab','After Space, Enter or Tab'),
            value: controller.snippetsEnabled,
            onChanged: (v) { controller.snippetsEnabled = v; controller.save(); },
          ),
          const Divider(height: 14),
          Row(children: [
            const Icon(Icons.lightbulb_outline_rounded, color: teal, size: 17),
            const SizedBox(width: 7),
            Text(controller.t('VÍ DỤ CÓ SẴN', 'READY EXAMPLES'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
          ]),
          const SizedBox(height: 7),
          Wrap(spacing: 7, runSpacing: 6, children: examples.entries.map((e) =>
            ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.add_rounded, color: teal, size: 16),
              label: Text('${e.key} → ${e.value}',
                style: const TextStyle(fontSize: 11)),
              onPressed: () => addExample(e.key, e.value),
            ),
          ).toList()),
        ])),
        const SizedBox(height: 9),
        Expanded(child: SurfaceCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('PHÍM TẮT  →  NỘI DUNG (TAB)'),
            Expanded(child: TextField(
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              controller: textController,
              onChanged: (v) { controller.snippetText = v; },
              decoration: const InputDecoration(
                hintText: 'dc\tđược\nntn\tnhư thế nào',
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            )),
            const SizedBox(height: 9),
            Align(alignment: Alignment.centerRight, child: PrimaryAction(
              label: controller.t('Lưu thay đổi', 'Save changes'),
              onPressed: controller.save,
            )),
          ],
        ))),
      ]),
    );
  }
}

class SymbolsPage extends StatefulWidget {
  const SymbolsPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<SymbolsPage> createState() => _SymbolsPageState();
}

class _SymbolsPageState extends State<SymbolsPage> {
  int selected = 0;
  static const categories = <String, List<String>>{
    'Phổ biến': ['→','←','↑','↓','↔','✓','✕','★','☆','♥','©','®','™','…'],
    'Toán học': ['±','∞','≠','≤','≥','×','÷','≈','√','∑','π','∆'],
    'Tiền tệ': ['€','£','¥','₫','\u0024','¢','₹'],
    'Ký hiệu': ['°','·','—','•','§','¶','№','@','#','°C'],
  };

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final category = categories.keys.elementAt(selected);
    return PageFrame(
      controller: controller,
      title: controller.t('Ký tự nhanh', 'Quick symbols'),
      subtitle: controller.t('Chọn nhóm, bấm ký tự để sao chép vào clipboard.',
        'Choose a category and click a symbol to copy.'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: teal),
            SizedBox(width: 8),
            Text('KÝ TỰ CÓ SẴN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 5, children: categories.keys.toList()
            .asMap().entries.map((entry) => ChoiceChip(
              label: Text(entry.value),
              selected: selected == entry.key,
              onSelected: (_) => setState(() => selected = entry.key),
            )).toList()),
        ])),
        const SizedBox(height: 9),
        Expanded(child: SurfaceCard(child: Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(child: Wrap(
            spacing: 9, runSpacing: 9,
            children: categories[category]!.map((symbol) => SizedBox(
              width: 58, height: 53,
              child: OutlinedButton(
                onPressed: () => controller.copySymbol(symbol),
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(symbol, style: const TextStyle(fontSize: 21)),
              ),
            )).toList(),
          )),
        ))),
      ]),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => PageFrame(
    controller: controller,
    title: controller.t('Cài đặt','Settings'),
    subtitle: controller.t('Một nơi quản lý chung cho Windows, macOS và Linux.','One shared control center for Windows, macOS and Linux.'),
    child: SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('INPUT'),
          _dropdown(controller.t('Kiểu gõ','Input method'), controller.inputMethod, ['Telex','VNI'],
            (v) { controller.inputMethod=v; controller.save(); }),
          const SizedBox(height: 14),
          _dropdown(controller.t('Ưu tiên ngôn ngữ','Language priority'), controller.languagePriority,
            ['Balanced','Vietnamese','English'], (v) { controller.languagePriority=v; controller.save(); }),
          const SizedBox(height: 14),
          _dropdown(controller.t('Phím chuyển V/E','V/E shortcut'), controller.hotkey,
            ['Ctrl + Shift + Space','Ctrl + Alt + V','Alt + Shift + V'],
            (v) { controller.hotkey=v; controller.save(); }),
        ])),
        const SizedBox(height: 12),
        SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('BEHAVIOR'),
          PreferenceSwitch(title: controller.t('Bảo vệ từ tiếng Anh','Protect English words'), subtitle: controller.t('Nhận diện offline','Offline recognition'), value: controller.smartEnglish,
            onChanged: (v) { controller.smartEnglish=v; controller.save(); }),
          const Divider(height: 10),
          PreferenceSwitch(title: controller.t('Khôi phục từ không hợp lệ','Restore invalid words'), subtitle: controller.t('Không giữ dấu khi chuỗi không hợp lệ','Remove marks from invalid sequences'), value: controller.restoreInvalid,
            onChanged: (v) { controller.restoreInvalid=v; controller.save(); }),
          const Divider(height: 10),
          PreferenceSwitch(title: controller.t('Sửa nhanh từ vừa gõ','Instant Word Repair'),
            subtitle: controller.t('Ctrl+Alt+Backspace ngay sau từ và dấu cách','Ctrl+Alt+Backspace after a word and space'),
            value: controller.instantRepairEnabled,
            onChanged:(v) {controller.instantRepairEnabled=v;controller.save();}),
          const Divider(height: 10),
          PreferenceSwitch(title: controller.t('Từ điển tự học có xác nhận','Adaptive Dictionary'),
            subtitle: controller.t('Chỉ học khi chủ động sửa lại một từ','Learn only from an explicit word repair'),
            value: controller.adaptiveLearningEnabled,
            onChanged:(v) {controller.adaptiveLearningEnabled=v;controller.save();}),
          const Divider(height: 10),
          PreferenceSwitch(title: controller.t('Dấu câu thông minh','Smart Punctuation'),
            subtitle: controller.t('Tùy chọn viết hoa đầu câu, tránh dấu cách liên tiếp','Optional sentence capitalization and duplicate-space guard'),
            value: controller.smartPunctuationEnabled,
            onChanged:(v) {controller.smartPunctuationEnabled=v;controller.save();}),
          const Divider(height: 10),
          PreferenceSwitch(title: controller.t('Tự dùng English trong terminal','Use English in terminal'), subtitle: controller.t('Giữ nguyên lệnh và mã nguồn','Preserve commands and source code'), value: controller.terminalEnglish,
            onChanged: (v) { controller.terminalEnglish=v; controller.save(); }),
        ])),
        const SizedBox(height: 12),
        SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('APPLICATION'),
          if (Platform.isWindows) ...[
            PreferenceSwitch(title: controller.t('Khởi động cùng hệ thống','Launch at login'), subtitle: controller.t('Tích hợp theo cơ chế của Windows','Uses Windows startup settings'), value: controller.autoStart,
              onChanged: (v) { controller.autoStart=v; controller.save(); }),
            const Divider(height: 10),
          ],
          if (Platform.isWindows || Platform.isMacOS) ...[
            PreferenceSwitch(title: controller.t('Hồ sơ theo ứng dụng','Per-app profiles'), subtitle: controller.t('Chọn chế độ nhập theo từng ứng dụng','Choose input mode for each app'), value: controller.profilesEnabled,
              onChanged: (v) { controller.profilesEnabled=v; controller.save(); }),
            const Divider(height: 10),
          ],
          _dropdown(controller.t('Ngôn ngữ giao diện','Interface language'), controller.englishUI ? 'English' : 'Tiếng Việt',
            ['Tiếng Việt','English'], (v) { controller.englishUI=v=='English'; controller.save(); }),
        ])),
        const SizedBox(height: 12),
        SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('PRIVACY'),
          Row(children: [
            const Icon(Icons.apps_rounded, color: teal),
            const SizedBox(width: 9),
            Expanded(child: Text(controller.t(
              'Chọn process bỏ qua và cấu hình từng ứng dụng',
              'Select excluded processes and per-app profiles'))),
            TextButton.icon(
              onPressed: () => controller.setPage(AppPage.applications),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(controller.t('Mở quản lý','Open manager'))),
          ]),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: PrimaryAction(label: controller.t('Lưu thay đổi','Save changes'), onPressed: controller.save)),
        ])),
      ]),
    ),
  );

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String> changed) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(label),
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        items: options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) { if (v != null) changed(v); },
      ),
    ],
  );
}
