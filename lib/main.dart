import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'features/home/splash_screen.dart';
import 'features/auth/auth_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: VaultlyApp()));
}

class VaultlyApp extends ConsumerWidget {
  const VaultlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Vaultly',
      debugShowCheckedModeBanner: false,
      theme: VaultlyTheme.lightTheme,
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const SplashScreen(); // Logged in, show app starting from Splash
          }
          return const AuthScreen(); // Not logged in, show Auth
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Scaffold(body: Center(child: Text('Auth Error: $err'))),
      ),
    );
  }
}
