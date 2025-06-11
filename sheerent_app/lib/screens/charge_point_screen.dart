import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../globals.dart';

class ChargePointScreen extends StatefulWidget {
  const ChargePointScreen({super.key});

  @override
  State<ChargePointScreen> createState() => _ChargePointScreenState();
}

class _ChargePointScreenState extends State<ChargePointScreen> {
  final TextEditingController _amountController = TextEditingController();

  Future<void> _submitCharge() async {
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("유효한 금액을 입력하세요.")),
      );
      return;
    }

    final url = Uri.parse("$baseUrl/users/$loggedInUserId/charge");
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"amount": amount}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 포인트 충전이 완료되었습니다.")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 충전 실패: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ 오류 발생: $e")),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("💸 포인트 충전")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("충전할 포인트 금액을 입력하세요."),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "금액 (P)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitCharge,
              child: const Text("충전하기"),
            ),
          ],
        ),
      ),
    );
  }
}
