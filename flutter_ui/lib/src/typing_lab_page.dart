import 'package:flutter/material.dart';

import 'controller.dart';
import 'widgets.dart';

// These are expected outputs of the portable C++ composer, checked against
// the native oracle with the bundled English and Vietnamese dictionaries.
// Priority English still composes Vietnamese terms that are not recognized
// English words. It is NOT the literal E switch.
class LabCase {
  const LabCase(this.typed, this.expected, this.noteVi, this.noteEn);
  final String typed, expected, noteVi, noteEn;
  String note(AppController c) => c.t(noteVi, noteEn);
}

class LabModeCases {
  static const examples = <String, List<LabCase>>{
    'Balanced': [
      LabCase('w', 'ư', 'Phím w Telex', 'Standalone Telex w'),
      LabCase('now', 'nơ', 'Từ tiếng Việt nơ', 'Vietnamese nơ'),
      LabCase('tieengs', 'tiếng', 'Dấu sắc đúng vị trí', 'Tone placement'),
      LabCase('chayj', 'chạy', 'Dấu nặng với j', 'Tone j'),
      LabCase('boons', 'bốn', 'Phân biệt tiếng Việt', 'Vietnamese composition'),
      LabCase(
        'been',
        'bên',
        'Cân bằng ưu tiên nghĩa tiếng Việt',
        'Vietnamese in balanced mode',
      ),
      LabCase(
        'boost',
        'boost',
        'Giữ từ tiếng Anh quen thuộc',
        'Protect known English',
      ),
      LabCase(
        'parameter',
        'parameter',
        'Giữ thuật ngữ kỹ thuật',
        'Software vocabulary',
      ),
      LabCase('exe', 'exe', 'Giữ từ tiếng Anh ngắn', 'English executable term'),
      LabCase('ddang', 'đang', 'Gõ đ bằng dd', 'Double d'),
    ],
    'Vietnamese': [
      LabCase('w', 'ư', 'Gõ ư trực tiếp', 'Standalone w'),
      LabCase('now', 'nơ', 'Ưu tiên từ Việt', 'Vietnamese word'),
      LabCase(
        'been',
        'bên',
        'Giữ cách hiểu tiếng Việt',
        'Vietnamese over English',
      ),
      LabCase(
        'boost',
        'bốt',
        'Ưu tiên chuyển đổi tiếng Việt',
        'Vietnamese first changes boost',
      ),
      LabCase('boons', 'bốn', 'Telex đầy đủ', 'Vietnamese Telex'),
      LabCase('chayj', 'chạy', 'Dấu nặng', 'Low tone'),
      LabCase('tieengs', 'tiếng', 'Dấu sắc', 'Acute tone'),
      LabCase('ddang', 'đang', 'Chữ đ', 'Vietnamese đ'),
    ],
    'English': [
      LabCase(
        'w',
        'ư',
        'Telex vẫn hoạt động khi ở V',
        'V mode still composes Telex',
      ),
      LabCase('now', 'now', 'Giữ từ tiếng Anh', 'Preserve known English'),
      LabCase(
        'been',
        'been',
        'Ưu tiên từ tiếng Anh đã biết',
        'English word first',
      ),
      LabCase(
        'boost',
        'boost',
        'Giữ nguyên thuật ngữ',
        'Preserve English term',
      ),
      LabCase(
        'boons',
        'bốn',
        'Từ không được nhận là tiếng Anh',
        'Unrecognized words may still compose',
      ),
      LabCase(
        'parameter',
        'parameter',
        'Từ kỹ thuật tiếng Anh',
        'Technical vocabulary',
      ),
      LabCase('exe', 'exe', 'Từ vựng phần mềm', 'Software vocabulary'),
      LabCase(
        'ddang',
        'đang',
        'Telex vẫn gõ tiếng Việt',
        'Vietnamese still available',
      ),
    ],
  };

  static List<LabCase> forMode(String mode) =>
      examples[mode] ?? examples['Balanced']!;
}

class TypingLabPage extends StatefulWidget {
  const TypingLabPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<TypingLabPage> createState() => _TypingLabPageState();
}

