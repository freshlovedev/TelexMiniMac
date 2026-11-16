import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'widgets.dart';
import 'backup_service.dart';
import 'release_service.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  bool running = false;
  String outcome = '';
  String backupInfo = '';
  String releaseInfo = '';
  bool releaseChecking = false;
  String? latestReleaseUrl;
  Duration? bridgeLatency;
  double? hookAverageMs;
  double? hookMaximumMs;
  double? hookP95Ms;
  double? hookP99Ms;
  int? hookSamples;
  int? focusProbeFailures;
  int? classificationBypasses;
  int? replacementFailures;
  int? externallyInjectedKeys;
  int? stableFocusRefreshes;
  int? processCount;
  bool? detectedMode;
  bool? connected;
  List<File> backups = [];
  String? selectedBackupPath;

  File? get selectedBackup {
    if (backups.isEmpty) return null;
    for (final f in backups) {
      if (f.path == selectedBackupPath) return f;
    }
    return backups.first;
  }

  @override
  void initState() {
    super.initState();
    refreshBackups();
  }

  Future<void> refreshBackups() async {
    try {
      final files = await BackupService.list();
      if (mounted) setState(() => backups = files);
    } catch (e) {
      if (mounted) setState(() => backupInfo = '$e');
    }
  }

  Future<void> readHookDiagnostics() async {
    if (!Platform.isWindows ||
        widget.controller.settingsDirectoryOverride != null) {
      return;
    }
    final root = Platform.environment['LOCALAPPDATA'];
    if (root == null) return;
    final folder = Directory('$root/TelexMini');
    final response = File('${folder.path}/diagnostics.metrics');
    final request = File('${folder.path}/diagnostics.request');
    try {
      await folder.create(recursive: true);
      if (await response.exists()) await response.delete();
      await request.writeAsString('1', flush: true);
      for (var attempt = 0; attempt < 15; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 75));
        if (!await response.exists()) continue;
        final parts = (await response.readAsString()).trim().split('\t');
        await response.delete();
        if (parts.length >= 3 && mounted) {
          setState(() {
            hookSamples = int.tryParse(parts[0]);
            hookAverageMs = double.tryParse(parts[1]);
            hookMaximumMs = double.tryParse(parts[2]);
            hookP95Ms = parts.length >= 5 ? double.tryParse(parts[3]) : null;
            hookP99Ms = parts.length >= 5 ? double.tryParse(parts[4]) : null;
            focusProbeFailures = parts.length >= 6
                ? int.tryParse(parts[5])
                : null;
            classificationBypasses = parts.length >= 7
                ? int.tryParse(parts[6])
                : null;
            replacementFailures = parts.length >= 8
                ? int.tryParse(parts[7])
                : null;
            externallyInjectedKeys = parts.length >= 9
                ? int.tryParse(parts[8])
                : null;
            stableFocusRefreshes = parts.length >= 10
                ? int.tryParse(parts[9])
                : null;
          });
        }
        break;
      }
    } catch (_) {
      // Diagnostics cannot interfere with regular text input.
    }
  }

  Future<void> diagnose() async {
    if (running) return;
    setState(() {
      running = true;
      outcome = '';
    });
    const channel = MethodChannel('com.telexmini/control');
    try {
      final sw = Stopwatch()..start();
      final status = await channel.invokeMapMethod<String, dynamic>(
        'getStatus',
      );
      sw.stop();
      final processes = await widget.controller.runningProcesses();
      await readHookDiagnostics();
      if (mounted) {
        setState(() {
          bridgeLatency = sw.elapsed;
          connected = status != null;
          detectedMode = status?['vietnameseEnabled'] == true;
          processCount = processes.length;
          outcome = widget.controller.t(
            'Chẩn đoán xong. Chỉ đo kết nối và trạng thái, không ghi phím.',
            'Diagnostics complete. Connection and state only; no keystrokes recorded.',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          connected = false;
          outcome = '$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => running = false);
      }
    }
  }

  Future<void> export() async {
    try {
      final file = await BackupService.create(widget.controller);
      await refreshBackups();
      if (mounted) {
        setState(
          () => backupInfo =
              widget.controller.t('Đã sao lưu tại: ', 'Saved to: ') + file.path,
        );
      }
    } catch (e) {
      if (mounted) setState(() => backupInfo = '$e');
    }
  }

  Future<void> importLatest() async {
    if (backups.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          widget.controller.t('Khôi phục cấu hình?', 'Restore configuration?'),
        ),
        content: Text(
          widget.controller.t(
            'Dữ liệu hiện tại sẽ được sao lưu trước, rồi thay bằng bản sao lưu gần nhất. Chỉ sử dụng tập tin do chính TelexMini tạo.',
            'Current configuration will be backed up first, then the latest backup will be restored. Only use files created by TelexMini.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.controller.t('Hủy', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.controller.t('Khôi phục', 'Restore')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final selected = selectedBackup;
      if (selected == null) return;
      await BackupService.create(widget.controller);
      await BackupService.restore(widget.controller, selected);
      await refreshBackups();
      if (mounted) {
        setState(
          () => backupInfo =
              widget.controller.t('Đã khôi phục: ', 'Restored: ') +
              selected.path,
        );
      }
    } catch (e) {
      if (mounted) setState(() => backupInfo = '$e');
    }
  }

  Future<void> deleteSelectedBackup() async {
    final selected = selectedBackup;
    if (selected == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          widget.controller.t('Xóa bản sao lưu này?', 'Delete this backup?'),
        ),
        content: Text(selected.path),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.controller.t('Hủy', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.controller.t('Xóa', 'Delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final known = (await BackupService.list()).any(
        (f) => f.path == selected.path,
      );
      if (!known) {
        throw const FileSystemException(
          'Backup is not in the known local history',
        );
      }
      await selected.delete();
      selectedBackupPath = null;
      await refreshBackups();
      if (mounted) {
        setState(
          () => backupInfo = widget.controller.t(
            'Đã xóa bản sao lưu đã chọn.',
            'Selected backup deleted.',
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => backupInfo = e.toString());
    }
  }

  Future<void> checkRelease() async {
    if (releaseChecking) return;
    setState(() {
      releaseChecking = true;
      releaseInfo = '';
    });
    try {
      final release = await ReleaseService.check();
      if (mounted) {
        setState(() {
          latestReleaseUrl = release.url;
          releaseInfo = release.newer
              ? widget.controller.t('Có bản mới: ', 'Update available: ') +
                    release.tag
              : widget.controller.t(
                      'Không có bản mới hơn. Phiên bản gần nhất: ',
                      'No newer version. Latest release: ',
                    ) +
                    release.tag;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => releaseInfo =
              widget.controller.t(
                'Không thể kiểm tra bản phát hành: ',
                'Unable to check releases: ',
              ) +
              e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => releaseChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return PageFrame(
      controller: c,
      title: c.t('Chẩn đoán & Sao lưu', 'Diagnostics & Backup'),
      subtitle: c.t(
        'Kiểm tra kết nối bộ gõ mà không thu thập nội dung đã nhập.',
        'Inspect input engine connectivity without recording typed content.',
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bug_report_rounded, color: teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.t('Input Diagnostics', 'Input Diagnostics'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: running ? null : diagnose,
                        icon: const Icon(Icons.refresh),
                        label: Text(c.t('Kiểm tra', 'Run diagnostics')),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Wrap(
                    spacing: 13,
                    runSpacing: 13,
                    children: [
                      _info(
                        c.t('Chế độ', 'Mode'),
                        c.vietnameseEnabled ? 'V · Vietnamese' : 'E · English',
                        Icons.keyboard_alt_rounded,
                      ),
                      _info(
                        c.t('Kiểu gõ', 'Input method'),
                        c.inputMethod,
                        Icons.translate,
                      ),
                      _info(
                        c.t('Kết nối Native', 'Native bridge'),
                        connected == null
                            ? c.t('Chưa kiểm tra', 'Not checked')
                            : (connected! ? 'Connected' : 'Disconnected'),
                        Icons.link_rounded,
                      ),
                      _info(
                        c.t('Thời gian gọi bridge', 'Bridge round trip'),
                        bridgeLatency == null
                            ? '—'
                            : '${bridgeLatency!.inMicroseconds / 1000.0} ms',
                        Icons.speed,
                      ),
                      _info(
                        c.t('Process phát hiện', 'Detected processes'),
                        processCount?.toString() ?? '—',
                        Icons.apps_outlined,
                      ),
                      _info(
                        c.t('Hook trung bình', 'Average hook callback'),
                        hookAverageMs == null
                            ? '—'
                            : '${hookAverageMs!.toStringAsFixed(3)} ms',
                        Icons.speed,
                      ),
                      _info(
                        c.t('Hook tối đa', 'Maximum callback'),
                        hookMaximumMs == null
                            ? '—'
                            : '${hookMaximumMs!.toStringAsFixed(3)} ms',
                        Icons.speed,
                      ),
                      _info(
                        'Hook p95',
                        hookP95Ms == null
                            ? '—'
                            : '${hookP95Ms!.toStringAsFixed(3)} ms',
                        Icons.show_chart_rounded,
                      ),
                      _info(
                        'Hook p99',
                        hookP99Ms == null
                            ? '—'
                            : '${hookP99Ms!.toStringAsFixed(3)} ms',
                        Icons.show_chart_rounded,
                      ),
                      _info(
                        c.t('Số mẫu phím vật lý', 'Physical key samples'),
                        hookSamples?.toString() ?? '—',
                        Icons.grid_view_rounded,
                      ),
                      _info(
                        c.t(
                          'Không xác định được ô nhập',
                          'Focus probe failures',
                        ),
                        focusProbeFailures?.toString() ?? '—',
                        Icons.info_outline,
                      ),
                      _info(
                        c.t('Chờ phân loại ô nhập', 'Context pending bypasses'),
                        classificationBypasses?.toString() ?? '—',
                        Icons.security_rounded,
                      ),
                      _info(
                        c.t('Thay ký tự thất bại', 'Replacement failures'),
                        replacementFailures?.toString() ?? '—',
                        Icons.warning_amber_rounded,
                      ),
                      _info(
                        c.t(
                          'Phím từ công cụ khác',
                          'External injected key events',
                        ),
                        externallyInjectedKeys?.toString() ?? '—',
                        Icons.input_rounded,
                      ),
                      _info(
                        c.t(
                          'Làm mới ô nhập không reset',
                          'Safe focus refreshes',
                        ),
                        stableFocusRefreshes?.toString() ?? '—',
                        Icons.check_circle_outline,
                      ),
                    ],
                  ),
                  if (outcome.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        outcome,
                        style: const TextStyle(color: muted),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    c.t(
                      'Bộ đếm chỉ tăng từ lúc mở engine; không lưu phím, từ gõ, tên ứng dụng hay nội dung cửa sổ. Nếu chữ Telex bị giữ nguyên, hãy chạy Chẩn đoán và kiểm tra bộ đếm Chờ phân loại, Thay ký tự thất bại, Phím từ công cụ khác. p95/p99 chỉ đo callback, không phải độ trễ phím-đến-màn hình.',
                      'Counters reset when the engine restarts; no keys, words, app names or window contents are recorded. If Telex remains literal, check pending context, failed replacements and injected keys. p95/p99 are callback times, not end-to-end input latency.',
                    ),
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.backup_outlined, color: teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.t('Sao lưu & Khôi phục', 'Backup & Restore'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.t(
                      'Lưu cấu hình, từ điển, gõ tắt và hồ sơ ứng dụng vào JSON trên máy. Bản sao lưu có thể chứa văn bản gõ tắt, hãy bảo vệ thư mục này.',
                      'Save settings, dictionaries, snippets and app profiles as local JSON. Backups may contain snippet values, so protect this folder.',
                    ),
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: export,
                        icon: const Icon(Icons.save_alt),
                        label: Text(c.t('Tạo bản sao lưu', 'Create backup')),
                      ),
                      OutlinedButton.icon(
                        onPressed: backups.isEmpty ? null : importLatest,
                        icon: const Icon(Icons.settings_backup_restore),
                        label: Text(
                          c.t('Khôi phục bản đã chọn', 'Restore selected'),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: backups.isEmpty
                            ? null
                            : deleteSelectedBackup,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(c.t('Xóa bản đã chọn', 'Delete selected')),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    c.t('Các bản sao lưu', 'Local backups'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (backups.isEmpty)
                    Text(
                      c.t('Chưa có bản sao lưu.', 'No backups yet.'),
                      style: const TextStyle(color: muted),
                    )
                  else
                    ...backups
                        .take(15)
                        .map(
                          (f) => ListTile(
                            dense: true,
                            selected: selectedBackup?.path == f.path,
                            selectedTileColor: teal.withValues(alpha: 0.08),
                            onTap: () =>
                                setState(() => selectedBackupPath = f.path),
                            leading: Icon(
                              selectedBackup?.path == f.path
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: teal,
                            ),
                            title: Text(f.uri.pathSegments.last),
                            subtitle: Text(
                              f.parent.path,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  if (backupInfo.isNotEmpty)
                    SelectableText(
                      backupInfo,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.system_update_alt_rounded, color: teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.t('Kiểm tra cập nhật', 'Software updates'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.t('Bản đang sử dụng: ', 'Installed version: ') +
                        ReleaseService.currentVersion,
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      OutlinedButton.icon(
                        onPressed: releaseChecking ? null : checkRelease,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          c.t('Kiểm tra bản mới', 'Check for updates'),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await ReleaseService.openReleases(
                              latestReleaseUrl ?? ReleaseService.releasesUrl,
                            );
                          } catch (e) {
                            if (mounted) {
                              setState(() => releaseInfo = e.toString());
                            }
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: Text(c.t('Xem bản phát hành', 'View releases')),
                      ),
                    ],
                  ),
                  if (releaseInfo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        releaseInfo,
                        style: const TextStyle(color: muted),
                      ),
                    ),
                  const SizedBox(height: 7),
                  Text(
                    c.t(
                      'Chỉ kiểm tra theo yêu cầu, không tự cài bản tải về chưa xác minh.',
                      'Checks only on request; never executes unverified downloaded installers.',
                    ),
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String title, String value, IconData icon) => SizedBox(
    width: 215,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: teal, size: 18),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontSize: 11, color: muted)),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}
