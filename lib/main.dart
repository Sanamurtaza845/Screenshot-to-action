import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/theme/app_theme.dart';
import 'features/home/views/home_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScreenshotToActionApp());
}

class ScreenshotToActionApp extends StatelessWidget {
  const ScreenshotToActionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Screenshot to Action',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: const HomeView(),
    );
  }
}