import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/ocr_service.dart';
import '../../services/models.dart';
import '../../services/firebase_service.dart';

class OCRConfirmationScreen extends StatefulWidget {
  final File file;
  final String extractedText;
  final AppProfile profile;
  final String fileType;

  const OCRConfirmationScreen({
    super.key,
    required this.file,
    required this.extractedText,
    required this.profile,
    this.fileType = 'image',
  });

  @override
  State<OCRConfirmationScreen> createState() => _OCRConfirmationScreenState();
}

class _OCRConfirmationScreenState extends State<OCRConfirmationScreen> {
  late TextEditingController _textController;
  late TextEditingController _nameController;
  late String _category;
  DateTime? _expiryDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.extractedText);
    _category = OCRService.classifyDocument(
      widget.extractedText,
      availableCategories: widget.profile.categories,
    );

    final suggestedName =
        OCRService.suggestFileName(_category, widget.extractedText);
    _nameController = TextEditingController(text: suggestedName);
  }

  @override
  void dispose() {
    _textController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verify Document'),
      ),
      body: SingleChildScrollView(
        padding: 3.paddingAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: widget.fileType == 'pdf'
                  ? Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('PDF Document', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : Image.file(
                      widget.file,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
            VaultlyTheme.verticalSpace(3),
            const Text(
              'Extracted Text',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            VaultlyTheme.verticalSpace(1),
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            VaultlyTheme.verticalSpace(3),
            const Text(
              'Document Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            VaultlyTheme.verticalSpace(1),
            _buildDropdown(
              label: 'Category',
              value: _category,
              items: widget.profile.categories,
              onChanged: (val) => setState(() => _category = val!),
            ),
            VaultlyTheme.verticalSpace(2),
            _buildTextField(
              label: 'File Name',
              controller: _nameController,
            ),
            VaultlyTheme.verticalSpace(3),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expiry Date (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_expiryDate == null
                  ? 'Not set'
                  : DateFormat('yyyy-MM-dd').format(_expiryDate!)),
              trailing:
                  const Icon(Icons.calendar_today, color: VaultlyTheme.primaryColor),
              onTap: _selectExpiryDate,
            ),
            VaultlyTheme.verticalSpace(4),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VaultlyTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SAVE TO VAULT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        VaultlyTheme.verticalSpace(0.5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items:
                  items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        VaultlyTheme.verticalSpace(0.5),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveDocument() async {
    final uid = FirebaseService.currentUid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Not authenticated. Please sign in again.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profileId = widget.profile.id;
      if (profileId.isEmpty) throw Exception('Profile ID is missing.');

      final cleanName = FirebaseService.sanitizePath(_nameController.text.trim());
      final safeCategory = FirebaseService.sanitizePath(_category);
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      final storagePath =
          'vault/${widget.profile.section.name}/$profileId/$safeCategory/$uniqueFileName';

      final fileUrl = await FirebaseService.uploadFile(widget.file, storagePath);

      final doc = AppDocument(
        id: '',
        userId: uid,
        profileId: profileId,
        fileUrl: fileUrl,
        fileType: widget.fileType,
        category: _category,
        fileName: _nameController.text.trim(),
        createdAt: DateTime.now(),
        expiryDate: _expiryDate,
      );

      await FirebaseService.saveDocument(doc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document successfully saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save document. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
