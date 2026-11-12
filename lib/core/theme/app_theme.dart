import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6254E8);
  static const Color backgroundColor = Color(0xFFF7F7FC);
  static const Color textColor = Color(0xFF202033);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      elevation: 0,
      centerTitle: false,
    ),
    fontFamily: 'Roboto',
  );
}
