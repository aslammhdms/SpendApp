import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_color_schemes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/app_loader.dart';
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
  /// The splash stays at least this long, so the name has appeared before
  /// the next screen replaces it. Starting up usually takes longer anyway.
  static const Duration _minimumTime = Duration(milliseconds: 700);

  /// Runs once: the name rises into place, and if the app is still getting
  /// ready near the end, the progress line fades in.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final Animation<double> _nameIn = CurvedAnimation(
    parent: _controller,
    curve: Interval(0, 0.4, curve: Motion.spatial),
  );
  late final Animation<double> _nameFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.2),
  );
  late final Animation<double> _progressFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.75, 1),
  );

  final Stopwatch _shown = Stopwatch();

  @override
  void initState() {
    super.initState();
    _shown.start();
    _controller.forward();
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
      // Only for a signed-in account: a signed-out app must not sync.
      final signedIn = ref.read(authProvider) == AuthState.authenticated;
      if (signedIn && settings.spreadsheetId != null) {
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

    // No fixed wait: only what is left of the minimum time, if anything.
    final remaining = _minimumTime - _shown.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);

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
    _controller.dispose();
    super.dispose();
  }

  /// Width and height of the wallet mark: the size Android draws it on its
  /// own launch screen, so the two line up.
  static const double _markSize = 144;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // The brand teal in every theme, like the app icon and Android's
    // launch screen before this one.
    const background = AppColorSchemes.seed;
    const foreground = Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: Stack(
          alignment: Alignment.center,
          children: [
            // Dead center, where Android's launch screen had it.
            const ExcludeSemantics(
              child: Icon(
                Icons.account_balance_wallet,
                size: _markSize,
                color: foreground,
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(top: _markSize + Space.xxl * 2),
                child: FadeTransition(
                  opacity: _nameFade,
                  child: AnimatedBuilder(
                    animation: _nameIn,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(
                          0, reduceMotion ? 0 : Space.xl * (1 - _nameIn.value)),
                      child: child,
                    ),
                    child: Text(
                      'SpendSheet',
                      style: text.headlineLarge?.copyWith(color: foreground),
                    ),
                  ),
                ),
              ),
            ),
            // Only seen when starting up takes a while (the first sync).
            Positioned(
              left: Space.xl,
              right: Space.xl,
              bottom: MediaQuery.paddingOf(context).bottom + Space.xxl,
              child: FadeTransition(
                opacity: _progressFade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLoader(size: 40, color: foreground),
                    const SizedBox(height: Space.md),
                    Text(
                      'Getting your data ready',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
