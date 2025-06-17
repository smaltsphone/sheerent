import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../globals.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  final Map<String, dynamic>? itemToEdit;
  final String? initialLocker;

  const RegisterScreen({this.itemToEdit, this.initialLocker, super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final priceController = TextEditingController();
  List<File> selectedImages = [];
  List<String> allLockers = ["101", "102", "103", "104", "105"];
  List<String> usedLockers = [];
  String _selectedUnit = 'per_day';
  String? _selectedLocker;
  String? existingImageUrl;
  List<String> availableLockers = [];

  bool get isEdit => widget.itemToEdit != null;

  @override
  void initState() {
    super.initState();
    fetchUsedLockers();
    if (isEdit) {
      final item = widget.itemToEdit!;
      nameController.text = item['name'] ?? '';
      descController.text = item['description'] ?? '';
      priceController.text = item['price_per_day'].toString();
      _selectedUnit = item['unit'] ?? 'per_day';
      _selectedLocker = item['locker_number'];
      existingImageUrl = (widget.itemToEdit?['images'] != null && widget.itemToEdit!['images'].isNotEmpty) 
    ? widget.itemToEdit!['images'][0] 
    : null;
    }
    
    fetchLockers();
  }

Future<void> fetchUsedLockers() async {
  final response = await http.get(Uri.parse('$baseUrl/lockers/available'));
  if (response.statusCode == 200) {
    List<dynamic> lockers = jsonDecode(response.body);
    // API가 사용 가능한 보관함 번호를 반환하므로 전체에서 빼서 usedLocker 구함
    usedLockers = allLockers.where((locker) => !lockers.contains(locker)).toList();
    setState(() {});
  } 
}

Future<void> fetchLockers() async {
  final allUrl = Uri.parse("$baseUrl/lockers/all");
  final availableUrl = Uri.parse("$baseUrl/lockers/available");

  try {
    final allResponse = await http.get(allUrl);
    final availableResponse = await http.get(availableUrl);

    if (allResponse.statusCode == 200 && availableResponse.statusCode == 200) {
      final allData = jsonDecode(utf8.decode(allResponse.bodyBytes));
      final availableData = jsonDecode(utf8.decode(availableResponse.bodyBytes));

      if (!mounted) return;

      setState(() {
        allLockers = List<String>.from(allData);
        availableLockers = List<String>.from(availableData);

        // 편집 모드일 때, 기존 보관함 번호가 있어도 선택 가능하도록 세팅
        if (isEdit) {
          final lockerFromEdit = widget.itemToEdit?['locker_number'];
          if (lockerFromEdit != null && allLockers.contains(lockerFromEdit)) {
            _selectedLocker = lockerFromEdit;
          } else {
            _selectedLocker = availableLockers.isNotEmpty ? availableLockers.first : null;
          }
        } else {
          if (availableLockers.isNotEmpty) {
            _selectedLocker = widget.initialLocker != null &&
                    availableLockers.contains(widget.initialLocker)
                ? widget.initialLocker
                : availableLockers.first;
          }
        }
      });
    }
  } catch (e) {
    debugPrint('🚨 보관함 API 호출 오류: $e');
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

  Future<void> _captureImageFromCamera() async {
    final uri = Uri.parse("$baseUrl/locker/capture");
    try {
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName =
            "captured_${DateTime.now().millisecondsSinceEpoch}.jpg";
        final filePath = path.join(tempDir.path, fileName);
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        if (!mounted) return;
        setState(() {
          selectedImages = [file];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("📸 촬영 성공")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 촬영 실패: ${response.statusCode}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 오류 발생: $e")),
        );
      }
    }
  }

  // 보관함 열기 API 호출
  Future<void> _openLocker() async {
    if (_selectedLocker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("보관함을 선택해주세요.")),
      );
      return;
    }
    final uri = Uri.parse("$baseUrl/lockers/open");
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'locker_number': _selectedLocker}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 보관함이 열렸습니다.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 보관함 열기 실패: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ 오류 발생: $e")),
      );
    }
  }

  // 보관함 닫기 및 상태 변경 API 호출
  Future<void> _closeLocker() async {
    if (_selectedLocker == null) return;
    final uri = Uri.parse("$baseUrl/lockers/close");
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'locker_number': _selectedLocker}),
      );
      if (response.statusCode != 200) {
        debugPrint('보관함 닫기 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('보관함 닫기 오류: $e');
    }
  }

