import 'package:flutter/material.dart';
import 'controller.dart';
import 'pages.dart';
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
            scaffoldBackgroundColor: dark ? const Color(0xFF0F1928) : const Color(0xFFF6F9FC),
            fontFamily: 'Roboto',
            textTheme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light)
                .textTheme.apply(
                  bodyColor: dark ? const Color(0xFFEBF4FA) : const Color(0xFF182B3E),
                  displayColor: dark ? const Color(0xFFEBF4FA) : const Color(0xFF182B3E),
                ),
            cardTheme: CardThemeData(
              color: dark ? const Color(0xFF192739) : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: dark ? const Color(0xFF304458) : const Color(0xFFDDE7EF)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: dark ? const Color(0xFF1F2F42) : const Color(0xFFF1F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: dark ? const Color(0xFF304458) : const Color(0xFFDDE7EF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: dark ? const Color(0xFF304458) : const Color(0xFFDDE7EF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF009189), width: 1.5),
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
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 900;
      return Scaffold(
        body: Row(
          children: [
            if (!compact) Sidebar(controller: controller),
            Expanded(
              child: Column(
                children: [
                  if (compact) CompactTopBar(controller: controller),
                  Expanded(child: _page()),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: compact
            ? CompactNavigation(controller: controller)
            : null,
      );
    });
  }

  Widget _page() {
    switch (controller.page) {
      case AppPage.overview:
        return OverviewPage(controller: controller);
      case AppPage.englishDictionary:
        return DictionaryPage(controller: controller, vietnamese: false);
      case AppPage.vietnamesePriority:
        return DictionaryPage(controller: controller, vietnamese: true);
      case AppPage.snippets:
        return SnippetsPage(controller: controller);
      case AppPage.symbols:
        return SymbolsPage(controller: controller);
      case AppPage.settings:
        return SettingsPage(controller: controller);
    }
  }
}

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 206,
      color: const Color(0xFF0D1F30),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrandHeader(),
          const SizedBox(height: 19),
          Text(controller.t('KHÔNG GIAN', 'WORKSPACE'),
              style: const TextStyle(color: Color(0xFF91A9BF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6)),
          const SizedBox(height: 8),
          _nav(AppPage.overview, Icons.grid_view_rounded, controller.t('Tổng quan', 'Overview')),
          _nav(AppPage.englishDictionary, Icons.menu_book_rounded, controller.t('Từ điển Anh', 'English dictionary')),
          _nav(AppPage.vietnamesePriority, Icons.translate_rounded, controller.t('Ưu tiên Telex', 'Vietnamese priority')),
          _nav(AppPage.snippets, Icons.bolt_rounded, controller.t('Gõ tắt', 'Snippets')),
          _nav(AppPage.symbols, Icons.auto_awesome_rounded, controller.t('Ký tự nhanh', 'Quick symbols')),
          _nav(AppPage.settings, Icons.settings_rounded, controller.t('Cài đặt', 'Settings')),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF172F40),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFF2D4657)),
            ),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF74DDC7)),
              const SizedBox(width: 9),
              Expanded(child: Text(controller.t('Riêng tư · Offline', 'Private · Offline'),
                style: const TextStyle(color: Color(0xFFCDDFE9), fontSize: 11, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _nav(AppPage page, IconData icon, String label) {
    final selected = controller.page == page;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => controller.setPage(page),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF155F61) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: selected ? const Color(0xFF75E8D4) : Colors.white70),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(
                color: selected ? const Color(0xFF75E8D4) : Colors.white,
                fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ))),
            ],
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
    child: Row(children: [
      const BrandMark(size: 34),
      const SizedBox(width: 10),
      const Text('telexmini', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      const Spacer(),
    ]),
  );
}

class CompactNavigation extends StatelessWidget {
  const CompactNavigation({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: controller.page.index,
    onDestinationSelected: (index) => controller.setPage(AppPage.values[index]),
    destinations: [
      NavigationDestination(icon: const Icon(Icons.grid_view_rounded), label: controller.t('Tổng quan','Home')),
      NavigationDestination(icon: const Icon(Icons.menu_book_rounded), label: controller.t('Từ điển','Words')),
      NavigationDestination(icon: const Icon(Icons.translate_rounded), label: controller.t('Telex','Telex')),
      NavigationDestination(icon: const Icon(Icons.bolt_rounded), label: controller.t('Gõ tắt','Snippets')),
      NavigationDestination(icon: const Icon(Icons.auto_awesome_rounded), label: controller.t('Ký tự','Symbols')),
      NavigationDestination(icon: const Icon(Icons.settings_rounded), label: controller.t('Cài đặt','Settings')),
    ],
  );
}
