import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'release_service.dart';
import 'widgets.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const supportUrl = 'https://ygometa.me';
  bool opening = false;

  Future<void> openSupportSite() async {
    if (opening) return;
    setState(() => opening = true);
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [
          supportUrl,
        ], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', [
          supportUrl,
        ], mode: ProcessStartMode.detached);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [
          supportUrl,
        ], mode: ProcessStartMode.detached);
      } else {
        throw UnsupportedError('Unsupported desktop platform');
      }
    } catch (_) {
      if (!mounted) return;
      // Let users open the exact address manually if the OS handler is missing.
      await Clipboard.setData(const ClipboardData(text: supportUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.controller.t(
                'Chưa mở được trình duyệt. Đã sao chép địa chỉ ygometa.me để bạn tự dán.',
                'Could not open the browser. ygometa.me was copied for manual use.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final dark = c.darkMode;
    return PageFrame(
      controller: c,
      titleIcon: const AboutNavMark(size: 25),
      title: c.t('Giới thiệu TelexMini', 'About TelexMini'),
      subtitle: c.t(
        'Một công cụ nhỏ, bắt đầu từ những lần gõ chưa như ý.',
        'A little typing tool born from everyday frustrations.',
      ),
      child: LayoutBuilder(
        builder: (context, space) => SingleChildScrollView(
          key: const Key('about-scroll'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1260),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(21),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    gradient: LinearGradient(
                      colors: dark
                          ? const [Color(0xFF08665F), Color(0xFF123D59)]
                          : const [Color(0xFF00877E), Color(0xFF286C92)],
                    ),
                  ),
                  child: Wrap(
                    spacing: 15,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const BrandMark(size: 57),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TelexMini',
                            style: TextStyle(
                              fontSize: 29,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            c.t(
                              'Bộ gõ song ngữ · Nhỏ gọn · Riêng tư',
                              'Bilingual typing · Lightweight · Private',
                            ),
                            style: const TextStyle(
                              color: Color(0xFFDBF5F3),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${c.t('Phiên bản', 'Version')} ${ReleaseService.currentVersion}',
                            style: const TextStyle(
                              color: Color(0xFFDBF5F3),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, layout) {
                    final columnWidth = layout.maxWidth >= 850
                        ? (layout.maxWidth - 12) / 2
                        : layout.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: columnWidth,
                          child: SurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _heading(
                                  Icons.favorite_border_rounded,
                                  c.t(
                                    'Vì sao tôi tạo TelexMini?',
                                    'Why I built TelexMini',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  c.t(
                                    'TelexMini ra đời sau rất nhiều lần tôi cảm thấy chưa hài lòng với trải nghiệm gõ tiếng Việt của mình. Có lúc đang viết tiếng Việt lại phải sửa dấu; có lúc xen một từ tiếng Anh, tên phần mềm hoặc đoạn mã thì bộ gõ hiểu nhầm. Những lần chuyển qua lại, xóa đi gõ lại tuy nhỏ nhưng đủ làm đứt mạch suy nghĩ.',
                                    'TelexMini began after many occasions when I felt dissatisfied with my own Vietnamese typing experience. Sometimes a Vietnamese word needed correction; other times an English term, app name or code snippet was interpreted as Vietnamese. Those small interruptions broke my flow.',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.55,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  c.t(
                                    'Tôi biết các bộ gõ khác có nhiều điểm mạnh và mỗi người có cách dùng khác nhau. Nhưng sau khi thử và điều chỉnh nhiều lần mà vẫn chưa tìm được cách làm việc thật tự nhiên cho mình, tôi quyết định tự xây dựng một công cụ: ưu tiên gõ đúng ngay khi nhấn phím, hiểu được ngữ cảnh Anh–Việt và để người dùng tự kiểm soát mọi tùy chọn.',
                                    'Other input methods have their strengths, and everyone types differently. After trying and adjusting different setups without finding the experience I wanted, I decided to create my own: immediate composition, better Vietnamese–English handling and controls that remain in the user’s hands.',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: SurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _heading(
                                  Icons.auto_awesome_outlined,
                                  c.t(
                                    'Những khó khăn tôi muốn giải quyết',
                                    'Problems I wanted to solve',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _benefit(
                                  Icons.translate_rounded,
                                  c.t(
                                    'Gõ tiếng Việt xen tiếng Anh',
                                    'Mixed Vietnamese and English',
                                  ),
                                  c.t(
                                    'Ví dụ: “been” nên hiểu là “bên” trong ngữ cảnh Việt, nhưng “boost” hoặc “parameter” phải được giữ nguyên.',
                                    'For example, “been” may mean “bên” in Vietnamese, while “boost” and “parameter” should stay untouched.',
                                  ),
                                ),
                                _benefit(
                                  Icons.bolt_rounded,
                                  c.t(
                                    'Dấu xuất hiện đúng lúc',
                                    'Marks appear as you type',
                                  ),
                                  c.t(
                                    'Hạn chế việc chờ tới cuối từ, đổi dấu muộn hoặc phải sửa đi sửa lại trong lúc đang nghĩ.',
                                    'Reduce delayed marks, unexpected composition and repetitive corrections.',
                                  ),
                                ),
                                _benefit(
                                  Icons.shield_outlined,
                                  c.t(
                                    'Riêng tư, cấu hình dễ hiểu',
                                    'Privacy and simple settings',
                                  ),
                                  c.t(
                                    'Gõ và xử lý văn bản offline, không cần tài khoản; trên Windows bộ gõ chạy theo quyền người dùng, không yêu cầu UAC cho việc sử dụng thông thường.',
                                    'Typing and text tools work offline, without an account. Normal Windows use runs under user privileges without an administrator prompt.',
                                  ),
                                ),
                                _benefit(
                                  Icons.tune_rounded,
                                  c.t(
                                    'Đủ linh hoạt theo thói quen',
                                    'Fits different workflows',
                                  ),
                                  c.t(
                                    'Từ điển ngoại lệ, gõ tắt, phím V/E, chế độ ứng dụng riêng, công cụ văn bản và kiểm tra gõ để ai cũng chỉnh được theo nhu cầu.',
                                    'Exception dictionaries, snippets, V/E shortcuts, per-app profiles, text tools and a typing lab.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading(
                        Icons.handshake_outlined,
                        c.t('Một lời cảm ơn', 'A note of thanks'),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        c.t(
                          'Cảm ơn bạn đã dành thời gian thử TelexMini, kể cả khi ứng dụng vẫn còn những chỗ cần hoàn thiện. Mỗi góp ý, mỗi từ gõ sai được báo lại và mỗi lần bạn giới thiệu công cụ cho một người khác đều là động lực để tôi tiếp tục sửa lỗi, học hỏi và làm nó tốt hơn.',
                          'Thank you for giving TelexMini a try, even while there are still rough edges to improve. Every suggestion, reported typing issue and recommendation to a friend helps me keep learning and making the app better.',
                        ),
                        style: const TextStyle(fontSize: 12.5, height: 1.6),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        c.t(
                          'Nếu TelexMini hữu ích với bạn và bạn muốn ủng hộ tác giả, hãy ghé thăm ygometa.me. Sự ủng hộ là hoàn toàn tự nguyện; điều tôi mong nhất là công cụ giúp việc gõ chữ mỗi ngày trở nên thoải mái hơn.',
                          'If TelexMini helps you and you would like to support its creator, please visit ygometa.me. Support is entirely optional; my biggest hope is simply to make everyday typing more comfortable.',
                        ),
                        style: const TextStyle(fontSize: 12.5, height: 1.6),
                      ),
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 10,
                        runSpacing: 9,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            key: const Key('about-support-link'),
                            onPressed: opening ? null : openSupportSite,
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                            ),
                            label: Text(
                              c.t(
                                'Truy cập ygometa.me · Ủng hộ tác giả',
                                'Visit ygometa.me · Support the creator',
                              ),
                            ),
                          ),
                          TextButton.icon(
                            key: const Key('about-copy-link'),
                            onPressed: () async {
                              await Clipboard.setData(
                                const ClipboardData(text: supportUrl),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      c.t(
                                        'Đã sao chép địa chỉ website.',
                                        'Website address copied.',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 17),
                            label: Text(c.t('Sao chép liên kết', 'Copy link')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const SelectableText(
                        supportUrl,
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(IconData icon, String text) => Row(
    children: [
      Icon(icon, color: teal, size: 21),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );

  Widget _benefit(IconData icon, String title, String description) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: teal, size: 19),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
