// lib/screens/main_tab_view.dart
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'return_screen.dart';
import 'register_screen.dart';
import 'rental_history_page.dart';
import 'settings_screen.dart';


class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),         // 📋 대여
    const ReturnScreen(),       // 🔄 반납
    const RegisterScreen(),     // ➕ 등록
    const RentalHistoryPage(),  // 🧾 대여기록 (이제 연결됨)
    const SettingsScreen(),        // ⚙️ 더보기
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '대여'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_return), label: '반납'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: '등록'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: '기록'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: '더보기'),
        ],
      ),
    );
  }
}
