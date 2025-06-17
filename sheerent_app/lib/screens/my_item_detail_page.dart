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
  late Map<String, dynamic> currentItem;

  @override
  void initState() {
    super.initState();
    currentItem = Map<String, dynamic>.from(widget.item);
    refreshItem();
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
    final updatedItem = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final rentalInfo = updatedItem['rental'];

    if (!mounted) return;

    setState(() {
      currentItem = updatedItem;
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
  final item = currentItem;
  final List imageUrls = item['images'] ?? [];

  final bool isDamaged = item['damage_reported'] == true;
  final bool hasInsurance = (item['has_insurance'] ?? false) || (item['rental']?['has_insurance'] ?? false);

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
            // ✅ 정보 묶기
            Card(
              elevation: 2,
              color: isDamaged ? Colors.red[50] : null, // 파손 시 빨간 배경
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('이름', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(item['name']?.toString() ?? '이름 없음'),

                    const SizedBox(height: 12),
                    Text('가격', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("${formatter.format(item['price_per_day'])} P / ${item['unit'] == 'per_hour' ? '시간' : '일'}"),

                    const SizedBox(height: 12),
                    Text('설명', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(item['description'] ?? ''),

                    const SizedBox(height: 12),
                    Text('보관함 번호', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(item['locker_number'] ?? '없음'),

                    const SizedBox(height: 12),
                    if (isDamaged) ...[
                      Text('보험 가입 여부', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        hasInsurance ? "✅ 가입" : "❌ 미가입",
                        style: TextStyle(
                          color: hasInsurance ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                        final url = Uri.parse('$baseUrl/items/repair/${item['id']}');
                        final response = await http.post(url);

                        if (response.statusCode == 200) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("✅ 수리 완료")),
                            );
                            await refreshItem(); // 최신 상태 반영
                            Navigator.pop(context, true);
                            if (mounted) setState(() {}); // 강제 리빌드
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("❌ 수리 실패: ${response.statusCode}")),
                            );
                          }
                        }
                      },
                        icon: const Icon(Icons.build),
                        label: const Text("수리하기"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
