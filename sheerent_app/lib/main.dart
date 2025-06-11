import 'package:flutter/material.dart';
import 'screens/main_tab_view.dart';
import 'screens/item_detail_page.dart'; // QR 코드 결과로 이동할 상세 페이지 import
import 'package:provider/provider.dart';
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
      home: const MainTabView(), // 앱 시작 시 하단 탭 화면으로 이동
      routes: {
        '/item_detail': (context) {
          final itemId = ModalRoute.of(context)!.settings.arguments as int;
          return ItemDetailPage(itemId: itemId);
        },
        '/rentals': (context) => const MainTabView(),
      },
    );
  }
}