Future<bool> _submitItem() async {
  if (!isLoggedIn(context)) {
    requireLogin(context);
    return false;
  }

  final name = nameController.text.trim();
  final desc = descController.text.trim();
  final price = int.tryParse(priceController.text) ?? 0;
  final ownerId = context.read<AuthProvider>().userId!;
  final locker = _selectedLocker;

  if (name.isEmpty ||
      desc.isEmpty ||
      price == 0 ||
      (!isEdit && selectedImages.isEmpty) ||
      locker == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 필드와 보관함을 선택하고 이미지를 등록하세요.")),
      );
    }
    return false;
  }

  if (isEdit) {
    final uri = Uri.parse("$baseUrl/items/${widget.itemToEdit!['id']}");
    final request = http.MultipartRequest('PUT', uri);

    request.fields['name'] = name;
    request.fields['description'] = desc;
    request.fields['price_per_day'] = price.toString();
    request.fields['unit'] = _selectedUnit;
    request.fields['locker_number'] = locker;
    request.fields['status'] = widget.itemToEdit!['status'];

    for (final image in selectedImages) {
      final multipartFile = await http.MultipartFile.fromPath('files', image.path);
      request.files.add(multipartFile);
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      if (!mounted) return false;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await _closeLocker();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ 수정 성공")),
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }

      return true;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 수정 실패: ${response.statusCode}")),
        );
      }
      return false;
    }
  } else {
    final uri = Uri.parse("$baseUrl/items/");
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = name;
    request.fields['description'] = desc;
    request.fields['price_per_day'] = price.toString();
    request.fields['owner_id'] = ownerId.toString();
    request.fields['unit'] = _selectedUnit;
    request.fields['locker_number'] = locker;
    request.fields['status'] = 'available';

    for (final image in selectedImages) {
      final multipartFile = await http.MultipartFile.fromPath('files', image.path);
      request.files.add(multipartFile);
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (!mounted) return false;

      // ✅ 먼저 초기화
      nameController.clear();
      descController.clear();
      priceController.clear();
      setState(() {
        selectedImages.clear();
        _selectedUnit = 'per_day';
        _selectedLocker = null;
      });

      // ✅ 메시지 먼저 띄우고
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ 등록 성공")),
      );

      // ✅ 300ms 지연 후 화면 전환
      await Future.delayed(const Duration(milliseconds: 300));

      // ✅ 보관함 닫기
      await _closeLocker();

      // ✅ 한 번만 push
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/rentals', (route) => false);
      }

      return true;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 등록 실패: ${response.statusCode}")),
        );
      }
      return false;
    }
  }
}

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "✏️ 물품 수정" : "➕ 물품 등록"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: '설명'),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '가격'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text("단위: "),
                  DropdownButton<String>(
                    value: _selectedUnit,
                    onChanged: (val) {
                      setState(() {
                        _selectedUnit = val!;
                      });
                    },
                    items: const [
                      DropdownMenuItem(value: 'per_hour', child: Text("시간")),
                      DropdownMenuItem(value: 'per_day', child: Text("일")),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text("보관함: "),
                  DropdownButton<String>(
                    value: _selectedLocker,
                    hint: const Text("선택"),
                    onChanged: (val) {
                      if (val != null && !usedLockers.contains(val)) {  // 이미 사용 중인 번호는 선택 안됨
                        setState(() {
                          _selectedLocker = val;
                        });
                      }
                    },
                    items: allLockers.map((locker) {
                      final isDisabled = usedLockers.contains(locker); // 이미 등록된 번호면 비활성화
                      return DropdownMenuItem<String>(
                        value: locker,
                        enabled: !isDisabled,
                        child: Text(
                          " $locker",
                          style: TextStyle(
                            color: isDisabled ? Colors.grey : Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _openLocker,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(60, 36),
                    ),
                    child: const Text("Open"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _captureImageFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("촬영"),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: const Icon(Icons.image),
                    label: const Text("갤러리"),
                  ),
                ],
              ),
              if (isEdit && selectedImages.isEmpty && existingImageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Image.network(
                   '$baseUrl$existingImageUrl',
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Text("❌ 이미지 로딩 실패"),
                  ),
                )
              else if (selectedImages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Image.file(
                    selectedImages[0],
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final success = await _submitItem();
                  if (success && mounted && Navigator.canPop(context)) {
                        Navigator.of(context).pop(true);
                      }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: Text(isEdit ? "수정하기" : "등록하기"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
