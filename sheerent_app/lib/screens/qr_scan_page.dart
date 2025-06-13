import 'dart:convert'; // ✅ JSON 파싱 추가
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'register_screen.dart'; // ✅ 등록화면 import 필요
import '../globals.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool scanned = false;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (!scanned) {
        scanned = true;
        controller.pauseCamera();

        final qrCode = scanData.code ?? '';
        try {
          final parsed = jsonDecode(qrCode);
          final locker = parsed['locker_number'];

          if (locker != null) {
            Navigator.pop(context); // 스캔화면 닫고
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RegisterScreen(initialLocker: locker), // ✅ 등록화면으로 이동
              ),
            );
          } else {
            throw FormatException("locker_number 없음");
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ 올바른 QR 코드 형식이 아닙니다.")),
          );
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QR 코드 스캔")),
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Colors.blueAccent,
          borderRadius: 10,
          borderLength: 20,
          borderWidth: 8,
          cutOutSize: 250,
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
