import 'package:flutter/material.dart';

import 'controller.dart';
import 'widgets.dart';

class SnippetListPage extends StatefulWidget {
  const SnippetListPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<SnippetListPage> createState() => _SnippetListPageState();
}

class _SnippetListPageState extends State<SnippetListPage> {
  final search = TextEditingController();
  static const samples = {
    'dc': 'Địa chỉ:',
    'sdt': 'Số điện thoại:',
    'eml': 'Email:',
    'tk': 'Tài khoản:',
    'mk': 'Mật khẩu:',
  };

  Map<String, String> get entries {
    final items = <String, String>{};
    for (final line in widget.controller.snippetText.split('\n')) {
      final tab = line.indexOf('\t');
      if (tab > 0) {
        final key = line.substring(0, tab).trim();
        if (key.isNotEmpty) items[key] = line.substring(tab + 1);
      }
    }
    return items;
  }

  Future<void> persist(Map<String, String> items) async {
    final normalized = items.entries
        .map((e) => '${e.key}\t${e.value}')
        .join('\n');
    try {
      await widget.controller.updateSnippets(normalized);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.t(
              'Không thể lưu gõ tắt. Kiểm tra kết nối bộ gõ và thử lại.',
              'Could not save shortcuts. Check the input engine and retry.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> edit({String? oldKey}) async {
    final current = entries;
    final keyInput = TextEditingController(text: oldKey ?? '');
    final valueInput = TextEditingController(
      text: oldKey == null
          ? ''
          : (current[oldKey] ?? '')
                .replaceAll(r'\n', '\n')
                .replaceAll(r'\t', '\t'),
    );
    String? error;
    final result = await showDialog<MapEntry<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(
            widget.controller.t(
              oldKey == null ? 'Thêm gõ tắt' : 'Sửa gõ tắt',
              oldKey == null ? 'Add snippet' : 'Edit snippet',
            ),
          ),
          content: SizedBox(
            width: 390,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyInput,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: widget.controller.t('Phím tắt', 'Shortcut'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueInput,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: widget.controller.t(
                      'Nội dung thay thế',
                      'Expansion',
                    ),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(widget.controller.t('Hủy', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final key = keyInput.text.trim();
                final value = valueInput.text.trim();
                if (!RegExp(r'^[a-zA-Z]{2,48}$').hasMatch(key) ||
                    value.isEmpty ||
                    value.length > 1024 ||
                    value.contains('\t')) {
                  update(
                    () => error = widget.controller.t(
                      'Phím tắt 2–48 chữ a-z, nội dung tối đa 1024 ký tự; hỗ trợ nhiều dòng.',
                      'Shortcut 2–48 letters a-z, expansion up to 1024 characters; supports multiline.',
                    ),
                  );
                  return;
                }
                if (key != oldKey &&
                    current.keys.any(
                      (word) => word.toLowerCase() == key.toLowerCase(),
                    )) {
                  update(
                    () => error = widget.controller.t(
                      'Phím tắt đã tồn tại.',
                      'Shortcut already exists.',
                    ),
                  );
                  return;
                }
                if (oldKey == null && current.length >= 256) {
                  update(
                    () => error = widget.controller.t(
                      'Tối đa 256 gõ tắt.',
                      'Maximum 256 snippets.',
                    ),
                  );
                  return;
                }
                final encoded = value
                    .replaceAll('\r\n', '\n')
                    .replaceAll('\r', '\n')
                    .replaceAll('\n', r'\n');
                Navigator.pop(ctx, MapEntry(key, encoded));
              },
              child: Text(widget.controller.t('Lưu', 'Save')),
            ),
          ],
        ),
      ),
    );
    keyInput.dispose();
    valueInput.dispose();
    if (result == null) return;
    if (oldKey != null) current.remove(oldKey);
    current[result.key] = result.value;
    await persist(current);
  }

