import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';

class RentalDetailPage extends StatelessWidget {
  final Map<String, dynamic> rental;
  const RentalDetailPage({super.key, required this.rental});

  @override
  Widget build(BuildContext context) {
    final item = rental['item'];
    final startTime = rental['start_time'];
    final endTime = rental['end_time'];
    final isReturned = rental['is_returned'];
    final damageReported = rental['damage_reported'];
    final hasInsurance = rental['has_insurance'] == true;

    final beforeImageUrl = item != null && item['images'] != null && item['images'].isNotEmpty
        ? "$baseUrl${item['images'][0]}"
        : null;
    final afterImageUrl = rental['after_image_url'];

    final formattedStart = startTime?.replaceAll('T', ' ').split('.').first ?? '-';
    final formattedEnd = endTime?.replaceAll('T', ' ').split('.').first ?? '-';

    final isDamaged = damageReported == true;
    final statusText = isReturned
        ? (isDamaged ? "반납 완료 (파손)" : "반납 완료 (정상)")
        : "대여 중";

    final statusColor = isReturned
        ? (isDamaged ? Colors.red : Colors.green)
        : Colors.orange;

    return Scaffold(
      appBar: AppBar(title: const Text("대여 상세정보")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item?['name'] ?? "삭제된 물품", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.info, color: statusColor),
                    const SizedBox(width: 8),
                    Text(statusText, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: statusColor)),
                  ],
                ),
                const Divider(height: 30),

                if (item != null) ...[
                  const Text("설명", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(item['description'] ?? '-', style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 12),
                  const Text("가격", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("${formatter.format(item['price_per_day'])} P / ${item['unit'] == 'per_hour' ? '시간' : '일'}",
                      style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 12),
                  const Text("보험 가입 여부", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(hasInsurance ? "✅ 가입" : "❌ 미가입", style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 12),

                  const Text("결제 상세 내역", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Builder(builder: (_) {
                    try {
                      final unit = item['unit'];
                      final price = item['price_per_day'];

                      if (startTime != null && endTime != null && price != null) {
                        final start = DateTime.parse(startTime);
                        final end = DateTime.parse(endTime);
                        int totalHours = end.difference(start).inHours;

                        if (totalHours <= 0) totalHours = 1;

                        final int baseHours = unit == 'per_hour' ? 1 : 24;
                        final int actualBaseHours = totalHours >= baseHours ? baseHours : totalHours;
                        final int extensionHours = totalHours - actualBaseHours;

                        final int pricePerHour = unit == 'per_hour'
                            ? price
                            : (price / 24).round();

                        final int basePrice = pricePerHour * actualBaseHours;
                        final int extensionPrice = pricePerHour * extensionHours;

                        final baseDays = actualBaseHours ~/ 24;
                        final baseRemainHours = actualBaseHours % 24;
                        String baseTimeText = '';
                        if (baseDays > 0) baseTimeText += '${baseDays}일 ';
                        if (baseRemainHours > 0) baseTimeText += '${baseRemainHours}시간';
                        if (baseTimeText.isEmpty) baseTimeText = '1시간';

                        final extensionDays = extensionHours ~/ 24;
                        final extensionRemainHours = extensionHours % 24;
                        String extensionTimeText = '';
                        if (extensionDays > 0) extensionTimeText += '${extensionDays}일 ';
                        if (extensionRemainHours > 0) extensionTimeText += '${extensionRemainHours}시간';

                        final int fee = ((basePrice + extensionPrice) * 0.05).round();
                        final int insurance = hasInsurance ? ((basePrice + extensionPrice) * 0.05).round() : 0;
                        final int total = basePrice + extensionPrice + fee + insurance;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("기본 요금 ($baseTimeText): ${formatter.format(basePrice)} P"),
                            if (extensionHours > 0)
                              Text("연장 요금 ($extensionTimeText): ${formatter.format(extensionPrice)} P"),
                            Text("수수료 (5%): ${formatter.format(fee)} P"),
                            if (hasInsurance)
                              Text("보험료 (5%): ${formatter.format(insurance)} P"),
                            const Divider(height: 20),
                            Text("총 결제 금액: ${formatter.format(total)} P", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        );
                      } else {
                        return const Text("시간 또는 가격 정보 부족");
                      }
                    } catch (e) {
                      return const Text("❌ 결제 정보 계산 오류");
                    }
                  }),
                  const SizedBox(height: 16),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("대여 시작", style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Text(formattedStart, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("반납 시간", style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Text(formattedEnd, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (beforeImageUrl != null || afterImageUrl != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("이미지 비교", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text("등록 이미지", style: TextStyle(fontSize: 14)),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: beforeImageUrl != null
                                        ? Image.network(
                                            beforeImageUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => const Text("불러오기 실패"),
                                          )
                                        : const Center(child: Text("이미지 없음")),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("반납 이미지", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: Builder(
                                      builder: (context) {
                                        if (afterImageUrl != null) {
                                          final fullUrl = "$baseUrl$afterImageUrl";
                                          return Image.network(
                                            fullUrl,
                                            fit: BoxFit.contain,
                                            loadingBuilder: (context, child, progress) {
                                              if (progress == null) return child;
                                              return const Center(child: CircularProgressIndicator());
                                            },
                                            errorBuilder: (_, __, ___) => const Text("불러오기 실패"),
                                          );
                                        } else {
                                          return const Center(child: Text("이미지 없음"));
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    ],
                  ),

                if (isReturned) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("삭제 확인"),
                            content: const Text("이 대여 기록을 삭제하시겠습니까?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("취소")),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("삭제")),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          final rentalId = rental['id'];
                          final url = Uri.parse('$baseUrl/rentals/$rentalId');
                          final response = await http.delete(url);

                          if (response.statusCode == 200) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("✅ 대여 기록이 삭제되었습니다")),
                            );
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("❌ 삭제 실패")),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text("삭제"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
