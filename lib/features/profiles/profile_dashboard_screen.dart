import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/widgets/folder_card.dart';
import '../../services/models.dart';
import '../../services/ocr_service.dart';
import '../../services/firebase_service.dart';
import '../documents/ocr_confirmation_screen.dart';
import '../documents/document_list_screen.dart';

class ProfileDashboardScreen extends StatefulWidget {
  final AppProfile profile;

  const ProfileDashboardScreen({
    super.key,
    required this.profile,
  });

  @override
  State<ProfileDashboardScreen> createState() => _ProfileDashboardScreenState();
}

class _ProfileDashboardScreenState extends State<ProfileDashboardScreen> {
  bool _isProcessing = false;
  bool _isLocked = false;
  final _localAuth = LocalAuthentication();

  @override
  void dispose() {
    super.dispose();
  }

  // ── Biometric lock ──────────────────────────────────────────────────────────

  Future<void> _lockWithBiometrics() async {
    Navigator.pop(context);
    try {
      final canAuth = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canAuth) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No biometrics available on this device.')),
        );
        return;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to lock this vault',
      );
      if (authenticated && mounted) {
        setState(() => _isLocked = true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric authentication unavailable.')),
      );
    }
  }

  Future<void> _unlockWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock this vault',
      );
      if (authenticated && mounted) setState(() => _isLocked = false);
    } catch (_) {}
  }

  // ── Share vault ─────────────────────────────────────────────────────────────

  Future<void> _shareVault(AppProfile profile, Map<String, int> counts) async {
    Navigator.pop(context);
    final total = counts.values.fold(0, (a, b) => a + b);
    final lines = counts.entries
        .where((e) => e.value > 0)
        .map((e) => '  • ${e.key}: ${e.value} document${e.value == 1 ? '' : 's'}')
        .join('\n');
    final text =
        '📁 ${profile.name} — Vaultly Vault\n\n$total document${total == 1 ? '' : 's'} stored:\n$lines\n\nManaged with Vaultly.';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  // ── Clear recent activity ───────────────────────────────────────────────────

  Future<void> _clearRecentActivity() async {
    Navigator.pop(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Recent Activity?'),
        content: const Text(
            'This will clear your recently viewed documents history. Your documents will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_viewed_${widget.profile.id}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recent activity cleared.')),
    );
  }

  Future<void> _pickAndProcessDocument(AppProfile currentProfile) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isProcessing = true);

      final path = result.files.single.path!;
      final isPdf = path.toLowerCase().endsWith('.pdf');
      final extractedText = isPdf ? '' : await OCRService.extractText(path);

      setState(() => _isProcessing = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OCRConfirmationScreen(
              file: File(path),
              extractedText: extractedText,
              fileType: isPdf ? 'pdf' : 'image',
              profile: currentProfile,
            ),
          ),
        );
      }
    }
  }

  void _openFolder(String category, AppProfile currentProfile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentListScreen(
          profileId: currentProfile.id,
          category: category,
          viewMode: DocumentViewMode.category,
        ),
      ),
    );
  }

  void _showAddCategoryDialog(AppProfile currentProfile) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder Name (e.g., Taxes)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context, rootNavigator: true).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  Navigator.of(context, rootNavigator: true).pop(); // Immediate pop
                  await FirebaseService.addCategory(currentProfile.id, controller.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Folder added!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Failed to add folder. Please try again.')),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showProfileOptions(AppProfile profile, Map<String, int> counts) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Vault'),
              onTap: () => _shareVault(profile, counts),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Lock with Biometrics'),
              onTap: _lockWithBiometrics,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Clear Recent Activity', style: TextStyle(color: Colors.red)),
              onTap: _clearRecentActivity,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'medical': return Icons.medical_services_outlined;
      case 'legal': return Icons.gavel_outlined;
      case 'financial': return Icons.account_balance_wallet_outlined;
      case 'personal': return Icons.person_outline;
      case 'education': return Icons.school_outlined;
      case 'bills': return Icons.receipt_long_outlined;
      case 'staffing': return Icons.people_outline;
      default: return Icons.folder_outlined;
    }
  }

  Color _getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'medical': return Colors.blue;
      case 'legal': return Colors.orange;
      case 'financial': return Colors.green;
      case 'personal': return Colors.purple;
      case 'education': return Colors.indigo;
      case 'bills': return Colors.orangeAccent;
      case 'staffing': return Colors.teal;
      default: return VaultlyTheme.primaryColor;
    }
  }

  void _confirmDeleteFolder(AppProfile profile, String category, int fileCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete the "$category" folder?'),
            if (fileCount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'WARNING: This folder contains $fileCount file(s). Deleting it will NOT delete the files, but they will become harder to find.',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await FirebaseService.removeCategory(profile.id, category);
                messenger.showSnackBar(
                  SnackBar(content: Text('Folder "$category" deleted.')),
                );
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete folder. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('profiles').doc(widget.profile.id).snapshots(),
      builder: (context, profileSnapshot) {
        if (!profileSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final currentProfile = AppProfile.fromFirestore(profileSnapshot.data!);

        return StreamBuilder<Map<String, int>>(
          stream: FirebaseService.streamAllCategoryCounts(currentProfile.id),
          builder: (context, countsSnapshot) {
            final categoryCounts = countsSnapshot.data ?? {};

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                title: Text(currentProfile.name),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showProfileOptions(currentProfile, categoryCounts),
                  ),
                ],
              ),
              body: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: 4.paddingAll,
                          decoration: const BoxDecoration(
                            color: VaultlyTheme.primaryColor,
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentProfile.section == VaultSection.personal ? 'PERSONAL VAULT' : 'BUSINESS VAULT',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              VaultlyTheme.verticalSpace(1),
                              Text(
                                currentProfile.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              VaultlyTheme.verticalSpace(3),
                              
                              // Search Bar
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DocumentListScreen(
                                      profileId: currentProfile.id,
                                      viewMode: DocumentViewMode.search,
                                    ),
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.search, color: Colors.white, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Search documents...',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        Padding(
                          padding: 3.paddingAll,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Categories',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showAddCategoryDialog(currentProfile),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add Folder'),
                                  ),
                                ],
                              ),
                              VaultlyTheme.verticalSpace(2),
                              
                              // Grid of Folders
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: currentProfile.categories.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.85,
                                ),
                                itemBuilder: (context, index) {
                                  final cat = currentProfile.categories[index];
                                  return FolderCard(
                                    title: cat,
                                    icon: _getIconForCategory(cat),
                                    count: categoryCounts[cat] ?? 0,
                                    color: _getColorForCategory(cat),
                                    onTap: () => _openFolder(cat, currentProfile),
                                    onLongPress: () => _confirmDeleteFolder(
                                      currentProfile, 
                                      cat, 
                                      categoryCounts[cat] ?? 0
                                    ),
                                  );
                                },
                              ),
                              
                              VaultlyTheme.verticalSpace(4),
                              
                              const Text(
                                'Quick Actions',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              VaultlyTheme.verticalSpace(2),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildActionButton(
                                    Icons.history, 
                                    'Recent',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DocumentListScreen(
                                          profileId: currentProfile.id,
                                          viewMode: DocumentViewMode.recent,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildActionButton(
                                    Icons.star, 
                                    'Starred',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DocumentListScreen(
                                          profileId: currentProfile.id,
                                          viewMode: DocumentViewMode.starred,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildActionButton(
                                    Icons.notifications, 
                                    'Alerts',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DocumentListScreen(
                                          profileId: currentProfile.id,
                                          viewMode: DocumentViewMode.alerts,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Analyzing Document...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_isLocked)
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFF0A0A12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_rounded, size: 64, color: Colors.white54),
                            const SizedBox(height: 24),
                            const Text(
                              'Vault Locked',
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentProfile.name,
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                            const SizedBox(height: 40),
                            ElevatedButton.icon(
                              onPressed: _unlockWithBiometrics,
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Unlock'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: VaultlyTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => _pickAndProcessDocument(currentProfile),
                backgroundColor: VaultlyTheme.primaryColor,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String label, {VoidCallback? onTap}) {
    return Expanded(
      child: Card(
        color: VaultlyTheme.primaryLightColor.withValues(alpha: 0.3),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: 2.paddingVertical,
            child: Column(
              children: [
                Icon(icon, color: VaultlyTheme.primaryColor),
                VaultlyTheme.verticalSpace(1),
                Text(
                  label,
                  style: const TextStyle(
                    color: VaultlyTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
