import 'dart:io';

import 'package:flutter/material.dart';

import 'controller.dart';
import 'widgets.dart';

class ReferenceDashboard extends StatelessWidget {
  const ReferenceDashboard({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => PageFrame(
    controller: controller,
    title: controller.t('Chào mừng đến với TelexMini', 'Welcome to TelexMini'),
    subtitle: controller.t(
      'Gõ tiếng Việt và tiếng Anh tự nhiên, nhanh và chính xác.',
      'Type Vietnamese and English naturally, quickly and accurately.',
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _modeBar(context),
            const SizedBox(height: 10),
            _priorityPicker(),
            const SizedBox(height: 12),
            if (constraints.maxWidth >= 620)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _preferences(),
                        const SizedBox(height: 12),
                        _safety(),
                        const SizedBox(height: 12),
                        _typeTester(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _miniSnippets(),
                        const SizedBox(height: 12),
                        _miniWords(true),
                        const SizedBox(height: 12),
                        _miniWords(false),
                        const SizedBox(height: 12),
                        _symbols(),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              _preferences(),
              const SizedBox(height: 12),
              _safety(),
              const SizedBox(height: 12),
              _typeTester(),
              const SizedBox(height: 12),
              _miniSnippets(),
              const SizedBox(height: 12),
              _miniWords(true),
              const SizedBox(height: 12),
              _miniWords(false),
              const SizedBox(height: 12),
              _symbols(),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _priorityPicker() => SurfaceCard(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 18, color: teal),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                controller.t(
                  'Chế độ ưu tiên khi gõ V',
                  'Language priority in V mode',
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LanguagePrioritySelector(controller: controller),
        const SizedBox(height: 5),
        Text(
          controller.t(
            'Balanced: cân bằng Anh–Việt. Ưu tiên Việt: mạnh về tiếng Việt. Ưu tiên Anh: giữ từ tiếng Anh đã biết. Nút E vẫn là chế độ gõ nguyên văn.',
            'Balanced: bilingual. Vietnamese first: favor Vietnamese words. English first: preserve known English. E still types literal characters.',
          ),
          style: const TextStyle(fontSize: 10.5, color: muted),
        ),
      ],
    ),
  );

  Widget _typeTester() => SurfaceCard(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(Icons.edit_square, controller.t('Thử gõ ngay', 'Try typing')),
        const SizedBox(height: 8),
        TextField(
          onChanged: (value) => controller.previewText = value,
          decoration: InputDecoration(
            hintText: controller.t(
              'Gõ thử tiếng Việt và tiếng Anh...',
              'Try Vietnamese and English...',
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _heading(IconData icon, String label, {VoidCallback? onAdd}) => Row(
    children: [
      Icon(icon, size: 21, color: const Color(0xFF006D71)),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      if (onAdd != null)
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline_rounded),
          tooltip: controller.t('Mở danh sách', 'Open list'),
        ),
    ],
  );

  Widget _modeBar(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(
        colors: [Color(0xFF008D83), Color(0xFF004462)],
      ),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 15,
      runSpacing: 14,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.keyboard_rounded, size: 33, color: Colors.white),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.t('Chế độ hiện tại', 'Current mode'),
                  style: const TextStyle(
                    color: Color(0xFFCEF1EF),
                    fontSize: 12,
                  ),
                ),
                Text(
                  controller.vietnameseEnabled
                      ? controller.t('Tiếng Việt', 'Vietnamese')
                      : 'English',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _modeOption('V', controller.t('Tiếng Việt', 'Vietnamese'), true),
              _modeOption('E', 'English', false),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            final options = ['Telex', 'VNI'];
            showMenu<String>(
              context: context,
              position: const RelativeRect.fromLTRB(650, 160, 22, 0),
              items: options
                  .map((e) => PopupMenuItem(value: e, child: Text(e)))
                  .toList(),
            ).then((value) {
              if (value != null) {
                controller.inputMethod = value;
                controller.save();
              }
            });
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF3F98A7)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
          ),
          icon: const Icon(Icons.keyboard_alt_outlined),
          label: Text(
            '${controller.t('Kiểu gõ', 'Input')}: ${controller.inputMethod}  ⌄',
          ),
        ),
      ],
    ),
  );

  Widget _modeOption(String initial, String label, bool vietnamese) {
    final selected = controller.vietnameseEnabled == vietnamese;
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => controller.setVietnameseEnabled(vietnamese),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF007F82) : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              initial,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF07334B),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF07334B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preferences() => SurfaceCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      children: [
        _heading(
          Icons.tune_rounded,
          controller.t('Tùy chỉnh trải nghiệm', 'Customize experience'),
        ),
        const Divider(height: 15),
        PreferenceSwitch(
          title: controller.t(
            'Bảo vệ từ tiếng Anh (offline)',
            'Protect English words (offline)',
          ),
          subtitle: controller.t(
            'Nhận diện cụm từ tiếng Anh, không cần Internet',
            'Recognize English without Internet',
          ),
          value: controller.smartEnglish,
          onChanged: (v) {
            controller.smartEnglish = v;
            controller.save();
          },
        ),
        const Divider(height: 14),
        PreferenceSwitch(
          title: controller.t(
            'Khôi phục từ không hợp lệ',
            'Restore invalid words',
          ),
          subtitle: controller.t(
            'Giữ nguyên từ khi không phải tiếng Việt',
            'Preserve non-Vietnamese words',
          ),
          value: controller.restoreInvalid,
          onChanged: (v) {
            controller.restoreInvalid = v;
            controller.save();
          },
        ),
      ],
    ),
  );

  Widget _safety() => SurfaceCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      children: [
        _heading(
          Icons.shield_outlined,
          controller.t('Tương thích & an toàn', 'Compatibility & safety'),
        ),
        const Divider(height: 15),
        PreferenceSwitch(
          title: controller.t(
            'Tự dùng English trong terminal',
            'Use English in terminal',
          ),
          subtitle: controller.t(
            'Không can thiệp lệnh và mã nguồn',
            'Do not modify commands and code',
          ),
          value: controller.terminalEnglish,
          onChanged: Platform.isWindows
              ? (v) {
                  controller.terminalEnglish = v;
                  controller.save();
                }
              : (_) {},
        ),
        const Divider(height: 14),
        Row(
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFFE38A09)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.t(
                      'Mật khẩu: luôn giữ nguyên tiếng Anh',
                      'Passwords always stay English',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF008A70),
                    ),
                  ),
                  Text(
                    controller.t(
                      'Không đọc hoặc xử lý nội dung ở mật khẩu',
                      'Never read or process password contents',
                    ),
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    ),
  );

  Widget _miniSnippets() {
    final items = <MapEntry<String, String>>[];
    for (final line in controller.snippetText.split('\n')) {
      final tab = line.indexOf('\t');
      if (tab > 0) {
        items.add(MapEntry(line.substring(0, tab), line.substring(tab + 1)));
      }
    }
    final display = items.take(5).toList();
    return SurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(
            Icons.layers_outlined,
            controller.t('Gõ tắt (Text Expand)', 'Snippets (Text Expand)'),
            onAdd: () => controller.setPage(AppPage.snippets),
          ),
          const Divider(height: 13),
          Text(
            controller.snippetsEnabled
                ? controller.t(
                    'Đang bật · gõ phím tắt rồi Space để mở rộng',
                    'On · type a shortcut + Space',
                  )
                : controller.t(
                    'Đang tắt · bật ở màn hình Gõ tắt',
                    'Off · enable in Snippets',
                  ),
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          if (display.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                controller.t(
                  'Chưa có gõ tắt nào được lưu. Nhấn + để thêm.',
                  'No saved snippets. Click + to create one.',
                ),
                style: const TextStyle(fontSize: 11.5, color: muted),
              ),
            ),
          ...display.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniWords(bool vietnamese) {
    final words = vietnamese
        ? controller.vietnameseWords
        : controller.englishWords;
    final view = words.take(5).toList();
    return SurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(
            vietnamese ? Icons.translate_rounded : Icons.layers_rounded,
            vietnamese
                ? controller.t('Ưu tiên Telex (Ngoại lệ)', 'Telex priority')
                : controller.t('Từ điển Anh', 'English dictionary'),
            onAdd: () => controller.setPage(
              vietnamese
                  ? AppPage.vietnamesePriority
                  : AppPage.englishDictionary,
            ),
          ),
          const Divider(height: 13),
          if (view.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                vietnamese
                    ? controller.t(
                        'Chưa có ngoại lệ tiếng Việt. Nhấn + để thêm.',
                        'No Vietnamese exceptions. Click + to add.',
                      )
                    : controller.t(
                        'Chưa có từ tùy chỉnh. Từ điển tích hợp vẫn hoạt động.',
                        'No custom words yet. Built-in English recognition still works.',
                      ),
                style: const TextStyle(fontSize: 11.5, color: muted),
              ),
            ),
          ...view.map(
            (word) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                word,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _symbols() => SurfaceCard(
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          Icons.functions_rounded,
          controller.t('Ký tự nhanh', 'Quick symbols'),
          onAdd: () => controller.setPage(AppPage.symbols),
        ),
        const Divider(height: 13),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: controller.symbols
              .take(15)
              .map(
                (s) => SizedBox(
                  width: 43,
                  height: 41,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => controller.copySymbol(s),
                    child: Text(s, style: const TextStyle(fontSize: 18)),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}
