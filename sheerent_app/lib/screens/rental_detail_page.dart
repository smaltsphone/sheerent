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
    final beforeImageUrl = item != null
      ? "$baseUrl${item['images'][0]}"  // 원래 저장된 곳
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
                  Text(rental['has_insurance'] == true ? "✅ 가입" : "❌ 미가입",
                      style: const TextStyle(fontSize: 15)),
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

                const SizedBox(height: 24),

// 이미지 영역 (Before / After 나란히 표시)
if (beforeImageUrl != null || rental['after_image_url'] != null)
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("이미지 비교", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(
        children: [
          // 등록 이미지 (Before)
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
                            errorBuilder: (context, error, stackTrace) =>
                                const Text("불러오기 실패"),
                          )
                        : const Center(child: Text("이미지 없음")),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

// 반납 이미지 (After)
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
              print("✅ [DEBUG] 반납 이미지 URL: $afterImageUrl");
              if (afterImageUrl != null) {
                final fullUrl = "$baseUrl$afterImageUrl";
                print("✅ [DEBUG] 반납 이미지 URL: $fullUrl");

                return Image.network(
                  fullUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print("❌ [ERROR] 이미지 로딩 실패: $error");
                    return const Text("불러오기 실패");
                  },
                );
              } else {
                print("❗ [DEBUG] after_image_url이 null입니다.");
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
    ]
  ),



              ],
            ),
          ),
        ),
      ),
    );
  }
}