class _TypingLabPageState extends State<TypingLabPage> {
  final field = TextEditingController();
  final results = <int, bool>{};
  int index = 0;
  String hint = '';
  String shownMode = 'Balanced';
  DateTime? started;
  Duration? elapsed;

  @override
  void initState() {
    super.initState();
    shownMode = widget.controller.languagePriority;
    widget.controller.addListener(_onModeChanged);
  }

  void _onModeChanged() {
    final mode = widget.controller.languagePriority;
    if (!mounted || shownMode == mode) return;
    shownMode = mode;
    setState(() {
      index = 0;
      results.clear();
      field.clear();
      hint = '';
      started = null;
      elapsed = null;
    });
  }

  @override
  void didUpdateWidget(TypingLabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onModeChanged);
      shownMode = widget.controller.languagePriority;
      widget.controller.addListener(_onModeChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onModeChanged);
    field.dispose();
    super.dispose();
  }

  void check() {
    final items = LabModeCases.forMode(widget.controller.languagePriority);
    final ok = field.text.trim() == items[index].expected;
    setState(() {
      results[index] = ok;
      elapsed = started == null ? null : DateTime.now().difference(started!);
      hint = ok
          ? widget.controller.t('Đạt', 'Pass')
          : widget.controller.t(
              'Chưa đúng kết quả mong đợi',
              'Does not match expected output',
            );
    });
  }

  void choose(int next) {
    setState(() {
      index = next;
      field.clear();
      hint = '';
      started = null;
      elapsed = null;
    });
  }

  Future<void> selectPriority(String priority) async {
    if (priority == widget.controller.languagePriority) return;
    try {
      await widget.controller.setLanguagePriority(priority);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.t(
              'Không chuyển được chế độ ưu tiên. Hãy thử lại.',
              'Could not switch priority. Please retry.',
            ),
          ),
        ),
      );
    }
  }

  String _label(String mode, AppController c) => switch (mode) {
    'Vietnamese' => c.t('Ưu tiên Việt', 'Vietnamese first'),
    'English' => c.t('Ưu tiên Anh', 'English first'),
    _ => 'Balanced',
  };

  String _explanation(String mode, AppController c) => switch (mode) {
    'Vietnamese' => c.t(
      'Tập trung chuyển Telex thành chữ Việt.',
      'Favor Vietnamese Telex output.',
    ),
    'English' => c.t(
      'Giữ nguyên từ tiếng Anh đã biết, vẫn gõ Việt được.',
      'Preserve known English; Vietnamese composition still works.',
    ),
    _ => c.t(
      'Cân bằng nhận diện tiếng Anh và tiếng Việt.',
      'Balance English protection and Vietnamese composition.',
    ),
  };

  Widget _comparisonCards(AppController c) => LayoutBuilder(
    builder: (context, space) {
      final wide = space.maxWidth >= 740;
      final width = wide ? (space.maxWidth - 16) / 3 : space.maxWidth;
      final modes = <String>['Balanced', 'Vietnamese', 'English'];
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final mode in modes)
            SizedBox(
              width: width,
              child: InkWell(
                key: Key('lab-mode-card-$mode'),
                borderRadius: BorderRadius.circular(13),
                onTap: () => selectPriority(mode),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: c.languagePriority == mode
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: c.languagePriority == mode
                          ? teal
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: c.languagePriority == mode ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            mode == 'Balanced'
                                ? Icons.tune_rounded
                                : mode == 'Vietnamese'
                                ? Icons.translate_rounded
                                : Icons.menu_book_rounded,
                            size: 17,
                            color: teal,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _label(mode, c),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (c.languagePriority == mode)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: teal,
                              size: 17,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _explanation(mode, c),
                        style: const TextStyle(fontSize: 10.5, color: muted),
                      ),
                      const SizedBox(height: 6),
                      for (final example
                          in mode == 'Vietnamese'
                              ? <LabCase>[
                                  const LabCase('been', 'bên', '', ''),
                                  const LabCase('boost', 'bốt', '', ''),
                                ]
                              : mode == 'English'
                              ? <LabCase>[
                                  const LabCase('been', 'been', '', ''),
                                  const LabCase('now', 'now', '', ''),
                                ]
                              : <LabCase>[
                                  const LabCase('been', 'bên', '', ''),
                                  const LabCase('boost', 'boost', '', ''),
                                ])
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '${example.typed}  →  ${example.expected}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final mode = c.languagePriority;
    final items = LabModeCases.forMode(mode);
    final sample = items[index.clamp(0, items.length - 1)];
    final passed = results.values.where((v) => v).length;

    return PageFrame(
      controller: c,
      title: 'Typing Lab',
      subtitle: c.t(
        'Kiểm tra đầu ra thực tế theo 3 chế độ; không lưu nội dung bạn gõ.',
        'Test actual input across all 3 priorities; typed text is not logged.',
      ),
      child: SingleChildScrollView(
        key: const Key('typing-lab-scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: teal, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.t(
                            'Chọn chế độ ưu tiên · áp dụng cả ứng dụng',
                            'Choose priority · applies across the app',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  LanguagePrioritySelector(controller: c),
                  const SizedBox(height: 11),
                  _comparisonCards(c),
                  const SizedBox(height: 7),
                  Text(
                    c.t(
                      'Ba chế độ trên hoạt động khi bật V. Chế độ E vẫn giữ nguyên mọi ký tự; ví dụ giả định đang chọn Telex.',
                      'These priorities work with V enabled. E always types literal keys; examples assume Telex.',
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
                      const Icon(Icons.keyboard_alt_outlined, color: teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${c.t('Bài thử', 'Typing test')} · ${_label(mode, c)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      Text(
                        '$passed/${items.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: results.length / items.length,
                    backgroundColor: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.t('Chuỗi phím cần gõ', 'Physical keys to type'),
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  SelectableText(
                    sample.typed,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.t('Kết quả mong đợi', 'Expected result'),
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  Text(
                    sample.expected,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sample.note(c),
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 13),
                  TextField(
                    key: const Key('typing-lab-input'),
                    controller: field,
                    onChanged: (value) {
                      if (started == null && value.isNotEmpty) {
                        started = DateTime.now();
                      }
                      if (hint.isNotEmpty) setState(() => hint = '');
                    },
                    decoration: InputDecoration(
                      hintText: c.t('Gõ thử tại đây', 'Type in this field'),
                      helperText: c.t(
                        'Bật V và chọn Telex để so sánh với kết quả mong đợi.',
                        'Use V and Telex to compare the expected output.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const Key('typing-lab-check'),
                        onPressed: check,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(c.t('Kiểm tra', 'Check')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => choose(index),
                        icon: const Icon(Icons.restart_alt),
                        label: Text(c.t('Thử lại', 'Retry')),
                      ),
                      OutlinedButton.icon(
                        key: const Key('typing-lab-next'),
                        onPressed: () => choose((index + 1) % items.length),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(c.t('Bài tiếp', 'Next case')),
                      ),
                    ],
                  ),
                  if (hint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        hint,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: results[index] == true
                              ? teal
                              : Colors.deepOrange,
                        ),
                      ),
                    ),
                  if (elapsed != null)
                    Text(
                      '${c.t('Thời gian thao tác: ', 'Attempt duration: ')}${elapsed!.inMilliseconds} ms',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    c.t(
                      'Tình huống thử theo chế độ đang chọn',
                      'Scenarios for the selected priority',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        ActionChip(
                          key: Key('typing-lab-case-$i'),
                          backgroundColor: results[i] == true
                              ? const Color(0xFFE0F7EC)
                              : null,
                          avatar: Icon(
                            results[i] == true
                                ? Icons.check_circle
                                : results[i] == false
                                ? Icons.error_outline
                                : Icons.keyboard,
                            size: 16,
                            color: results[i] == true ? teal : muted,
                          ),
                          label: Text(items[i].typed),
                          onPressed: () => choose(i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.t(
                      'Kiểm tra bằng tay trên ô nhập thật; không phải phép đo p95/p99 của bàn phím.',
                      'Manual editable-field checks, not keyboard p95/p99 latency measurements.',
                    ),
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
