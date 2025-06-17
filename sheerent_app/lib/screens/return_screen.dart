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

enum RentalUnit { hour, day }

class ReturnScreen extends StatefulWidget {
  const ReturnScreen({super.key});

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  List rentals = [];
  bool loading = false;
  List<File> selectedImages = [];
  final TextEditingController _extendController = TextEditingController(text: '1');
  String _extendUnit = 'days';
  int loggedInUserPoint = 0; // ✅ 이 줄 추가

  int rentalAmount = 1;
  RentalUnit rentalUnit = RentalUnit.hour;
  bool insuranceSelected = false;

  @override
  void initState() {
    super.initState();
    if (isLoggedIn(context)) {
      fetchRentedItems();
      fetchUserPoint();
    }
  }

  @override
  void dispose() {
    _extendController.dispose();
    super.dispose();
  }

Future<bool> fetchInsuranceStatus(int rentalId) async {
  final url = Uri.parse('$baseUrl/rentals/$rentalId');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['has_insurance'] ?? false;
  }

  return false;
}

  Future<void> fetchUserPoint() async {
  final userId = context.read<AuthProvider>().userId;
  final url = Uri.parse('$baseUrl/users/$userId');

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        loggedInUserPoint = data['point'] ?? 0;
      });
    } else {
      debugPrint("❌ 포인트 불러오기 실패: ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("❌ 포인트 불러오기 오류: $e");
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

  Future<void> extendRental(int rentalId, int amount, String unit, bool hasInsurance) async {
    final url = Uri.parse(
  "$baseUrl/rentals/$rentalId/extend?$unit=$amount&has_insurance=${insuranceSelected.toString()}");
    final response = await http.put(url);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final deducted = data['deducted_point'];
      final msg = "✅ 대여 기간이 연장되었습니다. 차감: ${formatter.format(deducted)} P";
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

  Future<void> payLateFee(int rentalId) async {
    final url = Uri.parse("$baseUrl/rentals/$rentalId/pay_late_fee");
    final response = await http.post(url);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final deducted = data['deducted_points'] ?? 0;
      final userPoint = data['user_point'];
      if (userPoint != null) {
        loggedInUserPoint = userPoint;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('연체료 ${formatter.format(deducted)} P 결제 완료')),
      );
      fetchRentedItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 연체료 결제 실패: ${response.statusCode}')),
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

void _showExtendDialog(int rentalId, Map<String, dynamic> itemData, String endTimeStr) async {
  rentalAmount = 1;
  rentalUnit = RentalUnit.hour;

  final hasInsurance = await fetchInsuranceStatus(rentalId); // ✅ 보험 여부 서버에서 조회

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;

          final unit = itemData['unit'];
          final pricePerDay = (itemData['price_per_day'] ?? 0).toDouble();
          final pricePerHour = (unit == 'per_day') ? pricePerDay / 24 : pricePerDay;
          final rentalHours = rentalAmount * (rentalUnit == RentalUnit.day ? 24 : 1);
          final rentalPrice = pricePerHour * rentalHours;
          final insuranceFee = hasInsurance ? pricePerHour * 0.05 * rentalHours : 0;
          final fee = rentalPrice * 0.05;
          final totalPay = rentalPrice + fee + insuranceFee;

          final DateTime originalEndTime = DateTime.parse(endTimeStr);
          final DateTime returnTime = originalEndTime.add(Duration(hours: rentalHours));
          final returnTimeStr =
              "${returnTime.year}-${returnTime.month.toString().padLeft(2, '0')}-${returnTime.day.toString().padLeft(2, '0')} "
              "${returnTime.hour.toString().padLeft(2, '0')}:${returnTime.minute.toString().padLeft(2, '0')}";

          Widget buildExtendOptions() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('대여 단위 선택',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
              ],
            );
          }

Widget buildPaymentSummary() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("💳 결제",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),

      // ✅ 요금 항목들
      Text("물품 가격: ${formatter.format(rentalPrice.round())} P",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      Text("수수료 (5%): ${formatter.format(fee.round())} P",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      if (hasInsurance)
        Text("보험료 (5%): ${formatter.format(insuranceFee.round())} P",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),

      const Divider(height: 24, thickness: 1.2),

      // ✅ 결제 요약 강조
      Text("총 결제 금액: ${formatter.format(totalPay.round())} P",
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)),
      Text("결제 후 남은 금액: ${formatter.format((loggedInUserPoint - totalPay).round())} P",
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),

      const SizedBox(height: 12),

      // ✅ 반납 시간 안내
      Row(
        children: [
          const Icon(Icons.schedule, color: Colors.redAccent, size: 28),
          const SizedBox(width: 8),
          Text('반납 시간: $returnTimeStr',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.redAccent)),
        ],
      ),
    ],
  );
}

          return AlertDialog(
            title: const Text('대여 연장'),
            content: SizedBox(
              width: isMobile ? double.infinity : 700,
              child: SingleChildScrollView(
                child: isMobile
                    ? Column(
                        children: [
                          buildExtendOptions(),
                          const SizedBox(height: 24),
                          buildPaymentSummary(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: buildExtendOptions()),
                          const SizedBox(width: 32),
                          Expanded(child: buildPaymentSummary()),
                        ],
                      ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  if (loggedInUserPoint < totalPay.round()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("❌ 포인트가 부족합니다.")),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  extendRental(
                    rentalId,
                    rentalAmount,
                    rentalUnit == RentalUnit.hour ? "hours" : "days",
                    hasInsurance, // ✅ 자동 전달
                  );
                },
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
    },
  );
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
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 100));

                      // ✅ 보험 여부 서버에서 조회
                      final hasInsurance = await fetchInsuranceStatus(rentalId);
                      await _returnItem(rentalId, itemId, selectedImages.first, hasInsurance);

                      try {
                        final closeResponse = await http.post(
                          Uri.parse("$baseUrl/lockers/close"),
                          headers: {"Content-Type": "application/json"},
                        );

                        if (closeResponse.statusCode == 200) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text("🔒 보관함이 닫혔습니다.")),
                          );
                        } else {
                          messenger.showSnackBar(
                            SnackBar(content: Text("❗ 보관함 닫기 실패: ${closeResponse.statusCode}")),
                          );
                        }
                      } catch (e) {
                        messenger.showSnackBar(
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

Future<void> _returnItem(int rentalId, int itemId, File afterFile, bool hasInsurance) async{
    final uri = Uri.parse("$baseUrl/rentals/$rentalId/return");
    final request = http.MultipartRequest('PUT', uri);

    request.fields['user_id'] = context.read<AuthProvider>().userId.toString();
    request.fields['item_id'] = itemId.toString();
    request.fields['has_insurance'] = hasInsurance.toString();
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
                  if (damageDetected && respJson['has_insurance'] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        "보험 적용: 자기부담금 3만원 차감",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  if (lateHours != null && lateFee != null && lateFee > 0)
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
              if (lateHours != null && lateFee != null && lateFee > 0)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await payLateFee(rentalIdResp);
                  },
                  child: const Text('연체료 결제'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);  // 먼저 다이얼로그 닫기
                    // ✅ 다음 프레임에서 안전하게 처리
                    Future.delayed(Duration.zero, () {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("✅ 반납 완료")),
                      );
                      fetchRentedItems();
                    });
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
  final totalHours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  final days = totalHours ~/ 24;
  final hours = totalHours % 24;

  List<String> parts = [];
  if (days > 0) parts.add("$days일");
  if (hours > 0) parts.add("$hours시간");
  if (minutes > 0) parts.add("$minutes분");
  if (parts.isEmpty) parts.add("0분");

  remainingText = "⏰ ${parts.join(' ')} 남음";
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
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  _showReturnDialog(rentalId, itemId);
                                },
                                child: const Text("반납하기"),
                              ),
                                ElevatedButton(
                                   onPressed: () => _showExtendDialog(rentalId, item, rental['end_time']),
                                  child: const Text("연장하기"),
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
