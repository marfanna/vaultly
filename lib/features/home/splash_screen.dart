import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'segment_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _lift;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _lift = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onGetStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, _) => const SegmentSelectionScreen(),
        transitionsBuilder: (ctx, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: Stack(
        children: [
          // Subtle radial glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 0.9,
                  colors: [Color(0xFF1A0E2E), Color(0xFF0A0A12)],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 5),

                  // Logo + wordmark
                  FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _lift,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/images/vaultly_logo.png',
                            width: 72,
                            height: 72,
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'VAULTLY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Personal and business documents,\norganised and always at hand.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 14,
                              height: 1.6,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

                  // CTA
                  FadeTransition(
                    opacity: _fade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GetStartedButton(onTap: _onGetStarted),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'Your data stays on your device.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.22),
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GetStartedButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GetStartedButton({required this.onTap});

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Get started',
                style: TextStyle(
                  color: const Color(0xFF0A0A12),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: Color(0xFF0A0A12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
