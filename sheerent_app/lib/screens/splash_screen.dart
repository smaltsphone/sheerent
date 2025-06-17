import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();

    // 1.5초 후 opacity 줄이기 (애니메이션 시작)
    Future.delayed(const Duration(milliseconds: 1500), () {
      setState(() {
        _opacity = 0.0;
      });
    });

    // 2초 후 홈 화면으로 전환
    Future.delayed(const Duration(milliseconds: 2500), () {
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFffdda4),
      body: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 1000),
          opacity: _opacity,
          child: Image.asset('assets/splash.png', width: 200),
        ),
      ),
    );
  }
}
