import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/models.dart';
import '../../services/firebase_service.dart';

class DocumentListScreen extends StatelessWidget {
  final String category;
  final String profileName;
  final String profileId;

  const DocumentListScreen({
    super.key,
    required this.category,
    required this.profileName,
    required this.profileId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('$category Documents'),
      ),
      body: StreamBuilder<List<AppDocument>>(
        stream: FirebaseService.streamDocuments(profileId, category: category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final documents = snapshot.data ?? [];

          if (documents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey.shade300),
                  VaultlyTheme.verticalSpace(2),
                  Text('No $category documents yet.', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: 2.paddingAll,
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: VaultlyTheme.primaryLightColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      doc.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                      color: VaultlyTheme.primaryColor,
                    ),
                  ),
                  title: Text(
                    doc.fileName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Uploaded on ${DateFormat('yyyy-MM-dd').format(doc.createdAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to DocumentDetailScreen
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
