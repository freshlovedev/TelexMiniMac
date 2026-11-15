import 'package:flutter/material.dart';
import 'controller.dart';

const teal = Color(0xFF009189);
const ink = Color(0xFF182B3E);
const muted = Color(0xFF6B8195);
const pageBg = Color(0xFFF6F9FC);

// Two opposing rounded arrows represent instantaneous Vietnamese / English
// switching. The mark is drawn as geometry, never as a generic letter glyph.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: CustomPaint(painter: _BilingualMarkPainter()),
  );
}

class _BilingualMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final square = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF08BBA9), Color(0xFF1675B5)],
      ).createShader(square);
    canvas.drawRRect(
      RRect.fromRectAndRadius(square.deflate(size.width * .015), Radius.circular(size.width * .26)),
      background,
    );
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * .105
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final forward = Path()
      ..moveTo(size.width * .24, size.height * .35)
      ..lineTo(size.width * .72, size.height * .35)
      ..moveTo(size.width * .58, size.height * .22)
      ..lineTo(size.width * .73, size.height * .35)
      ..lineTo(size.width * .58, size.height * .48);
    canvas.drawPath(forward, line);

    final backward = Path()
      ..moveTo(size.width * .76, size.height * .65)
      ..lineTo(size.width * .28, size.height * .65)
      ..moveTo(size.width * .42, size.height * .52)
      ..lineTo(size.width * .27, size.height * .65)
      ..lineTo(size.width * .42, size.height * .78);
    canvas.drawPath(backward, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      BrandMark(),
      SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('telexmini', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.05)),
        Text('BILINGUAL INPUT', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Color(0xFFB9CDDF), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: .35)),
      ])),
    ],
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.controller, required this.child, this.title, this.subtitle});
  final AppController controller;
  final Widget child;
  final String? title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 15, 22, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TELEXMINI / ${controller.t('BẢNG ĐIỀU KHIỂN', 'WORKSPACE')}',
              style: const TextStyle(color: Color(0xFF66849E), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .35)),
            const SizedBox(height: 3),
            Text(title ?? controller.t('Gõ theo cách của bạn.', 'Type your way.'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.6)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            ],
          ])),
          IconButton.filledTonal(
            tooltip: controller.t('Đổi giao diện sáng/tối','Toggle light/dark theme'),
            onPressed: controller.toggleTheme,
            icon: Icon(controller.darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
        ]),
        const SizedBox(height: 13),
        Expanded(child: child),
      ]),
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(15), this.height});
  final Widget child;
  final EdgeInsets padding;
  final double? height;
  @override
  Widget build(BuildContext context) => Card(
    child: Container(
      height: height,
      padding: padding,
      child: child,
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 1, 0, 7),
    child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: .2)),
  );
}

class PreferenceSwitch extends StatelessWidget {
  const PreferenceSwitch({super.key, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: muted)),
      ])),
      Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: teal, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ],
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon ?? Icons.check_rounded, size: 17),
    label: Text(label),
    style: FilledButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
  );
}
