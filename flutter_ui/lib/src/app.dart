import 'package:flutter/material.dart';

import 'controller.dart';
import 'applications_page.dart';
import 'about_page.dart';
import 'diagnostics_page.dart';
import 'pages.dart';
import 'reference_dashboard.dart';
import 'snippet_list_page.dart';
import 'text_tools_page.dart';
import 'typing_lab_page.dart';
import 'widgets.dart';

class TelexMiniApp extends StatelessWidget {
  const TelexMiniApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final dark = controller.darkMode;
        final scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF009189),
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'TelexMini',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: scheme,
            scaffoldBackgroundColor: dark
                ? const Color(0xFF0F1928)
                : const Color(0xFFF6F9FC),
            fontFamily: 'Segoe UI Variable',
            fontFamilyFallback: const ['Segoe UI', 'Arial'],
            textTheme:
                ThemeData(brightness: dark ? Brightness.dark : Brightness.light)
                    .textTheme
                    .apply(
                      bodyColor: dark
                          ? const Color(0xFFEBF4FA)
                          : const Color(0xFF182B3E),
                      displayColor: dark
                          ? const Color(0xFFEBF4FA)
                          : const Color(0xFF182B3E),
                    ),
            cardTheme: CardThemeData(
              color: dark ? const Color(0xFF192739) : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: dark
                      ? const Color(0xFF304458)
                      : const Color(0xFFDDE7EF),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: dark
                  ? const Color(0xFF1F2F42)
                  : const Color(0xFFF1F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: dark
                      ? const Color(0xFF304458)
                      : const Color(0xFFDDE7EF),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: dark
                      ? const Color(0xFF304458)
                      : const Color(0xFFDDE7EF),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF009189),
                  width: 1.5,
                ),
              ),
            ),
          ),
          home: AppShell(controller: controller),
        );
      },
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, bounds) {
          // At 125–150% Windows DPI, the Flutter logical viewport may be
          // much smaller than the native window's physical pixel bounds.
          // Keep the editor usable rather than clipping a fixed sidebar.
          final compact = bounds.maxWidth < 850 || bounds.maxHeight < 640;
          return Row(
            children: [
              if (!compact) Sidebar(controller: controller),
              Expanded(
                child: Column(
                  children: [
                    if (compact) CompactTopBar(controller: controller),
                    Expanded(child: _page()),
                    if (compact) CompactNavigation(controller: controller),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _page() {
    switch (controller.page) {
      case AppPage.overview:
        return ReferenceDashboard(controller: controller);
      case AppPage.englishDictionary:
        return DictionaryPage(controller: controller, vietnamese: false);
      case AppPage.vietnamesePriority:
        return DictionaryPage(controller: controller, vietnamese: true);
      case AppPage.snippets:
        return SnippetListPage(controller: controller);
      case AppPage.symbols:
        return SymbolsPage(controller: controller);
      case AppPage.applications:
        return ApplicationsPage(controller: controller);
      case AppPage.textTools:
        return TextToolsPage(controller: controller);
      case AppPage.typingLab:
        return TypingLabPage(controller: controller);
      case AppPage.diagnostics:
        return DiagnosticsPage(controller: controller);
      case AppPage.settings:
        return SettingsPage(controller: controller);
      case AppPage.about:
        return AboutPage(controller: controller);
    }
  }
}

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: controller.compactSidebar ? 76 : 255,
      color: controller.darkMode
          ? const Color(0xFF0D1F30)
          : const Color(0xFFF9FCFF),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.compactSidebar)
            Tooltip(message: 'TelexMini', child: const BrandMark(size: 45))
          else
            const BrandHeader(),
          const SizedBox(height: 25),
          if (!controller.compactSidebar)
            Text(
              controller.t('KHÔNG GIAN', 'WORKSPACE'),
              style: TextStyle(
                color: controller.darkMode
                    ? const Color(0xFF91A9BF)
                    : const Color(0xFF6A8195),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .6,
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _nav(
                  AppPage.overview,
                  Icons.home_outlined,
                  controller.t('Tổng quan', 'Overview'),
                ),
                _nav(
                  AppPage.englishDictionary,
                  Icons.menu_book_rounded,
                  controller.t('Từ điển Anh', 'English dictionary'),
                ),
                _nav(
                  AppPage.vietnamesePriority,
                  Icons.translate_rounded,
                  controller.t('Ưu tiên Telex', 'Vietnamese priority'),
                ),
                _nav(
                  AppPage.snippets,
                  Icons.layers_outlined,
                  controller.t('Gõ tắt', 'Snippets'),
                ),
                _nav(
                  AppPage.symbols,
                  Icons.functions_rounded,
                  controller.t('Ký tự nhanh', 'Quick symbols'),
                ),
                _nav(
                  AppPage.applications,
                  Icons.grid_view_rounded,
                  controller.t('Ứng dụng & process', 'Apps & processes'),
                ),
                _nav(
                  AppPage.textTools,
                  Icons.auto_fix_high_rounded,
                  controller.t('Công cụ văn bản', 'Text tools'),
                ),
                _nav(AppPage.typingLab, Icons.keyboard_rounded, 'Typing Lab'),
                _nav(
                  AppPage.diagnostics,
                  Icons.bug_report_rounded,
                  controller.t('Chẩn đoán & sao lưu', 'Diagnostics & backup'),
                ),
                _nav(
                  AppPage.settings,
                  Icons.settings_rounded,
                  controller.t('Cài đặt', 'Settings'),
                ),
                _nav(
                  AppPage.about,
                  Icons.info_outline_rounded,
                  controller.t('Giới thiệu', 'About'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: controller.darkMode
                  ? const Color(0xFF172F40)
                  : const Color(0xFFEBF7F5),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: controller.darkMode
                    ? const Color(0xFF2D4657)
                    : const Color(0xFFCCE5E1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: controller.darkMode
                      ? const Color(0xFF74DDC7)
                      : const Color(0xFF007D72),
                ),
                const SizedBox(width: 9),
                if (!controller.compactSidebar)
                  Expanded(
                    child: Text(
                      controller.t('Riêng tư · Offline', 'Private · Offline'),
                      style: TextStyle(
                        color: controller.darkMode
                            ? const Color(0xFFCDDFE9)
                            : const Color(0xFF234D53),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nav(AppPage page, IconData icon, String label) {
    final selected = controller.page == page;
    final navIconColor = selected
        ? (controller.darkMode
              ? const Color(0xFF75E8D4)
              : const Color(0xFF007E75))
        : (controller.darkMode ? Colors.white70 : const Color(0xFF49677A));
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => controller.setPage(page),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? (controller.darkMode
                        ? const Color(0xFF155F61)
                        : const Color(0xFFDAF4EF))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                if (page == AppPage.about)
                  AboutNavMark(color: navIconColor)
                else
                  Icon(icon, size: 19, color: navIconColor),
                if (!controller.compactSidebar) const SizedBox(width: 10),
                if (!controller.compactSidebar)
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? (controller.darkMode
                                  ? const Color(0xFF75E8D4)
                                  : const Color(0xFF006A67))
                            : (controller.darkMode
                                  ? Colors.white
                                  : const Color(0xFF1D3548)),
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CompactTopBar extends StatelessWidget {
  const CompactTopBar({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Row(
      children: [
        const BrandMark(size: 34),
        const SizedBox(width: 10),
        const Text(
          'telexmini',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const Spacer(),
      ],
    ),
  );
}

class CompactNavigation extends StatelessWidget {
  const CompactNavigation({super.key, required this.controller});
  final AppController controller;

  static const primary = <AppPage>[
    AppPage.overview,
    AppPage.englishDictionary,
    AppPage.textTools,
    AppPage.typingLab,
  ];

  Future<void> showMore(BuildContext context) async {
    final other = <AppPage, (IconData, String)>{
      AppPage.vietnamesePriority: (
        Icons.translate_rounded,
        controller.t('Ưu tiên Telex', 'Vietnamese priority'),
      ),
      AppPage.snippets: (
        Icons.layers_outlined,
        controller.t('Gõ tắt', 'Snippets'),
      ),
      AppPage.symbols: (
        Icons.functions_rounded,
        controller.t('Ký tự nhanh', 'Quick symbols'),
      ),
      AppPage.applications: (
        Icons.grid_view_rounded,
        controller.t('Ứng dụng & process', 'Apps & processes'),
      ),
      AppPage.diagnostics: (
        Icons.bug_report_rounded,
        controller.t('Chẩn đoán & sao lưu', 'Diagnostics & backup'),
      ),
      AppPage.settings: (
        Icons.settings_rounded,
        controller.t('Cài đặt', 'Settings'),
      ),
      AppPage.about: (
        Icons.info_outline_rounded,
        controller.t('Giới thiệu', 'About'),
      ),
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (dialogContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.72,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in other.entries)
                ListTile(
                  leading: Icon(entry.value.$1),
                  title: Text(entry.value.$2),
                  selected: controller.page == entry.key,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    controller.setPage(entry.key);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = primary.indexOf(controller.page);
    return NavigationBar(
      key: const Key('compact-navigation'),
      height: 70,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      selectedIndex: index < 0 ? primary.length : index,
      onDestinationSelected: (destination) {
        if (destination == primary.length) {
          showMore(context);
        } else {
          controller.setPage(primary[destination]);
        }
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.grid_view_rounded),
          label: controller.t('Tổng quan', 'Home'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.menu_book_rounded),
          label: controller.t('Từ điển', 'Words'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: controller.t('Văn bản', 'Text'),
        ),
        const NavigationDestination(
          icon: Icon(Icons.keyboard_rounded),
          label: 'Lab',
        ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz_rounded),
          label: controller.t('Thêm', 'More'),
        ),
      ],
    );
  }
}
