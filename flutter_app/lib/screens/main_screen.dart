import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'dashboard_screen.dart';
import 'configure_screen.dart';
import 'settings_screen.dart';

/// 底部 4 Tab 主框架：对话 / 仪表盘 / 配置 / 设置。
/// 首页默认停在「对话」Tab；IndexedStack 保留各页状态（对话连接不丢、配置不重置）。
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 各 Tab 页面实例（复用，避免切 Tab 重建导致对话断连 / 状态丢失）
  final List<Widget> _pages = const [
    ChatScreen(),
    DashboardScreen(showSettingsButton: false),
    ConfigureScreen(showBack: false),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '对话',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '仪表盘',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '配置',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
