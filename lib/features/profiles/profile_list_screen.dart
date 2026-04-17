import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/models.dart';
import '../../services/firebase_service.dart';
import '../../services/auth_service.dart';
import 'profile_dashboard_screen.dart';

class ProfileListScreen extends ConsumerStatefulWidget {
  final VaultSection section;

  const ProfileListScreen({
    super.key,
    required this.section,
  });

  @override
  ConsumerState<ProfileListScreen> createState() => _ProfileListScreenState();
}

class _ProfileListScreenState extends ConsumerState<ProfileListScreen> {
  bool _isActionInProgress = false;

  void _showProfileDialog({AppProfile? profile}) {
    final nameController = TextEditingController(text: profile?.name);
    final labelController = TextEditingController(text: profile?.label);
    bool _isLoadingInDialog = false;

    showDialog(
      context: context,
      barrierDismissible: !_isLoadingInDialog,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(profile == null ? 'Add New Profile' : 'Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                enabled: !_isLoadingInDialog,
                decoration: const InputDecoration(labelText: 'Name (e.g., John Doe)'),
              ),
              TextField(
                controller: labelController,
                enabled: !_isLoadingInDialog,
                decoration: const InputDecoration(labelText: 'Label (e.g., Father, Client A)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isLoadingInDialog ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoadingInDialog
                  ? null
                  : () async {
                      if (nameController.text.isNotEmpty) {
                        setDialogState(() => _isLoadingInDialog = true);
                        try {
                          Navigator.of(context, rootNavigator: true).pop(); // Immediate pop
                          
                          if (profile == null) {
                            final newProfile = AppProfile(
                              id: '',
                              userId: FirebaseService.currentUid ?? 'error',
                              section: widget.section,
                              name: nameController.text,
                              label: labelController.text.isEmpty ? null : labelController.text,
                            );
                            await FirebaseService.createProfile(newProfile);
                          } else {
                            final updatedProfile = AppProfile(
                              id: profile.id,
                              userId: profile.userId,
                              section: profile.section,
                              name: nameController.text,
                              label: labelController.text.isEmpty ? null : labelController.text,
                              categories: profile.categories,
                            );
                            await FirebaseService.updateProfile(updatedProfile);
                          }
                        } catch (e) {
                          print('Profile Action Error: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error saving profile: $e')),
                            );
                          }
                        }
                      }
                    },
              child: _isLoadingInDialog 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(AppProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text('Are you sure you want to delete ${profile.name}? This will also delete all associated documents.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isActionInProgress = true);
      try {
        await FirebaseService.deleteProfile(profile.id);
      } finally {
        if (mounted) setState(() => _isActionInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.section == VaultSection.personal ? 'Personal Vault' : 'Business Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<AppProfile>>(
            stream: FirebaseService.streamProfiles(widget.section),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final profiles = snapshot.data ?? [];
              
              if (profiles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_outlined, size: 64, color: Colors.grey.shade300),
                      VaultlyTheme.verticalSpace(2),
                      const Text('No profiles found.', style: TextStyle(color: Colors.grey)),
                      VaultlyTheme.verticalSpace(1),
                      TextButton(
                        onPressed: () => _showProfileDialog(),
                        child: const Text('Create your first profile'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: 2.paddingAll,
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: VaultlyTheme.primaryColor,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(profile.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: profile.label != null ? Text(profile.label!) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showProfileDialog(profile: profile);
                              } else if (value == 'delete') {
                                _confirmDelete(profile);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                            icon: const Icon(Icons.more_vert),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileDashboardScreen(profile: profile),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          if (_isActionInProgress)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProfileDialog(),
        backgroundColor: VaultlyTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
