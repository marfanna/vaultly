import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isStarred = false;
  final TextEditingController _searchController = TextEditingController();

  Future<void> _pickAndProcessDocument(AppProfile currentProfile) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isProcessing = true);
      
      final path = result.files.single.path!;
      final extractedText = await OCRService.extractText(path);
      
      setState(() => _isProcessing = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OCRConfirmationScreen(
              file: File(path),
              extractedText: extractedText,
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
                  print('Add Folder Error: $e');
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showProfileOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Vault'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Lock with Biometrics'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Clear Recent Activity', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context),
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
              try {
                await FirebaseService.removeCategory(profile.id, category);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Folder "$category" deleted.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
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
                    icon: Icon(_isStarred ? Icons.star : Icons.star_border, 
                              color: _isStarred ? Colors.amber : null),
                    onPressed: () => setState(() => _isStarred = !_isStarred),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: _showProfileOptions,
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
                                  color: Colors.white.withOpacity(0.8),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    icon: Icon(Icons.search, color: Colors.white),
                                    hintText: 'Search documents...',
                                    hintStyle: TextStyle(color: Colors.white70),
                                    border: InputBorder.none,
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
                      color: Colors.black.withOpacity(0.5),
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
        color: VaultlyTheme.primaryLightColor.withOpacity(0.3),
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
