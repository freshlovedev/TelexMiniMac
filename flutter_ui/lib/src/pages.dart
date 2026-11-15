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
    subtitle: controller.t('Hai ngôn ngữ. Một trải nghiệm liền mạch.', 'Two languages. One seamless experience.'),
    child: SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _HeroMode(controller: controller),
        const SizedBox(height: 16),
        SectionTitle(controller.t('TÙY CHỈNH TRẢI NGHIỆM', 'PERSONALIZE YOUR EXPERIENCE')),
        LayoutBuilder(builder: (context, box) {
          final stacked = box.maxWidth < 760;
          final first = SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(controller.t('NGÔN NGỮ NHẬN DIỆN','LANGUAGE RECOGNITION'),
                style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              PreferenceSwitch(
                title: controller.t('Bảo vệ từ tiếng Anh (offline)','Protect English words (offline)'),
                subtitle: controller.t('Nhận diện cục bộ, không cần Internet','Local recognition, no Internet required'),
                value: controller.smartEnglish,
                onChanged: (v) { controller.smartEnglish=v; controller.save(); },
              ),
              const Divider(height: 12),
              PreferenceSwitch(
                title: controller.t('Khôi phục từ không hợp lệ','Restore invalid words'),
                subtitle: controller.t('Giữ nguyên từ khi không phải tiếng Việt','Preserve words that are not Vietnamese'),
                value: controller.restoreInvalid,
                onChanged: (v) { controller.restoreInvalid=v; controller.save(); },
              ),
            ]),
          );
          final second = SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(controller.t('TƯƠNG THÍCH AN TOÀN','SAFE COMPATIBILITY'),
                style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (Platform.isWindows) ...[
                PreferenceSwitch(
                  title: controller.t('Tự dùng English trong terminal','Use English automatically in terminals'),
                  subtitle: controller.t('Không can thiệp lệnh và mã nguồn','Avoid changing commands and source code'),
                  value: controller.terminalEnglish,
                  onChanged: (v) { controller.terminalEnglish=v; controller.save(); },
                ),
                const SizedBox(height: 5),
              ],
              Text(controller.t('Mật khẩu: luôn giữ nguyên tiếng Anh','Password fields: always preserve English'),
                style: const TextStyle(color: teal, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              Text(controller.t('Không đọc hoặc xử lý nội dung ô mật khẩu','Password field contents are never read or processed'),
                style: const TextStyle(color: muted, fontSize: 11)),
            ]),
          );
          return stacked
            ? Column(children: [first, const SizedBox(height: 12), second])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: first), const SizedBox(width: 14), Expanded(child: second),
              ]);
        }),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(controller.t('THỬ GÕ NGAY','TRY TYPING'),
              style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => controller.previewText=v,
              decoration: InputDecoration(
                hintText: controller.t('Gõ thử tiếng Việt và tiếng Anh...','Try Vietnamese and English here...'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
              ),
            ),
            const SizedBox(height: 8),
            Text(controller.t('Ví dụ: tieengs vieetj · bilingual typing','Example: tieengs vieetj · bilingual typing'),
              style: const TextStyle(color: muted, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.shield_outlined, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(
            controller.nativeConnected
              ? controller.t('Đã kết nối giao diện với cấu hình hệ thống.','Connected to native settings bridge.')
              : controller.t('Chưa kết nối cầu nối hệ thống. Chế độ gõ có thể chưa được áp dụng.','Native bridge unavailable. Input-mode changes may not take effect.'),
            style: const TextStyle(color: muted, fontSize: 10.5),
          )),
        ]),
      ]),
    ),
  );
}