  Future<void> remove(String key) async {
    final items = entries;
    items.remove(key);
    await persist(items);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final filtered = entries.entries
        .where(
          (e) => ('${e.key} ${e.value}').toLowerCase().contains(
            search.text.toLowerCase(),
          ),
        )
        .toList();
    return PageFrame(
      controller: c,
      title: c.t('Gõ tắt (Text Expand)', 'Snippets (Text Expand)'),
      subtitle: c.t(
        'Thêm, sửa, xóa từng mục. Danh sách cập nhật ngay sau khi lưu.',
        'Add, edit or delete entries. The list updates immediately.',
      ),
      child: LayoutBuilder(
        builder: (context, viewport) {
          final content = Column(
            children: [
              SurfaceCard(
                child: PreferenceSwitch(
                  title: c.t('Bật mở rộng gõ tắt', 'Enable snippet expansion'),
                  subtitle: c.t(
                    'Mở rộng sau dấu cách, Enter hoặc Tab',
                    'Expand on Space, Enter or Tab',
                  ),
                  value: c.snippetsEnabled,
                  onChanged: (v) {
                    c.snippetsEnabled = v;
                    c.save();
                  },
                ),
              ),
              const SizedBox(height: 7),
              if (!c.snippetsEnabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 17,
                        color: muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.t(
                            'Gõ tắt đang tắt. Thêm mục đầu tiên sẽ tự bật; hoặc bật bằng công tắc phía trên.',
                            'Expansion is off. Adding the first entry enables it, or use the switch above.',
                          ),
                          style: const TextStyle(fontSize: 11.5, color: muted),
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  c.t(
                    'Biến mẫu: {date}, {time}, {datetime}, {clipboard}, {cursor}. Có thể xuống dòng; clipboard chỉ đọc khi kích hoạt.',
                    'Macros: {date}, {time}, {datetime}, {clipboard}, {cursor}. Multiline; clipboard read on trigger only.',
                  ),
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  c.t(
                    'Smart Undo: Backspace ngay sau gõ tắt bằng dấu cách để trở lại phím tắt (trong ô văn bản được hỗ trợ).',
                    'Smart Undo: Backspace immediately after Space expansion restores the shortcut in supported text fields.',
                  ),
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: c.t(
                          'Tìm trong danh sách...',
                          'Search entries...',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PrimaryAction(
                    label: c.t('Thêm gõ tắt', 'Add snippet'),
                    icon: Icons.add,
                    onPressed: () => edit(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SurfaceCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.layers_outlined, color: teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.t('Danh sách gõ tắt', 'Saved shortcuts'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${filtered.length} ${c.t('mục', 'entries')}',
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ),
                      const Divider(height: 15),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  c.t(
                                    'Chưa có mục nào. Nhấn Thêm gõ tắt để bắt đầu.',
                                    'No entries. Add a snippet to get started.',
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final item = filtered[i];
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.short_text_rounded,
                                      color: teal,
                                    ),
                                    title: Text(
                                      item.key,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      item.value,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: c.t('Sửa', 'Edit'),
                                          onPressed: () =>
                                              edit(oldKey: item.key),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: c.t('Xóa', 'Delete'),
                                          onPressed: () => remove(item.key),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Keep quick-add examples in a single horizontally scrollable strip.
              // Wrapping to two rows made the editor overflow at the 900x650 minimum.
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final entry in samples.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ActionChip(
                          avatar: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 16,
                            color: teal,
                          ),
                          label: Text('${entry.key} → ${entry.value}'),
                          onPressed: () async {
                            final items = entries;
                            if (!items.containsKey(entry.key)) {
                              items[entry.key] = entry.value;
                              await persist(items);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
          // A capped, scrollable editor prevents clipping on small monitors
          // at 125–150% DPI without limiting the native resize affordance.
          return viewport.maxHeight < 450
              ? SingleChildScrollView(
                  child: SizedBox(height: 490, child: content),
                )
              : content;
        },
      ),
    );
  }
}
