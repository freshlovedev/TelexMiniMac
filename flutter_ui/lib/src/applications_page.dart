import 'dart:io';

import 'package:flutter/material.dart';

import 'controller.dart';
import 'widgets.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  List<String> running = [];
  String query = '';
  bool refreshing = false;
  String? error;
  bool showRunning = false;

  List<String> get saved => widget.controller.managedApps
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  List<String> get excluded => widget.controller.excludedApps
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  Map<String, String> get profiles {
    final map = <String, String>{};
    for (final row in widget.controller.profilesText.split('\n')) {
      final fields = row.split('\t');
      if (fields.length == 2) map[fields.first.toLowerCase()] = fields.last;
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => refreshing = true);
    final result = await widget.controller.runningProcesses();
    if (mounted) {
      setState(() {
        running = result;
        refreshing = false;
      });
    }
  }

  Future<void> chooseExecutable() async {
    final name = await widget.controller.chooseExecutable();
    if (name != null && name.isNotEmpty) {
      await add(name, true);
    }
  }

  Future<void> add([String? existing, bool fromFilePicker = false]) async {
    final input = TextEditingController(text: existing ?? '');
    String? validation;
    final answer = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(
            widget.controller.t(
              existing == null
                  ? 'Thêm ứng dụng / process'
                  : 'Sửa ứng dụng / process',
              existing == null
                  ? 'Add application / process'
                  : 'Edit application / process',
            ),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: input,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: widget.controller.t(
                      'Tên file thực thi',
                      'Executable name',
                    ),
                    hintText: Platform.isWindows
                        ? 'notepad.exe'
                        : 'com.example.app',
                  ),
                  onSubmitted: (v) {
                    if (AppController.validProcessName(v.trim())) {
                      Navigator.pop(ctx, v.trim());
                    }
                  },
                ),
                if (validation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(
                      validation!,
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
                final name = input.text.trim();
                if (!AppController.validProcessName(name)) {
                  update(
                    () => validation = widget.controller.t(
                      'Tên không hợp lệ. Ví dụ: notepad.exe',
                      'Invalid executable name. Example: notepad.exe',
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, name);
              },
              child: Text(
                widget.controller.t('Lưu vào danh sách', 'Save to list'),
              ),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    if (answer == null) return;
    final items = saved.toSet();
    if (existing != null && !fromFilePicker) items.remove(existing);
    if (items.any((e) => e.toLowerCase() == answer.toLowerCase())) {
      if (mounted) {
        setState(
          () => error = widget.controller.t(
            'Process đã có trong danh sách.',
            'Already in the list.',
          ),
        );
      }
      return;
    }
    items.add(answer);
    widget.controller.managedApps = items.join(',');
    await widget.controller.save();
    if (existing != null && !fromFilePicker) {
      if (excluded.contains(existing)) {
        await toggleExclusion(existing, false);
        await toggleExclusion(answer, true);
      }
      final p = profiles;
      if (p.containsKey(existing.toLowerCase())) {
        final mode = p[existing.toLowerCase()]!;
        p.remove(existing.toLowerCase());
        p[answer.toLowerCase()] = mode;
        await widget.controller.saveProfiles(
          p.entries.map((e) => '${e.key}\t${e.value}').join('\n'),
        );
      }
    }
    if (mounted) setState(() => error = null);
  }

  Future<void> remove(String name) async {
    final items = saved.where((e) => e.toLowerCase() != name.toLowerCase());
    widget.controller.managedApps = items.join(',');
    await widget.controller.save();
    await toggleExclusion(name, false);
    final p = profiles..remove(name.toLowerCase());
    await widget.controller.saveProfiles(
      p.entries.map((e) => '${e.key}\t${e.value}').join('\n'),
    );
    if (mounted) setState(() {});
  }

  Future<void> toggleExclusion(String name, bool value) async {
    final items = excluded.toSet()
      ..removeWhere((e) => e.toLowerCase() == name.toLowerCase());
    if (value) items.add(name);
    widget.controller.excludedApps = items.join(',');
    await widget.controller.save();
    if (mounted) setState(() {});
  }

  Future<void> changeProfile(String name, String mode) async {
    final rules = profiles;
    if (mode == 'Default') {
      rules.remove(name.toLowerCase());
    } else {
      rules[name.toLowerCase()] = mode;
    }
    await widget.controller.saveProfiles(
      rules.entries.map((e) => '${e.key}\t${e.value}').join('\n'),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final stored = saved;
    final list =
        (showRunning ? <String>{...running, ...stored} : stored.toSet())
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final filtered = list
        .where((e) => e.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return PageFrame(
      controller: c,
      title: c.t('Ứng dụng & Process', 'Applications & Processes'),
      subtitle: c.t(
        'Danh sách được lưu riêng, không nằm trong ô nhập.',
        'Saved entries appear in a separate list, not a textbox.',
      ),
      child: LayoutBuilder(
        builder: (context, viewport) {
          final content = Column(
            children: [
              SurfaceCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => query = v),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded),
                              hintText: c.t(
                                'Tìm ứng dụng hoặc process...',
                                'Search applications or processes...',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: refresh,
                          tooltip: c.t('Quét lại', 'Refresh'),
                          icon: const Icon(Icons.refresh),
                        ),
                        if (!Platform.isLinux) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: chooseExecutable,
                            icon: const Icon(Icons.folder_open_outlined),
                            label: Text(
                              Platform.isMacOS
                                  ? c.t('Chọn .app', 'Choose .app')
                                  : c.t('Chọn EXE', 'Choose EXE'),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        PrimaryAction(
                          label: c.t('Thêm ứng dụng', 'Add application'),
                          icon: Icons.add,
                          onPressed: () => add(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    PreferenceSwitch(
                      title: c.t(
                        'Quy tắc riêng theo ứng dụng',
                        'Per-application rules',
                      ),
                      subtitle: Platform.isLinux
                          ? c.t(
                              'Fcitx5 áp dụng theo chương trình. IBus chưa xác định được ứng dụng đích.',
                              'Fcitx5 applies per program; IBus lacks target-application identity.',
                            )
                          : c.t(
                              'Chọn ngôn ngữ cho từng ứng dụng',
                              'Choose a language for each application',
                            ),
                      value: c.profilesEnabled,
                      onChanged: (v) {
                        c.profilesEnabled = v;
                        c.save();
                      },
                    ),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SurfaceCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.apps_outlined, color: teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.t(
                                'Danh sách ứng dụng & process',
                                'Applications & processes',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (refreshing)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          Text(
                            '${filtered.length}',
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text(
                              c.t(
                                'Đã thêm (${stored.length})',
                                'Saved (${stored.length})',
                              ),
                            ),
                            selected: !showRunning,
                            onSelected: (_) =>
                                setState(() => showRunning = false),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(
                              c.t('Process đang chạy', 'Running processes'),
                            ),
                            selected: showRunning,
                            onSelected: (_) =>
                                setState(() => showRunning = true),
                          ),
                        ],
                      ),
                      const Divider(height: 13),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  c.t(
                                    'Chưa có mục nào. Nhấn Thêm ứng dụng để tạo danh sách.',
                                    'No entries. Click Add application to create your list.',
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final name = filtered[i];
                                  final isSaved = stored.any(
                                    (e) =>
                                        e.toLowerCase() == name.toLowerCase(),
                                  );
                                  final ignored = excluded.any(
                                    (e) =>
                                        e.toLowerCase() == name.toLowerCase(),
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSaved
                                              ? Icons.apps_rounded
                                              : Icons.memory_rounded,
                                          color: teal,
                                          size: 19,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Tooltip(
                                          message: c.t(
                                            'Bỏ qua bộ gõ',
                                            'Ignore input engine',
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                c.t('Bỏ qua', 'Ignore'),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              Checkbox(
                                                value: ignored,
                                                onChanged: (value) =>
                                                    toggleExclusion(
                                                      name,
                                                      value ?? false,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 116,
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            underline: const SizedBox.shrink(),
                                            value:
                                                profiles[name.toLowerCase()] ??
                                                'Default',
                                            items:
                                                [
                                                      'Default',
                                                      'English',
                                                      'Vietnamese',
                                                      'Balanced',
                                                    ]
                                                    .map(
                                                      (
                                                        mode,
                                                      ) => DropdownMenuItem(
                                                        value: mode,
                                                        child: Text(
                                                          mode,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                            onChanged: (mode) {
                                              if (mode != null) {
                                                changeProfile(name, mode);
                                              }
                                            },
                                          ),
                                        ),
                                        if (isSaved) ...[
                                          IconButton(
                                            tooltip: c.t('Sửa', 'Edit'),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 19,
                                            ),
                                            onPressed: () => add(name),
                                          ),
                                          IconButton(
                                            tooltip: c.t('Xóa', 'Delete'),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 19,
                                            ),
                                            onPressed: () => remove(name),
                                          ),
                                        ] else
                                          IconButton(
                                            tooltip: c.t(
                                              'Thêm vào danh sách',
                                              'Add to saved list',
                                            ),
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                              size: 20,
                                            ),
                                            onPressed: () => add(name),
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
            ],
          );
          return viewport.maxHeight < 440
              ? SingleChildScrollView(
                  child: SizedBox(height: 550, child: content),
                )
              : content;
        },
      ),
    );
  }
}
