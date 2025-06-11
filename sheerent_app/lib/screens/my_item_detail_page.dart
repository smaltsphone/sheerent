import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'register_screen.dart';
import '../globals.dart';

class MyItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  const MyItemDetailPage({super.key, required this.item});

  @override
  State<MyItemDetailPage> createState() => _MyItemDetailPageState();
}

class _MyItemDetailPageState extends State<MyItemDetailPage> {
  bool isRented = false;

  @override
  void initState() {
    super.initState();
    checkRentalStatus();
  }

Future<void> checkRentalStatus() async {
  final itemId = widget.item['id'];
  final url = Uri.parse('$baseUrl/rentals?is_returned=false');

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final List<dynamic> rentals = jsonDecode(utf8.decode(response.bodyBytes));
    if (!mounted) return;  // 위젯이 트리에 없으면 종료
    setState(() {
      isRented = rentals.any((rental) => rental['item']?['id'] == itemId);
    });
  }
}

Future<void> refreshItem() async {
  final url = Uri.parse('$baseUrl/items/${widget.item['id']}');
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final updatedItem = jsonDecode(response.body);
    print("디버그: updatedItem = $updatedItem");
    if (!mounted) return;  // 위젯이 트리에 없으면 종료
    setState(() {
      widget.item.clear();
      widget.item.addAll(updatedItem);
    });
    // 대여 상태도 다시 확인
    await checkRentalStatus();
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ 아이템 정보 갱신 실패: ${response.statusCode}")),
      );
    }
  }
}

  Future<void> deleteItem(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("삭제 확인"),
        content: const Text("정말 이 아이템을 삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("취소")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("삭제")),
        ],
      ),
    );

    if (confirm != true) return;

    final url = Uri.parse('$baseUrl/items/${widget.item['id']}');
    final response = await http.delete(url);

    if (response.statusCode == 204) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 삭제 완료")),
        );
        Navigator.pop(context, true); // 삭제 성공 시 true 반환하면서 현재 페이지 종료
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ 삭제 실패: ${response.statusCode}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final List imageUrls = item['images'] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text("내가 등록한 물품")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrls.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: imageUrls.length,
                    itemBuilder: (context, index) => Image.network(
                      '$baseUrl${imageUrls[index]}',
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('이름: ${item['name']}', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                '가격: ${formatter.format(item['price_per_day'])} P / ${item['unit'] == 'per_hour' ? '시간' : '일'}',
              ),
              const SizedBox(height: 8),
              Text('설명: ${item['description']}'),
              const SizedBox(height: 8),
              Text('보관함 번호: ${item['locker_number'] ?? '없음'}'),
              const SizedBox(height: 24),
              if (!isRented)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterScreen(itemToEdit: item),
                          ),
                        );
                        if (result == true) {
                          await refreshItem();
                        }
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text("수정하기"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => deleteItem(context),
                      icon: const Icon(Icons.delete),
                      label: const Text("삭제하기"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    ),
                  ],
                )
              else
                const Center(
                  child: Text(
                    "❗ 현재 대여 중이므로 수정/삭제할 수 없습니다.",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
