import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:intl/intl.dart';

class OCRService {
  // Common date regex patterns
  static final List<RegExp> _datePatterns = [
    RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'), // 12/04/2026 or 12-04-26
    RegExp(r'\d{4}[/-]\d{1,2}[/-]\d{1,2}'), // 2026/04/12
    RegExp(r'(\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})', caseSensitive: false), // 12 April 2026
  ];

  /// Simple keyword-based classification
  static String classifyDocument(String text) {
    text = text.toLowerCase();
    
    if (text.contains('prescription') || 
        text.contains('doctor') || 
        text.contains('hospital') || 
        text.contains('rx')) {
      return 'Medical';
    }
    
    if (text.contains('agreement') || 
        text.contains('deed') || 
        text.contains('contract') ||
        text.contains('legal')) {
      return 'Legal';
    }
    
    if (text.contains('invoice') || 
        text.contains('bill') || 
        text.contains('receipt') || 
        text.contains('tax') ||
        text.contains('financial')) {
      return 'Financial';
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
    } catch (e) {
      print('OCR Error: $e');
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

  /// Suggests a file name based on category and extracted date
  static String suggestFileName(String category, String profileName, String text) {
    final date = extractDate(text);
    return '${category}_${profileName}_$date';
  }
}
