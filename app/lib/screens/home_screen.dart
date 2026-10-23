import 'package:flutter/material.dart';

import '../widgets/mini_player.dart';
import '../widgets/mosque_background.dart';
import 'episodes_screen.dart';
import 'library_screen.dart';
import 'rules_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// الهيكل الرئيسي: أربعة أقسام مع مشغّل مصغّر ثابت.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _pages = [
    EpisodesScreen(),
    RulesScreen(),
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MosqueBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: _pages),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books_rounded),
                label: 'الحلقات',
              ),
              NavigationDestination(
                icon: Icon(Icons.format_quote_outlined),
                selectedIcon: Icon(Icons.format_quote_rounded),
                label: 'القواعد',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.manage_search_rounded),
                label: 'البحث',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmarks_outlined),
                selectedIcon: Icon(Icons.bookmarks_rounded),
                label: 'محفوظاتي',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'الإعدادات',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