class _HeroMode extends StatelessWidget {
  const _HeroMode({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF008F89), Color(0xFF2879AE)],
      ),
      border: Border.all(color: const Color(0xFF36BDB1), width: 1),
    ),
    child: LayoutBuilder(builder: (context, box) {
      final stacked = box.maxWidth < 640;
      final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(controller.t('CHẾ ĐỘ HIỆN TẠI','CURRENT MODE'),
          style: const TextStyle(color: Color(0xFFC4F3EB), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .4)),
        const SizedBox(height: 12),
        Text(controller.t('Chuyển chế độ tức thì','Switch modes instantly'),
          style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        SizedBox(
          width: 270,
          child: FilledButton(
            onPressed: () => controller.setVietnameseEnabled(!controller.vietnameseEnabled),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE0FFF7),
              foregroundColor: const Color(0xFF06474A),
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            ),
            child: Text(
              controller.vietnameseEnabled
                ? controller.t('V  ·  TIẾNG VIỆT','V  ·  VIETNAMESE')
                : controller.t('E  ·  TIẾNG ANH','E  ·  ENGLISH'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: .4),
            ),
          ),
        ),
      ]);
      final right = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(controller.t('CHẾ ĐỘ AN TOÀN','SAFE MODE'),
          style: const TextStyle(color: Color(0xFFC4F3EB), fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(controller.t('Gõ tiếng Việt và tiếng Anh tự nhiên','Type Vietnamese and English naturally'),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(
          Platform.isWindows
            ? controller.t('Mật khẩu luôn dùng English\nBảo vệ ứng dụng terminal\nXử lý hoàn toàn offline','Passwords always use English\nProtect terminal applications\nFully offline processing')
            : controller.t('Mật khẩu luôn dùng English\nKhông xử lý nội dung nhạy cảm\nXử lý hoàn toàn offline','Passwords always use English\nSensitive fields are not processed\nFully offline processing'),
          style: const TextStyle(color: Color(0xFFE5F5F7), fontSize: 12, height: 1.6),
        ),
      ]);
      return stacked
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, const SizedBox(height: 22), right])
        : Row(children: [Expanded(child: left), const SizedBox(width: 28), Expanded(child: right)]);
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: TextField(
            onChanged: (v) => setState(() => query=v),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: c.t('Tìm từ...','Search words...')),
          )),
          const SizedBox(width: 12),
          PrimaryAction(label: c.t('Thêm từ','Add word'), icon: Icons.add, onPressed: _add),
        ]),
        const SizedBox(height: 14),
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
      ]),
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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return PageFrame(
      controller: controller,
      title: controller.t('Gõ tắt thông minh','Smart snippets'),
      subtitle: controller.t('Tạo cụm từ thay thế chạy hoàn toàn offline.','Create offline text-expansion shortcuts.'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PreferenceSwitch(
            title: controller.t('Bật mở rộng gõ tắt','Enable snippet expansion'),
            subtitle: controller.t('Chỉ mở rộng sau dấu cách, Enter hoặc Tab','Expand after Space, Enter or Tab'),
            value: controller.snippetsEnabled,
            onChanged: (v) { controller.snippetsEnabled=v; controller.save(); },
          ),
          const Divider(),
          const FieldLabel('SHORTCUTS'),
          Expanded(child: TextField(
            expands: true,
            minLines: null,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            controller: textController,
            onChanged: (v) { controller.snippetText=v; },
            decoration: const InputDecoration(
              hintText: 'dc\tđược\nntn\tnhư thế nào',
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          )),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: PrimaryAction(
            label: controller.t('Lưu thay đổi','Save changes'),
            onPressed: controller.save,
          )),
        ])),
      ]),
    );
  }
}

class SymbolsPage extends StatelessWidget {
  const SymbolsPage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => PageFrame(
    controller: controller,
    title: controller.t('Ký tự nhanh','Quick symbols'),
    subtitle: controller.t('Chọn ký tự để sao chép, sau đó dán vào ứng dụng đang dùng.','Select a symbol to copy, then paste it into your app.'),
    child: SurfaceCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: controller.symbols.map((symbol) => SizedBox(
          width: 62,
          height: 62,
          child: OutlinedButton(
            onPressed: () => controller.copySymbol(symbol),
            child: Text(symbol, style: const TextStyle(fontSize: 23)),
          ),
        )).toList(),
      ),
    ),
  );
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
          TextField(
            controller: TextEditingController(text: controller.excludedApps),
            onChanged: (v) => controller.excludedApps=v,
            decoration: InputDecoration(labelText: controller.t('Ứng dụng bỏ qua','Excluded applications'), hintText: 'process.exe, terminal'),
          ),
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
