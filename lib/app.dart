import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // 设置状态栏样式
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
    ));

    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        cardTheme: CardTheme(
          color: AppColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.card,
          contentTextStyle: const TextStyle(color: AppColors.textPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.success;
            return AppColors.textTertiary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.success.withOpacity(0.3);
            return AppColors.glassBg;
          }),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: AppColors.glassBg,
          thumbColor: AppColors.primary,
          overlayColor: AppColors.glassHighlight,
        ),
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('正在加载...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_agreementAccepted != true) {
      return const AgreementScreen();
    }

    return const HomeScreen();
  }
}
