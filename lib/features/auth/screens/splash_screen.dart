import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import 'package:go_router/go_router.dart';
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
    // Start after the first frame: initialization updates providers, and
    // Riverpod rejects that while the widget tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
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
        final syncEngine = ref.read(syncEngineProvider);
        await syncEngine.initialize(settings.spreadsheetId!);
        // Full sync if never synced or last sync >24h stale
        final lastSync = await syncEngine.getLastSyncTime();
        final isStale = lastSync != null &&
            DateTime.now().difference(lastSync).inHours >= 24;
        if (lastSync == null) {
          debugPrint('No previous sync found — running initial fullSync');
          await syncEngine.fullSync();
        } else if (isStale) {
          debugPrint('Last sync >24h ago — running fullSync to refresh');
          await syncEngine.fullSync();
        }
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: scheme.surface,
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
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: Radii.xlAll,
                        boxShadow: [
                          BoxShadow(
                            color: context.palette.cardShadow,
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 48,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    Text(
                      'SpendSheet',
                      style: text.headlineMedium
                          ?.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      'Track your expenses effortlessly',
                      style: text.bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: Space.xxl + Space.lg),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: scheme.primary,
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
