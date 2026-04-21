import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';

const _privacyUrl = 'https://marfanna.github.io/vaultly/privacy.html';
const _termsUrl   = 'https://marfanna.github.io/vaultly/terms.html';

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open page. Please try again.')),
      );
    }
  }
}

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  String? _localDisplayName;

  String _resolveDisplayName(User? user) {
    if (_localDisplayName != null) return _localDisplayName!;
    String name = user?.displayName ?? '';
    if (name.isEmpty && user?.email != null) {
      final prefix = (user!.email as String).split('@').first;
      name = prefix[0].toUpperCase() + prefix.substring(1);
    }
    return name.isEmpty ? 'Vaultly User' : name;
  }

  Future<void> _editName(BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Full name',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    final newName = ctrl.text.trim();
    if (confirmed != true || newName.isEmpty) return;

    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);
      if (mounted) setState(() => _localDisplayName = newName);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('Could not update name. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;
    final displayName = _resolveDisplayName(user);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        children: [
          // ── User header ──────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: VaultlyTheme.primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    (user?.email?.isNotEmpty == true)
                        ? user!.email![0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _editName(context, displayName),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.edit_outlined, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text('SUPPORT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1.2)),
          ),

          _Tile(
            icon: Icons.headset_mic_outlined,
            label: 'Help & Contact',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _HelpScreen()),
            ),
          ),
          _Tile(
            icon: Icons.description_outlined,
            label: 'Terms and Conditions',
            onTap: () => _openUrl(context, _termsUrl),
          ),
          _Tile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => _openUrl(context, _privacyUrl),
          ),

          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text('ACCOUNT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1.2)),
          ),

          _Tile(
            icon: Icons.logout,
            label: 'Logout',
            color: Colors.red,
            onTap: () => _confirmLogout(context),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authServiceProvider).signOut();
            },
            child: const Text('LOGOUT', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Shared tile widget ────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _Tile({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.black87;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? VaultlyTheme.primaryColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w500)),
      trailing: color == null
          ? const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

// ── Help screen ───────────────────────────────────────────────────────────────

class _HelpScreen extends StatelessWidget {
  const _HelpScreen();

  static const _phone = '01750118555';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Help & Contact')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: VaultlyTheme.primaryLightColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.support_agent_rounded,
                    size: 48, color: VaultlyTheme.primaryColor),
                const SizedBox(height: 16),
                const Text(
                  'Need help?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reach us directly — we\'re happy to help.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          const Text('PHONE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 12),

          _ContactTile(
            icon: Icons.phone_outlined,
            label: _phone,
            onTap: () => _copyPhone(context),
            trailing: TextButton(
              onPressed: () => _copyPhone(context),
              child: const Text('Copy'),
            ),
          ),

          const SizedBox(height: 32),

          const Text('FAQ',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 12),

          _FaqTile(
            question: 'How do I upload a document?',
            answer: 'Open a profile, tap the + button at the bottom right, then select an image from your gallery.',
          ),
          _FaqTile(
            question: 'Are my documents secure?',
            answer: 'Documents are stored in Firebase cloud storage and access is restricted to your signed-in account by app security rules.',
          ),
          _FaqTile(
            question: 'What is the Alerts section?',
            answer: 'Alerts shows documents with an expiry date within the next 90 days, sorted soonest first.',
          ),
          _FaqTile(
            question: 'Can I lock the app with biometrics?',
            answer: 'You can hide an open profile with a biometric privacy screen for the current session from the ⋮ menu inside that profile.',
          ),
        ],
      ),
    );
  }

  void _copyPhone(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _phone));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone number copied.'), duration: Duration(seconds: 2)),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ContactTile({required this.icon, required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: VaultlyTheme.primaryColor),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.question,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            trailing: Icon(_open ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(widget.answer,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5)),
            ),
        ],
      ),
    );
  }
}

