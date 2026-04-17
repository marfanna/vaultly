import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VaultlyTheme {
  // Spacing based on 8px grid
  static const double gridUnit = 8.0;

  static const Color primaryColor = Color(0xFF6F35A1);
  static const Color primaryLightColor = Color(0xFFDECDFF);
  static const Color accentColor = Color(0xFF6200EE);
  static const Color backgroundColor = Colors.white;
  static const Color surfaceColor = Color(0xFFF5F5F5);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: primaryLightColor,
        onSecondary: primaryColor,
        surface: surfaceColor,
        onSurface: Colors.black,
      ),
      textTheme: GoogleFonts.montserratTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(gridUnit * 3), // 24px
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(gridUnit * 3), // 24px
          side: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        margin: const EdgeInsets.symmetric(vertical: gridUnit),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Spacing Widgets
  static Widget verticalSpace(double multiplier) => SizedBox(height: gridUnit * multiplier);
  static Widget horizontalSpace(double multiplier) => SizedBox(width: gridUnit * multiplier);
}

extension PaddingExtension on num {
  EdgeInsets get paddingAll => EdgeInsets.all(toDouble() * VaultlyTheme.gridUnit);
  EdgeInsets get paddingHorizontal => EdgeInsets.symmetric(horizontal: toDouble() * VaultlyTheme.gridUnit);
  EdgeInsets get paddingVertical => EdgeInsets.symmetric(vertical: toDouble() * VaultlyTheme.gridUnit);
  
  Widget get vertical => SizedBox(height: toDouble() * VaultlyTheme.gridUnit);
  Widget get horizontal => SizedBox(width: toDouble() * VaultlyTheme.gridUnit);
}
