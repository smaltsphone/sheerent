import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'login_screen.dart';
import 'register_user_screen.dart';
import '../globals.dart';
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
    final userId = loggedInUserId;
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
    if (loggedInUserId == null) return;
    final url = Uri.parse("$baseUrl/users/$loggedInUserId");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final userData = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        loggedInUserPoint = userData['point'];
        loggedInUserIsAdmin = userData['is_admin'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("☰ 더보기")),
      body: ListView(
        children: [
          if (loggedInUserId != null) ...[
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text("👤 $loggedInUserName 님"),
              subtitle: const Text("로그인 상태입니다."),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text("보유 포인트"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${loggedInUserPoint != null ? formatter.format(loggedInUserPoint) : '-'} P",
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
                setState(() {
                  loggedInUserId = null;
                  loggedInUserName = null;
                  loggedInUserPoint = null;
                  loggedInUserIsAdmin = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("로그아웃 되었습니다.")),
                );
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("📦 내가 등록한 아이템", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    child: Text("등록한 아이템이 없습니다."),
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
