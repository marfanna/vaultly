import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/models.dart';
import '../../services/firebase_service.dart';
import 'document_detail_screen.dart';

enum DocumentViewMode { category, recent, starred, alerts }

class DocumentListScreen extends StatelessWidget {
  final String profileId;
  final String? category;
  final DocumentViewMode viewMode;

  const DocumentListScreen({
    super.key,
    required this.profileId,
    this.category,
    this.viewMode = DocumentViewMode.category,
  });

  String _getTitle() {
    switch (viewMode) {
      case DocumentViewMode.category: return '$category Documents';
      case DocumentViewMode.recent: return 'Recent Uploads';
      case DocumentViewMode.starred: return 'Starred Documents';
      case DocumentViewMode.alerts: return 'Document Alerts';
    }
  }

  String _getEmptyMessage() {
    switch (viewMode) {
      case DocumentViewMode.category: return 'No documents in $category yet.';
      case DocumentViewMode.recent: return 'No recent documents found.';
      case DocumentViewMode.starred: return 'You haven\'t starred any documents yet.';
      case DocumentViewMode.alerts: return 'No document alerts at the moment.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_getTitle()),
      ),
      body: StreamBuilder<List<AppDocument>>(
        stream: FirebaseService.streamDocuments(
          profileId,
          category: viewMode == DocumentViewMode.category ? category : null,
          starredOnly: viewMode == DocumentViewMode.starred,
          limit: viewMode == DocumentViewMode.recent ? 10 : null,
        ),
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
                  Icon(
                    viewMode == DocumentViewMode.starred ? Icons.star_border : Icons.folder_open_outlined, 
                    size: 64, 
                    color: Colors.grey.shade300
                  ),
                  VaultlyTheme.verticalSpace(2),
                  Text(_getEmptyMessage(), style: const TextStyle(color: Colors.grey)),
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
                    '${DateFormat('dd-MM-yyyy').format(doc.createdAt)} ${viewMode != DocumentViewMode.category ? "• ${doc.category}" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Icon(
                    doc.isStarred ? Icons.star : Icons.chevron_right,
                    color: doc.isStarred ? Colors.amber : Colors.grey,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DocumentDetailScreen(document: doc),
                      ),
                    );
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
