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
  String? error;
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() { refreshing = true; error = null; });
    final items = await widget.controller.runningProcesses();
    if (mounted) setState(() { running = items; refreshing = false; });
  }

  List<String> get excluded => widget.controller.excludedApps
    .split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Map<String,String> get profiles {
    final result = <String,String>{};
    for (final row in widget.controller.profilesText.split('\n')) {
      final cells = row.split('\t');
      if (cells.length == 2) result[cells[0].toLowerCase()] = cells[1];
    }
    return result;
  }

  Future<void> toggleExclusion(String process, bool include) async {
    final names = excluded.toSet();
    names.removeWhere((name) => name.toLowerCase() == process.toLowerCase());
    if (include) names.add(process);
    widget.controller.excludedApps = names.join(',');
    await widget.controller.save();
    if (mounted) setState(() {});
  }

  Future<void> changeProfile(String process, String mode) async {
    final rules = profiles;
    if (mode == 'Default') {
      rules.remove(process.toLowerCase());
    } else {
      rules[process.toLowerCase()] = mode;
    }
    try {
      final serialized = rules.entries.map((item) =>
        [item.key, item.value].join('\t')).join('\n');
      await widget.controller.saveProfiles(serialized);
      if (mounted) setState(() { error = null; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); });
    }
  }

  Future<void> addProcess() async {
    final input = TextEditingController();
    final process = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.controller.t('Thêm tên ứng dụng', 'Add application')),
        content: TextField(controller: input, autofocus: true,
          decoration: InputDecoration(hintText: Platform.isWindows
            ? 'example.exe' : 'com.example.app')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text(widget.controller.t('Hủy','Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, input.text.trim()),
            child: Text(widget.controller.t('Thêm','Add'))),
        ],
      ),
    );
    if (!mounted || process == null || process.isEmpty) return;
    if (!AppController.validProcessName(process)) {
      setState(() { error = widget.controller.t(
        'Tên process không hợp lệ', 'Invalid process name'); });
      return;
    }
    await toggleExclusion(process, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final selected = excluded;
    final rules = profiles;
    final names = <String>{...running, ...selected, ...rules.keys}.toList()
      ..sort((a,b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final matches = names.where((name) =>
      name.toLowerCase().contains(query.toLowerCase().trim())).toList();

    return PageFrame(
      controller: c,
      title: c.t('Ứng dụng & process','Apps & processes'),
      subtitle: c.t('Quản lý ứng dụng ngay tại giao diện chính.',
        'Manage applications directly in the main window.'),
      child: Column(children: [
        SurfaceCard(child: Column(children: [
          Row(children: [
            Expanded(child: TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: c.t('Tìm process...', 'Find process...')),
            )),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: c.t('Quét lại', 'Refresh'),
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded)),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: Platform.isWindows || Platform.isMacOS ? addProcess : null,
              icon: const Icon(Icons.add_rounded),
              label: Text(c.t('Thêm tên','Add name'))),
          ]),
          const Divider(height: 15),
          PreferenceSwitch(
            title: c.t('Bật chế độ riêng theo ứng dụng','Enable per-app profiles'),
            subtitle: c.t('English / Vietnamese / Balanced',
              'English / Vietnamese / Balanced'),
            value: c.profilesEnabled,
            onChanged: (value) { c.profilesEnabled = value; c.save(); }),
          if (error != null) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
        ])),
        const SizedBox(height: 10),
        Expanded(child: SurfaceCard(padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.apps_rounded, color: teal, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(c.t('PROCESS ĐANG CHẠY','RUNNING PROCESSES'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              if (refreshing) const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
              Text(matches.length.toString(),
                style: const TextStyle(color: muted)),
            ]),
            const Divider(height: 14),
            Expanded(child: !(Platform.isWindows || Platform.isMacOS)
              ? Center(child: Text(c.t('Chưa hỗ trợ chọn process trên Linux.',
                  'Linux process selection is not available yet.')))
              : matches.isEmpty
                ? Center(child: Text(c.t('Không tìm thấy process. Hãy quét lại hoặc thêm tên.',
                    'No process found. Refresh or add a name.')))
                : ListView.separated(
                  itemCount: matches.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final process = matches[index];
                    return Row(children: [
                      const Icon(Icons.window_rounded, color: teal, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(process, overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 112, child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(c.t('Bỏ qua','Ignore'),
                          style: const TextStyle(fontSize: 11)),
                        value: selected.any((name) =>
                          name.toLowerCase() == process.toLowerCase()),
                        onChanged: (v) => toggleExclusion(process, v ?? false))),
                      const SizedBox(width: 6),
                      SizedBox(width: 132, child: DropdownButton<String>(
                        isExpanded: true,
                        value: rules[process.toLowerCase()] ?? 'Default',
                        underline: const SizedBox.shrink(),
                        items: ['Default','English','Vietnamese','Balanced'].map(
                          (value) => DropdownMenuItem(value: value,
                            child: Text(value, style: const TextStyle(fontSize: 11)))).toList(),
                        onChanged: (v) {
                          if (v != null) changeProfile(process, v);
                        })),
                    ]);
                  })),
          ]))),
        const SizedBox(height: 8),
        Text(c.t('Chỉ đọc tên process, không đọc nội dung cửa sổ hoặc lịch sử gõ.',
          'Only process names are read, never window contents or typed text.'),
          style: const TextStyle(color: muted, fontSize: 11)),
      ]),
    );
  }
}
