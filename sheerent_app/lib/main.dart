import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_tab_view.dart';
import 'screens/item_detail_page.dart';
import 'screens/splash_screen.dart'; // ✅ 추가
import 'providers/auth_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sheerent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/', // ✅ 스플래시 먼저 띄우기
      routes: {
        '/': (context) => const SplashScreen(), // ✅ 첫 화면: 쉬봇 splash
        '/home': (context) => const MainTabView(), // ✅ 메인 탭 화면
        '/item_detail': (context) {
          final itemId = ModalRoute.of(context)!.settings.arguments as int;
          return ItemDetailPage(itemId: itemId);
        },
        '/rentals': (context) => const MainTabView(),
      },
    );
  }
}
