// lib/globals.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'screens/register_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';

const String apiBaseUrl = "https://sheerent-server.onrender.com";
const String baseUrl = "http://172.30.1.3:8000";

final NumberFormat formatter = NumberFormat('#,##0', 'ko_KR');

void resetLoginState(BuildContext context) {
  Provider.of<AuthProvider>(context, listen: false).logout();
  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
}

// ✅ 관리자 여부, 포인트 포함해서 전역 상태 저장
void onLoginSuccess(
    BuildContext context, int userId, String userName, bool isAdmin, int point) {
  Provider.of<AuthProvider>(context, listen: false)
      .login(id: userId, name: userName, admin: isAdmin, point: point);
  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
}

bool isLoggedIn(BuildContext context) =>
    Provider.of<AuthProvider>(context, listen: false).isLoggedIn;

void requireLogin(BuildContext context) {
  if (!isLoggedIn(context)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("로그인이 필요한 기능입니다.")),
    );
  }
}

void handleRegisterButton(BuildContext context) {
  if (!isLoggedIn(context)) {
    requireLogin(context);
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const RegisterScreen()),
  );
}

Future<void> handleRentItemWithDays(
    BuildContext context, int itemId, double days) async {
  if (!isLoggedIn(context)) {
    requireLogin(context);
    return;
  }

  final borrowerId = Provider.of<AuthProvider>(context, listen: false).userId;
  if (borrowerId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ 로그인 정보가 없습니다.")),
    );
    return;
  }

  final url = Uri.parse('$baseUrl/rentals/');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'item_id': itemId,
      'borrower_id': borrowerId,
      'end_time': DateTime.now()
          .add(Duration(seconds: (days * 24 * 60 * 60).toInt()))
          .toIso8601String(),
    }),
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ 대여 성공")),
    );
    Navigator.pop(context);
  } else {
    final detail = utf8.decode(response.bodyBytes);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ 대여 실패: $detail")),
    );
  }
}

Future<List<dynamic>> fetchMyItems(BuildContext context) async {
  final userId = Provider.of<AuthProvider>(context, listen: false).userId;
  if (userId == null) return [];

  final url = Uri.parse('$baseUrl/items/owned/$userId');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } else {
    return [];
  }
}

 String getUnitText(String? unit) {
  switch (unit) {
    case 'per_day':
      return '일';
    case 'per_hour':
      return '시간';
    default:
      return '기타';
  }
}

