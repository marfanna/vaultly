import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/models.dart';
import '../../services/firebase_service.dart';
import 'document_detail_screen.dart';

enum DocumentViewMode { category, recent, starred, alerts, search }

class DocumentListScreen extends StatefulWidget {
  final String profileId;
  final String? category;
  final DocumentViewMode viewMode;
  final String initialQuery;

  const DocumentListScreen({
    super.key,
    required this.profileId,
    this.category,
    this.viewMode = DocumentViewMode.category,
    this.initialQuery = '',
  });

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  late final TextEditingController _searchCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
    _query = widget.initialQuery;
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _getTitle() {
    switch (widget.viewMode) {
      case DocumentViewMode.category:   return '${widget.category} Documents';
      case DocumentViewMode.recent:     return 'Recent Uploads';
      case DocumentViewMode.starred:    return 'Starred Documents';
      case DocumentViewMode.alerts:     return 'Document Alerts';
      case DocumentViewMode.search:     return '';
    }
  }

  String _getEmptyMessage() {
    switch (widget.viewMode) {
      case DocumentViewMode.category:  return 'No documents in ${widget.category} yet.';
      case DocumentViewMode.recent:    return 'No recent documents found.';
      case DocumentViewMode.starred:   return 'You haven\'t starred any documents yet.';
      case DocumentViewMode.alerts:    return 'No documents expiring in the next 90 days.';
      case DocumentViewMode.search:    return _query.isEmpty ? 'Type to search documents.' : 'No results for "$_query".';
    }
  }

  List<AppDocument> _applySearch(List<AppDocument> docs) {
    if (_query.trim().isEmpty) return docs;
    final q = _query.toLowerCase();
    return docs.where((d) =>
        d.fileName.toLowerCase().contains(q) ||
        d.category.toLowerCase().contains(q)).toList();
  }

  List<AppDocument> _filterForAlerts(List<AppDocument> docs) {
    final cutoff = DateTime.now().add(const Duration(days: 90));
    return docs
        .where((d) => d.expiryDate != null && d.expiryDate!.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
  }

  _ExpiryStatus _expiryStatus(DateTime expiry) {
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft < 0)   return _ExpiryStatus.expired;
    if (daysLeft <= 14) return _ExpiryStatus.critical;
    if (daysLeft <= 30) return _ExpiryStatus.warning;
    return _ExpiryStatus.upcoming;
  }

  PreferredSizeWidget _buildAppBar() {
    if (widget.viewMode == DocumentViewMode.search) {
      return AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search documents...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: InputBorder.none,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _searchCtrl.clear(),
                  )
                : null,
          ),
        ),
      );
    }
    return AppBar(title: Text(_getTitle()));
  }

  @override
  Widget build(BuildContext context) {
    final isSearch = widget.viewMode == DocumentViewMode.search;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: StreamBuilder<List<AppDocument>>(
        stream: FirebaseService.streamDocuments(
          widget.profileId,
          category: widget.viewMode == DocumentViewMode.category ? widget.category : null,
          starredOnly: widget.viewMode == DocumentViewMode.starred,
          limit: widget.viewMode == DocumentViewMode.recent ? 10 : null,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final raw = snapshot.data ?? [];

          final documents = switch (widget.viewMode) {
            DocumentViewMode.alerts => _filterForAlerts(raw),
            DocumentViewMode.search => _applySearch(raw),
            _ => raw,
          };

          if (isSearch && _query.trim().isEmpty) {
            return _buildSearchPlaceholder();
          }

          if (documents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.viewMode == DocumentViewMode.alerts
                        ? Icons.notifications_none_outlined
                        : widget.viewMode == DocumentViewMode.starred
                            ? Icons.star_border
                            : isSearch
                                ? Icons.search_off_rounded
                                : Icons.folder_open_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
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
              return widget.viewMode == DocumentViewMode.alerts
                  ? _buildAlertTile(context, doc)
                  : _buildDefaultTile(context, doc, showCategory: isSearch);
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search_rounded, size: 72, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'Search by name or category',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultTile(BuildContext context, AppDocument doc, {bool showCategory = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: VaultlyTheme.primaryLightColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            doc.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image,
            color: VaultlyTheme.primaryColor,
          ),
        ),
        title: Text(doc.fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          showCategory
              ? '${doc.category}  ·  ${DateFormat('dd MMM yyyy').format(doc.createdAt)}'
              : '${DateFormat('dd-MM-yyyy').format(doc.createdAt)}${widget.viewMode != DocumentViewMode.category ? "  ·  ${doc.category}" : ""}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Icon(
          doc.isStarred ? Icons.star : Icons.chevron_right,
          color: doc.isStarred ? Colors.amber : Colors.grey,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DocumentDetailScreen(document: doc)),
        ),
      ),
    );
  }

  Widget _buildAlertTile(BuildContext context, AppDocument doc) {
    final status = _expiryStatus(doc.expiryDate!);
    final daysLeft = doc.expiryDate!.difference(DateTime.now()).inDays;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    switch (status) {
      case _ExpiryStatus.expired:
        statusColor = Colors.red.shade700;
        statusLabel = 'Expired';
        statusIcon = Icons.error_outline;
      case _ExpiryStatus.critical:
        statusColor = Colors.red;
        statusLabel = daysLeft == 0 ? 'Expires today' : 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}';
        statusIcon = Icons.warning_amber_rounded;
      case _ExpiryStatus.warning:
        statusColor = Colors.orange;
        statusLabel = 'Expires in $daysLeft days';
        statusIcon = Icons.schedule_outlined;
      case _ExpiryStatus.upcoming:
        statusColor = Colors.amber.shade700;
        statusLabel = 'Expires in $daysLeft days';
        statusIcon = Icons.schedule_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.4), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DocumentDetailScreen(document: doc)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.fileName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                      '${doc.category}  ·  Uploaded ${DateFormat('dd MMM yyyy').format(doc.createdAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('dd MMM').format(doc.expiryDate!),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: statusColor),
                  ),
                  Text(
                    DateFormat('yyyy').format(doc.expiryDate!),
                    style: TextStyle(fontSize: 11, color: statusColor.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ExpiryStatus { expired, critical, warning, upcoming }
