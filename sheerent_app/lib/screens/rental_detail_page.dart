import 'package:flutter/material.dart';
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
    final deposit = rental['deposit_amount'];
    final deducted = rental['deducted_amount'];
    final beforeImageUrl = item != null
        ? "$baseUrl/static/images/item_${item['id']}/before.jpg"
        : null;

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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타이틀
                Text(
                  item?['name'] ?? "삭제된 물품",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // 상태 표시
                Row(
                  children: [
                    Icon(Icons.info, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ],
                ),
                const Divider(height: 30),

                // 설명 및 가격
                if (item != null) ...[
                  Text("설명", style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(item['description'] ?? '-', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Text("가격", style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text("${formatter.format(item['price_per_day'])} P / ${item['unit'] == 'per_hour' ? '시간' : '일'}",),
                ],
                const SizedBox(height: 16),

                // 시간 정보
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

                const SizedBox(height: 20),

                // 보증금 정보
                if (isReturned)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDamaged ? Colors.red[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isDamaged
                          ? "보증금 차감: ₩$deducted"
                          : "보증금 반환: ₩$deposit",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDamaged ? Colors.red : Colors.green,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // 이미지
                if (beforeImageUrl != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("등록 이미지 (Before)", style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          beforeImageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Text("이미지를 불러올 수 없습니다."),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
