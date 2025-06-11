import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../globals.dart';
import 'rental_detail_page.dart';

class RentalHistoryPage extends StatefulWidget {
  const RentalHistoryPage({super.key});

  @override
  State<RentalHistoryPage> createState() => _RentalHistoryPageState();
}

class _RentalHistoryPageState extends State<RentalHistoryPage> {
  List rentals = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (isLoggedIn()) {
      fetchRentalHistory();
    }
  }

  Future<void> fetchRentalHistory() async {
    setState(() {
      loading = true;
    });

    final url = Uri.parse("$baseUrl/users/$loggedInUserId/rentals");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final data = json.decode(decoded);
        setState(() {
          rentals = data;
        });
      } else {
        print("이력 불러오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("이력 오류: $e");
      setState(() {
        rentals = [];
      });
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn()) {
      return Scaffold(
        appBar: AppBar(title: const Text("🧾 대여 이력")),
        body: const Center(child: Text("로그인이 필요한 기능입니다.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("🧾 대여 이력")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rentals.isEmpty
              ? const Center(child: Text("대여 이력이 없습니다."))
              : ListView.builder(
                  itemCount: rentals.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final rental = rentals[index];
                    final item = rental['item'];
                    final isReturned = rental['is_returned'] == true;
                    final isDamaged = rental['damage_reported'] == true;
                    final title = item != null ? item['name'] : "삭제된 물품";

                      // ✅ 상태 텍스트와 색상 설정
                    final statusText = isReturned
                        ? (isDamaged ? "반납 완료 (파손)" : "반납 완료 (정상)")
                        : "대여 중";
                    final statusColor = isReturned
                        ? (isDamaged ? Colors.red : Colors.green)
                        : Colors.orange;

                    Widget? imageWidget;
                    if (item != null &&
                        item['images'] != null &&
                        item['images'].isNotEmpty) {
                      imageWidget = ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          '$baseUrl${item['images'][0]}',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      );
                    } else {
                      imageWidget = Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_not_supported),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RentalDetailPage(rental: rental),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              imageWidget,
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text("렌탈 ID: ${rental['id']}"),
                                    Text("대여일: ${rental['start_time'] ?? '없음'}"),
                                    Text("반납일: ${rental['end_time'] ?? '미반납'}"),
                                    Text(
                                      "상태: $statusText",
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
