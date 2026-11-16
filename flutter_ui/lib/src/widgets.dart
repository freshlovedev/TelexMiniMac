import 'package:flutter/material.dart';

import 'controller.dart';
import 'feature_guide.dart';

const teal = Color(0xFF009189);
const ink = Color(0xFF182B3E);
const muted = Color(0xFF6B8195);
const pageBg = Color(0xFFF6F9FC);

// Minimal feather mark: natural Vietnamese typing, not a generic T or arrows.
// Native Windows icon uses the same normalized 1024-unit geometry.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Image.asset(
      'assets/telexmini-icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    ),
  );
}

/// Painted information badge for About, independent of the icon font subset.
/// This avoids a missing glyph in Windows release builds.
class AboutNavMark extends StatelessWidget {
  const AboutNavMark({super.key, this.size = 19, this.color = teal});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('about-nav-mark'),
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: size * .088),
    ),
    child: Text(
      'i',
      style: TextStyle(
        color: color,
        fontSize: size * .72,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    ),
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        const BrandMark(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TelexMini',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dark ? Colors.white : const Color(0xFF102B40),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              Text(
                'BỘ GÕ SONG NGỮ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dark
                      ? const Color(0xFFB9CDDF)
                      : const Color(0xFF638194),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.controller,
    required this.child,
    this.title,
    this.subtitle,
    this.titleIcon,
  });
  final AppController controller;
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? titleIcon;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 15, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titleIcon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: titleIcon!,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TELEXMINI / ${controller.t('BẢNG ĐIỀU KHIỂN', 'WORKSPACE')}',
                      style: const TextStyle(
                        color: Color(0xFF66849E),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title ??
                          controller.t(
                            'Gõ theo cách của bạn.',
                            'Type your way.',
                          ),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.6,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: controller.t(
                  'Thu gọn/mở rộng sidebar',
                  'Collapse/expand sidebar',
                ),
                onPressed: controller.toggleCompactSidebar,
                icon: Icon(
                  controller.compactSidebar
                      ? Icons.menu_rounded
                      : Icons.menu_rounded,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: controller.t(
                  'Đóng giao diện · bộ gõ vẫn chạy',
                  'Close settings · keep typing engine running',
                ),
                onPressed: controller.closeSettingsWindow,
                icon: const Icon(Icons.close_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: controller.t(
                  'Đổi giao diện sáng/tối',
                  'Toggle light/dark theme',
                ),
                onPressed: controller.toggleTheme,
                icon: Icon(
                  controller.darkMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (controller.page != AppPage.about)
            FeatureGuide(controller: controller, page: controller.page),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.height,
  });
  final Widget child;
  final EdgeInsets padding;
  final double? height;
  @override
  Widget build(BuildContext context) => Card(
    child: Container(height: height, padding: padding, child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 1, 0, 7),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        letterSpacing: .2,
      ),
    ),
  );
}

class PreferenceSwitch extends StatelessWidget {
  const PreferenceSwitch({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ),
      Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: teal,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ],
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon ?? Icons.check_rounded, size: 17),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: teal,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
  );
}

/// Same three input-priority modes on Overview, Typing Lab and Settings.
/// This controls how V mode resolves ambiguity; E remains literal English.
class LanguagePrioritySelector extends StatelessWidget {
  const LanguagePrioritySelector({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    const values = <String>['Balanced', 'Vietnamese', 'English'];
    const icons = <IconData>[
      Icons.tune_rounded,
      Icons.translate_rounded,
      Icons.menu_book_rounded,
    ];
    final labels = <String>[
      'Balanced',
      controller.t('Ưu tiên Việt', 'Vietnamese first'),
      controller.t('Ưu tiên Anh', 'English first'),
    ];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 7,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < values.length; i++)
          ChoiceChip(
            key: Key('priority-${values[i]}'),
            avatar: Icon(
              icons[i],
              size: 17,
              color: controller.languagePriority == values[i]
                  ? (dark ? const Color(0xFFBAF7EA) : const Color(0xFF006E68))
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            label: Text(
              labels[i],
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            selected: controller.languagePriority == values[i],
            selectedColor: dark
                ? const Color(0xFF195D60)
                : const Color(0xFFC9EEE7),
            showCheckmark: false,
            onSelected: (_) async {
              try {
                await controller.setLanguagePriority(values[i]);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        controller.t(
                          'Không lưu được chế độ ưu tiên. Hãy thử lại.',
                          'Could not save input priority. Please retry.',
                        ),
                      ),
                    ),
                  );
                }
              }
            },
          ),
      ],
    );
  }
}
