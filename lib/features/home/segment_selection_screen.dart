import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/models.dart';
import '../profiles/profile_list_screen.dart';

class SegmentSelectionScreen extends StatelessWidget {
  const SegmentSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('VAULTLY'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          const CircleAvatar(
            backgroundColor: VaultlyTheme.primaryLightColor,
            child: Icon(Icons.person, color: VaultlyTheme.primaryColor),
          ),
          VaultlyTheme.horizontalSpace(2),
        ],
      ),
      body: Padding(
        padding: 3.paddingHorizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VaultlyTheme.verticalSpace(2),
            const Text(
              'Select Section',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            VaultlyTheme.verticalSpace(3),
            
            // Personal Card
            _buildSegmentCard(
              context,
              title: 'Personal',
              subtitle: 'Family, Healthcare, Personal IDs',
              icon: Icons.family_restroom,
              color: VaultlyTheme.primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileListScreen(section: VaultSection.personal),
                  ),
                );
              },
            ),
            
            VaultlyTheme.verticalSpace(2),
            
            // Business Card
            _buildSegmentCard(
              context,
              title: 'Business',
              subtitle: 'Clients, Legal, Tax, Contracts',
              icon: Icons.business_center,
              color: const Color(0xFF9C27B0), // Different shade of purple
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileListScreen(section: VaultSection.business),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: 3.paddingAll,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: 2.paddingAll,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            VaultlyTheme.horizontalSpace(2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}
