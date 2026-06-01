import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'screens/agreement_screen.dart';
import 'screens/home_screen.dart';

class ZephyrApp extends StatefulWidget {
  const ZephyrApp({super.key});

  @override
  State<ZephyrApp> createState() => _ZephyrAppState();
}

class _ZephyrAppState extends State<ZephyrApp> {
  bool? _agreementAccepted;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAgreement();
  }

  Future<void> _checkAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('agreement_accepted') ?? false;
    if (mounted) {
      setState(() {
        _agreementAccepted = accepted;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        cardTheme: const CardTheme(
          color: AppColors.card,
          elevation: 4,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    // 正在检查协议状态
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载...'),
            ],
          ),
        ),
      );
    }

    // 未同意协议，显示协议页面
    if (_agreementAccepted != true) {
      return const AgreementScreen();
    }

    // 已同意协议，显示主页
    return const HomeScreen();
  }
}
