import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ItemDetailPage extends StatefulWidget {
  final int itemId;
  const ItemDetailPage({super.key, required this.itemId});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

enum RentalUnit { hour, day }
int? userPoint;

class _ItemDetailPageState extends State<ItemDetailPage> {
  Map<String, dynamic>? item;
  bool loading = true;
  int rentalAmount = 1;
  RentalUnit rentalUnit = RentalUnit.hour;
  bool insuranceSelected = false;

  @override
  void initState() {
    super.initState();
    fetchItemDetail();
     fetchUserPoint();
  }

  Future<void> fetchUserPoint() async {
  final userId = context.read<AuthProvider>().userId;
  final url = Uri.parse('$baseUrl/users/$userId');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    setState(() {
      userPoint = data['point'];
    });
  } else {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ 사용자 정보를 불러오지 못했습니다.")),
    );
  }
}

  Future<void> fetchItemDetail() async {
    final url = Uri.parse("$baseUrl/items/${widget.itemId}");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        item = data;
        loading = false;
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 물품 정보를 불러오지 못했습니다.")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading || item == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List imageUrls = item!['images'] ?? [];
    final unit = item!['unit'];
    final pricePerDay = (item!['price_per_day'] ?? 0).toDouble();

    // 시간 기준 단가 계산
    final pricePerHour = (unit == 'per_day')
      ? pricePerDay / 24
      : pricePerDay;
    double rentalPrice = rentalAmount * pricePerHour * (rentalUnit == RentalUnit.day ? 24 : 1);
    final int totalHours = rentalAmount * (rentalUnit == RentalUnit.day ? 24 : 1);
    final double insuranceFee = insuranceSelected ? pricePerHour * 0.05 * totalHours : 0;
    final double fee = rentalPrice * 0.05;
    final double totalPay = rentalPrice + fee + insuranceFee;
    final DateTime startTime = DateTime.now();
    
    final DateTime returnTime = startTime.add(Duration(hours: totalHours));
    final String returnTimeStr =
        "${returnTime.year}-${returnTime.month.toString().padLeft(2, '0')}-${returnTime.day.toString().padLeft(2, '0')} "
        "${returnTime.hour.toString().padLeft(2, '0')}:${returnTime.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(title: Text(item!['name'] ?? '물품 상세정보')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrls.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      '$baseUrl${imageUrls[index]}',
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('이미지가 없습니다',
                      style: TextStyle(color: Colors.black45, fontSize: 16)),
                ),
              ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('이름', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(item!['name'] ?? '', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('가격', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text("${formatter.format(item!['price_per_day'])} P / ${getUnitText(item!['unit'])}"),
                    const SizedBox(height: 12),
                    Text('설명', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(item!['description'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Text('보관함 번호', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(
                      item!['locker_number'] ?? '없음',
                      style: Theme.of(context).textTheme.bodyMedium,
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (item!['owner_id'] == context.read<AuthProvider>().userId)
              Center(
                child: Text(
                  '❌ 자신이 등록한 물건은 대여할 수 없습니다.',
                  style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                ),
              )
            else ...[
              Text('대여 단위 선택', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ToggleButtons(
                borderRadius: BorderRadius.circular(8),
                isSelected: [rentalUnit == RentalUnit.hour, rentalUnit == RentalUnit.day],
                onPressed: (index) {
                  setState(() {
                    rentalUnit = index == 0 ? RentalUnit.hour : RentalUnit.day;
                    rentalAmount = 1;
                  });
                },
                selectedColor: Colors.white,
                fillColor: Colors.blueAccent,
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('시간')),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('일')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.blueAccent),
                    onPressed: () {
                      if (rentalAmount > 1) {
                        setState(() => rentalAmount--);
                      }
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$rentalAmount ${rentalUnit == RentalUnit.hour ? "시간" : "일"}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                    onPressed: () => setState(() => rentalAmount++),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: insuranceSelected,
                    onChanged: (value) {
                      setState(() {
                        insuranceSelected = value ?? false;
                      });
                    },
                  ),
                  const Text(
                    '보험 가입',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (insuranceSelected)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    '⚠️ 파손 시 자기부담금 3만원이 발생합니다.',
                    style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                  ),
                ),
              Center(
                child: Text('총 결제 금액: ${formatter.format(totalPay.round())} P',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 8),
                  Text('반납 시간: $returnTimeStr',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: (item!['owner_id'] == context.read<AuthProvider>().userId)
          ? null
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: () async {
                  final rentalHours = rentalAmount * (rentalUnit == RentalUnit.day ? 24 : 1);
                  final endTime = DateTime.now().add(Duration(hours: rentalHours));

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("💳 결제 확인"),
                      content: Text(
                        "물품 가격: ${formatter.format(rentalPrice.round())} P\n"
                        "수수료 (5%): ${formatter.format(fee.round())} P\n"
                        "보험료 (5%): ${formatter.format(insuranceFee.round())} P\n"
                        "총 결제 금액: ${formatter.format(totalPay.round())} P\n"
                        "결제 후 남은 금액: ${userPoint != null ? formatter.format((userPoint! - totalPay).round()) : '로딩 중...'} P\n\n"
                        "결제를 진행하시겠습니까?",
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("확인")),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  final response = await http.post(
                    Uri.parse("$baseUrl/rentals/"),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "item_id": item!['id'],
                      "borrower_id": context.read<AuthProvider>().userId,
                      "end_time": endTime.toIso8601String(),
                      "total_pay": totalPay.round(),
                      "insurance": insuranceSelected,
                    }),
                  );

                  if (response.statusCode == 200 || response.statusCode == 201) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ 대여 완료")),
                    );
                    // 2) 라즈베리파이에 보관함 열기 신호 보내기
                    try {
                      final doorResponse = await http.post(
                        Uri.parse("$baseUrl/lockers/open"),  // FastAPI lockers/open 경로
                        headers: {"Content-Type": "application/json"},
                      );
                      if (doorResponse.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("🔓 보관함 열렸습니다.")),
                        );
                        // 15초 후 보관함 닫기 요청 자동 실행
      Future.delayed(const Duration(seconds: 15), () async {
        try {
          final doorCloseResponse = await http.post(
            Uri.parse("$baseUrl/lockers/close"),
            headers: {"Content-Type": "application/json"},
          );

          if (doorCloseResponse.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("🔒 보관함이 닫혔습니다.")),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("⚠️ 보관함 닫기 실패: ${doorCloseResponse.statusCode}")),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("⚠️ 보관함 닫기 중 오류: $e")),
          );
        }
      });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("⚠️ 보관함 열기 실패: ${doorResponse.statusCode}")),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("⚠️ 보관함 중 오류 발생: $e")),
                      );
                    }
                    Navigator.pop(context, true);
                  } else {
                    final decodedBody = utf8.decode(response.bodyBytes);
                    final errorMsg = jsonDecode(decodedBody)['detail'] ?? "알 수 없는 오류";
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("❌ 대여 실패: $errorMsg")),
                    );
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('대여하기', style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
            
    );
    
  }
}
