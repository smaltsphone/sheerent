import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'login_screen.dart';
import 'register_user_screen.dart';
import '../globals.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'my_item_detail_page.dart';
import 'charge_point_screen.dart';
import 'qr_scan_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<List<dynamic>> fetchMyItems() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return [];

    final url = Uri.parse('$baseUrl/items/owned/$userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      return [];
    }
  }

  Future<void> _refreshPoint() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final url = Uri.parse("$baseUrl/users/${auth.userId}");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final userData = jsonDecode(utf8.decode(response.bodyBytes));
      auth.updatePoint(userData['point']);
      auth.updateAdmin(userData['is_admin']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("☰ 더보기")),
      body: ListView(
        children: [
          if (context.watch<AuthProvider>().isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text("👤 ${context.watch<AuthProvider>().userName} 님"),
              subtitle: const Text("로그인 상태입니다."),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text("보유 포인트"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${context.watch<AuthProvider>().point != null ? formatter.format(context.watch<AuthProvider>().point) : '-'} P",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: "포인트 새로고침",
                    onPressed: _refreshPoint,
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_card),
              title: const Text("포인트 충전"),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChargePointScreen()),
                );
                setState(() {});
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("로그아웃"),
              onTap: () {
                context.read<AuthProvider>().logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("로그아웃 되었습니다.")),
                );
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("📦 내가 등록한 물품", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            FutureBuilder<List<dynamic>>(
              future: fetchMyItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text("등록한 물품이 없습니다."),
                  );
                }
                return Column(
                  children: items.map((item) => ListTile(
                    leading: item['images']?.isNotEmpty == true
                        ? Image.network(
                            '$baseUrl${item['images'][0]}',
                            width: 40, height: 40, fit: BoxFit.cover)
                        : const Icon(Icons.image),
                    title: Text(item['name']),
                    subtitle: Text("${formatter.format(item['price_per_day'])} P / ${item['unit'] == 'per_hour' ? '시간' : '일'}",),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyItemDetailPage(item: item),
                        ),
                      ).then((result) {
                        if (result == true) {
                          setState(() {
                            // 화면 갱신 로직
                          });
                        }
                      });
                    },
                  )).toList(),
                );
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text("로그인"),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ).then((_) => setState(() {}));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text("회원가입"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterUserScreen()),
                );
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("앱 정보"),
            subtitle: const Text("쉬어렌트 v1.0"),
          ),
          ListTile(
            leading: const Icon(Icons.contact_support),
            title: const Text("개발자 문의"),
            subtitle: const Text("support@sheerent.com"),
          ),
        ],
      ),
    );
  }
}
