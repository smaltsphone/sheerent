import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../globals.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';


class ReturnScreen extends StatefulWidget {
  const ReturnScreen({super.key});

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  List rentals = [];
  bool loading = false;
  List<File> selectedImages = [];

  @override
  void initState() {
    super.initState();
    if (isLoggedIn(context)) {
      fetchRentedItems();
    }
  }

  Future<void> fetchRentedItems() async {
    setState(() {
      loading = true;
    });

    final userId = context.read<AuthProvider>().userId;
    final url = Uri.parse(
        "$baseUrl/rentals?is_returned=false&borrower_id=$userId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final data = json.decode(decoded);
        setState(() {
          rentals = data;
        });
      } else {
        print("대여 목록 불러오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("대여 리스트 오류: $e");
      setState(() {
        rentals = [];
      });
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> extendRental(int rentalId) async {
    final url = Uri.parse("$baseUrl/rentals/$rentalId/extend");
    final response = await http.put(url);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final additionalCharge = data['additional_charge'];
      final msg = additionalCharge != null
          ? "✅ 대여 기간이 1일 연장되었습니다. 추가 요금: ${formatter.format(additionalCharge)} P"
          : "✅ 대여 기간이 1일 연장되었습니다";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      fetchRentedItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 연장 실패")),
      );
    }
  }

  Future<void> _captureImageFromCamera() async {
  final uri = Uri.parse("$baseUrl/capture");

  try {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final tempDir = await getTemporaryDirectory();
      final fileName = "captured_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final filePath = path.join(tempDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (!mounted) return;

      setState(() {
        selectedImages = [file];
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📸 촬영 성공")),
      );
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ 촬영 실패: ${response.statusCode}")),
      );
    }
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ 오류 발생: $e")),
    );
  }
}

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() {
        selectedImages = [File(picked.path)];
      });
    }
  }

  void _showReturnDialog(int rentalId, int itemId) {
    selectedImages = [];

    showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text("반납 처리"),
          content: SizedBox(
            width: 300,
            height: 300,
            child: Center(
              child: selectedImages.isNotEmpty
                  ? Image.file(selectedImages.first, fit: BoxFit.contain)
                  : const Text("사진을 촬영하거나 선택해주세요."),
            ),
          ),
          actions: [
            // 갤러리 버튼
            ElevatedButton.icon(
              onPressed: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null && mounted) {
                  setState(() {
                    selectedImages = [File(picked.path)];
                  });
                }
              },
              icon: const Icon(Icons.image),
              label: const Text("갤러리"),
            ),

            // 촬영하기 버튼
            ElevatedButton.icon(
              onPressed: () async {
                await _captureImageFromCamera();
                if (!mounted) return;
                setState(() {});
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text("촬영하기"),
            ),

            // 반납하기 버튼
            TextButton(
              onPressed: selectedImages.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      _returnItem(rentalId, itemId, selectedImages.first);

                      try {
                        final closeResponse = await http.post(
                          Uri.parse("$baseUrl/lockers/close"),
                          headers: {"Content-Type": "application/json"},
                        );

                        if (closeResponse.statusCode == 200) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("🔒 보관함이 닫혔습니다.")),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("❗ 보관함 닫기 실패: ${closeResponse.statusCode}")),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("❗ 보관함 닫기 중 오류 발생: $e")),
                        );
                      }
                    },
              child: const Text("반납하기"),
            ),

            // 취소 버튼
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
          ],
        );
      },
    );
  },
);


  }

  Future<void> _returnItem(int rentalId, int itemId, File afterFile) async {
    final uri = Uri.parse("$baseUrl/rentals/$rentalId/return");
    final request = http.MultipartRequest('PUT', uri);

    request.fields['user_id'] = context.read<AuthProvider>().userId.toString();
    request.fields['item_id'] = itemId.toString();
    request.files.add(await http.MultipartFile.fromPath('after_file', afterFile.path));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await request.send();
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final respJson = json.decode(respStr);

        final damageDetected = respJson['damage_reported'] ?? false;
        final lateHours = respJson['late_hours'];
        final lateFee = respJson['late_fee'];
        final rentalIdResp = respJson['id'];
        final dateTime = DateTime.parse(respJson['start_time']);
        final formattedDate =
            '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}';

        final beforeImageUrl =
            "$baseUrl/results/${itemId}_${rentalIdResp}_$formattedDate/before/before.jpg";
        final afterImageUrl =
            "$baseUrl/results/${itemId}_${rentalIdResp}_$formattedDate/after/after.jpg";

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("분석 결과"),
            content: SizedBox(
              width: 750,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(damageDetected ? "❌ 파손 감지" : "✅ 정상"),
                  if (lateHours != null && lateFee != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "연체 ${lateHours}시간 / 연체료: ${formatter.format(lateFee)} P",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(children: [
                        Image.network(beforeImageUrl, width: 300, height: 300, fit: BoxFit.contain),
                        const Text("Before"),
                      ]),
                      Column(children: [
                        Image.network(afterImageUrl, width: 300, height: 300, fit: BoxFit.contain),
                        const Text("After"),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  fetchRentedItems();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ 반납 완료!")),
                  );
                },
                child: const Text("확인"),
              ),
            ],
          ),
        );
      } else {
        final respStr = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 반납 실패: $respStr")),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ 반납 실패: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn(context)) {
      return Scaffold(
        appBar: AppBar(title: const Text("🔄 반납할 물품")),
        body: const Center(child: Text("로그인이 필요한 기능입니다.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("🔄 반납할 물품")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rentals.isEmpty
              ? const Center(child: Text("반납할 물품이 없습니다."))
              : ListView.builder(
                  itemCount: rentals.length,
                  itemBuilder: (context, index) {
                    final rental = rentals[index];
                    final item = rental['item'];
                    if (item == null) {
                      return const ListTile(
                        leading: Icon(Icons.error),
                        title: Text("❗ 등록된 아이템 정보를 찾을 수 없습니다."),
                      );
                    }

                    final rentalId = rental['id'];
                    final itemId = item['id'];
                    final endTime = DateTime.parse(rental['end_time']);
                    final now = DateTime.now();
                    final remaining = endTime.difference(now);
                    String remainingText;
                    if (remaining.isNegative) {
                      final overdue = now.difference(endTime);
                      final itemPrice = item['price_per_day'] ?? 0;
                      final overdueDays = (overdue.inHours / 24).ceil();
                      final overdueFee = itemPrice * overdueDays;
                      final penalty = (overdueFee * 0.1).round();
                      remainingText =
                          '⛔ ${overdue.inHours}시간 연체\n연체비용 ${formatter.format(overdueFee)}원 + 벌금 ${formatter.format(penalty)}원';
                    } else {
                      remainingText =
                          '⏰ ${remaining.inHours}시간 ${remaining.inMinutes.remainder(60)}분 남음';
                    }

                    final beforeImageUrl =
                        "$baseUrl/static/images/item_$itemId/before.jpg";

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: Image.network(
                              beforeImageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 40),
                            ),
                            title: Text("${item['name']} (렌탈 ID: $rentalId)"),
                            subtitle: Text("반납 마감: ${rental['end_time']}\n$remainingText"),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton(
                                onPressed: () async {
                                  try {
                                    final doorResponse = await http.post(
                                      Uri.parse("$baseUrl/lockers/open"), // 보관함 여는 API 주소
                                      headers: {"Content-Type": "application/json"},
                                    );

                                    if (doorResponse.statusCode == 200) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("🔓 보관함이 열렸습니다.")),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("❗ 보관함 열기 실패: ${doorResponse.statusCode}")),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("❗ 보관함 열기 중 오류 발생: $e")),
                                    );
                                  }

                                  // 보관함 열기 시도 후 기존 반납 다이얼로그 호출
                                  _showReturnDialog(rentalId, itemId);
                                },
                                child: const Text("반납하기"),
                              ),
                                ElevatedButton(
                                  onPressed: () => extendRental(rentalId),
                                  child: const Text("+1일 연장"),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
