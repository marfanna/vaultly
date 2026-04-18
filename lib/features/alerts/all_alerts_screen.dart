import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/models.dart';
import '../../services/firebase_service.dart';
import '../documents/document_detail_screen.dart';

enum _ExpiryStatus { expired, critical, warning, upcoming }

class AllAlertsScreen extends StatefulWidget {
  const AllAlertsScreen({super.key});

  @override
  State<AllAlertsScreen> createState() => _AllAlertsScreenState();
}

class _AllAlertsScreenState extends State<AllAlertsScreen> {
  Map<String, AppProfile> _profileMap = {};

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final results = await Future.wait([
      FirebaseService.streamProfiles(VaultSection.personal).first,
      FirebaseService.streamProfiles(VaultSection.business).first,
    ]);
    if (mounted) {
      setState(() {
        _profileMap = {
          for (final list in results)
            for (final p in list)
              p.id: p,
        };
      });
    }
  }

  _ExpiryStatus _expiryStatus(DateTime expiry) {
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft < 0)   return _ExpiryStatus.expired;
    if (daysLeft <= 14) return _ExpiryStatus.critical;
    if (daysLeft <= 30) return _ExpiryStatus.warning;
    return _ExpiryStatus.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Alerts')),
      body: StreamBuilder<List<AppDocument>>(
        stream: FirebaseService.streamExpiringDocuments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none, size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 20),
                    Text(
                      'No expiring documents',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Documents expiring within 90 days\nwill appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) => _buildAlertTile(context, docs[index]),
          );
        },
      ),
    );
  }

  Widget _buildAlertTile(BuildContext context, AppDocument doc) {
    final status = _expiryStatus(doc.expiryDate!);
    final daysLeft = doc.expiryDate!.difference(DateTime.now()).inDays;
    final profile = _profileMap[doc.profileId];

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
        statusLabel = daysLeft == 0
            ? 'Expires today'
            : 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}';
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

    final sectionLabel = profile != null
        ? '${profile.section.name[0].toUpperCase()}${profile.section.name.substring(1)}'
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
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
                    Text(
                      doc.fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        doc.category,
                        profile?.name,
                        sectionLabel,
                      ].whereType<String>().join('  ·  '),
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
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: statusColor),
                  ),
                  Text(
                    DateFormat('yyyy').format(doc.expiryDate!),
                    style: TextStyle(
                        fontSize: 11,
                        color: statusColor.withValues(alpha: 0.7)),
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
