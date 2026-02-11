import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/settings_repository.dart';
import '../providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../home/providers/dashboard_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize auth with timeout to prevent hanging
      await ref.read(authProvider.notifier).init().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Auth init timed out, proceeding as unauthenticated');
        },
      );
    } catch (e) {
      debugPrint('Auth init error: $e');
    }

    // Load persisted settings (currency, theme, etc.) into provider state
    try {
      await ref.read(settingsProvider.notifier).loadSettings();
    } catch (e) {
      debugPrint('Settings load error: $e');
    }

    // Initialize sync engine if spreadsheet is configured
    try {
      final settings = ref.read(settingsProvider);
      if (settings.spreadsheetId != null) {
        await ref.read(syncEngineProvider).initialize(settings.spreadsheetId!);
      }
    } catch (e) {
      debugPrint('Sync engine init error: $e');
    }

    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    // Check auth state and onboarding
    final authState = ref.read(authProvider);

    try {
      final settingsRepo = SettingsRepository();
      final isOnboarded = await settingsRepo.isOnboarded();

      if (!mounted) return;

      if (authState == AuthState.authenticated && isOnboarded) {
        context.go('/home');
      } else if (authState == AuthState.authenticated) {
        context.go('/onboarding');
      } else {
        context.go('/welcome');
      }
    } catch (e) {
      debugPrint('Settings check error: $e');
      if (mounted) {
        context.go('/welcome');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        size: 50,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'SpendSheet',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track your expenses effortlessly',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
