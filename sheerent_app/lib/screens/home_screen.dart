import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'item_detail_page.dart';
import '../globals.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List items = [];
  bool loading = false;
  List<XFile> selectedImages = [];
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAvailableItems();
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> fetchAvailableItems() async {
    setState(() {
      loading = true;
    });

    final url = Uri.parse('$baseUrl/items/available');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final data = json.decode(decoded);
        setState(() {
          items = data;
        });
      } else {
        throw Exception("Failed to load items");
      }
    } catch (e) {
      print("오류 발생: $e");
      setState(() {
        items = [];
      });
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> _registerItem(String name, String desc, int price, int ownerId, List<XFile> imageFiles, String unit) async {
    final uri = Uri.parse("$baseUrl/items/");
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = name;
    request.fields['description'] = desc;
    request.fields['price_per_day'] = price.toString();
    request.fields['owner_id'] = ownerId.toString();
    request.fields['unit'] = unit;

    for (var image in List<XFile>.from(imageFiles)) {
      final multipartFile = await http.MultipartFile.fromPath('files', image.path);
      request.files.add(multipartFile);
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        fetchAvailableItems();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 등록 성공")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 등록 실패: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print("등록 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 등록 중 오류 발생")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('등록된 물품이 없습니다.'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final firstImage =
                        item['images']?.isNotEmpty == true ? item['images'][0] : null;

                    return Card(
                      child: ListTile(
                        leading: firstImage != null
                            ? Image.network(
                                '$baseUrl$firstImage',
                                width: 60,
                                height: 60,
                                fit: BoxFit.contain,
                              )
                            : const Icon(Icons.image),
                        title: Text(item['name'] ?? ''),
                        subtitle: Text("${formatter.format(item['price_per_day'])} P / ${getUnitText(item['unit'])}"),
                        onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItemDetailPage(itemId: item['id']),
                          ),
                        );

                        if (result == true) {
                          fetchAvailableItems();
                        }
                      },
                      ),
                    );
                  },
                ),
    );
  }
}
