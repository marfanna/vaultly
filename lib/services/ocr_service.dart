import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:intl/intl.dart';

class OCRService {
  // Common date regex patterns
  static final List<RegExp> _datePatterns = [
    RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'), // 12/04/2026 or 12-04-26
    RegExp(r'\d{4}[/-]\d{1,2}[/-]\d{1,2}'), // 2026/04/12
    RegExp(r'(\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})', caseSensitive: false), // 12 April 2026
  ];

  static const Map<String, List<String>> _builtinKeywords = {
    'Medical':    ['prescription', 'doctor', 'hospital', 'clinic', 'rx', 'patient', 'diagnosis', 'medicine'],
    'Legal':      ['agreement', 'deed', 'contract', 'legal', 'attorney', 'court', 'lawsuit', 'notary'],
    'Financial':  ['invoice', 'bill', 'receipt', 'tax', 'financial', 'payment', 'statement', 'balance'],
    'Education':  ['school', 'university', 'college', 'degree', 'transcript', 'certificate', 'student', 'enrollment', 'grade', 'academic'],
    'Personal':   [],
  };

  /// Keyword-based classification against built-in categories, then custom ones.
  /// Pass [availableCategories] (the profile's full category list) so custom
  /// folders are also considered as suggestions.
  static String classifyDocument(String text, {List<String>? availableCategories}) {
    final lower = text.toLowerCase();

    // 1. Try built-in keyword matching (only if that category exists in profile)
    for (final entry in _builtinKeywords.entries) {
      if (entry.value.isEmpty) continue;
      final inProfile = availableCategories == null || availableCategories.contains(entry.key);
      if (inProfile && entry.value.any((kw) => lower.contains(kw))) {
        return entry.key;
      }
    }

    // 2. Try matching custom category names directly against OCR text
    if (availableCategories != null) {
      for (final cat in availableCategories) {
        if (_builtinKeywords.containsKey(cat)) continue; // already checked above
        if (lower.contains(cat.toLowerCase())) return cat;
      }
    }

    // 3. Fall back to 'Personal' if present, else first available category
    if (availableCategories != null && availableCategories.isNotEmpty) {
      return availableCategories.contains('Personal')
          ? 'Personal'
          : availableCategories.first;
    }
    return 'Personal';
  }

  /// Extracts text from an image file using Tesseract on-device
  static Future<String> extractText(String imagePath) async {
    try {
      String text = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'eng',
      );
      return text;
    } catch (_) {
      return '';
    }
  }

  /// Extracts a date from text or returns today's date
  static String extractDate(String text) {
    for (var pattern in _datePatterns) {
      var match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0)!;
      }
    }
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  /// Suggests a file name based on extracted date (Format: DD-MM-YYYY)
  static String suggestFileName(String category, String text) {
    final rawDate = extractDate(text);
    try {
      final DateTime dt = DateFormat('yyyy-MM-dd').parse(rawDate);
      return DateFormat('dd-MM-yyyy').format(dt);
    } catch (_) {
      return rawDate;
    }
  }
}
