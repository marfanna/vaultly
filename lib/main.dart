import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'features/home/splash_screen.dart';
import 'features/home/segment_selection_screen.dart';
import 'features/auth/auth_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final prefs = await SharedPreferences.getInstance();
  final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
  runApp(ProviderScope(child: VaultlyApp(onboardingSeen: onboardingSeen)));
}

class VaultlyApp extends ConsumerWidget {
  final bool onboardingSeen;
  const VaultlyApp({super.key, required this.onboardingSeen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      key: ValueKey(authState.asData?.value?.uid ?? 'logged-out'),
      title: 'Vaultly',
      debugShowCheckedModeBanner: false,
      theme: VaultlyTheme.lightTheme,
      home: authState.when(
        data: (user) {
          if (user != null) {
            return onboardingSeen
                ? const SegmentSelectionScreen()
                : const SplashScreen();
          }
          return const AuthScreen();
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Scaffold(body: Center(child: Text('Auth Error: $err'))),
      ),
    );
  }
}
