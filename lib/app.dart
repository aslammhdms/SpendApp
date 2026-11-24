import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'core/services/biometric_service.dart';
import 'core/services/window_protection_service.dart';
import 'features/goals/screens/add_edit_goal_screen.dart';
import 'features/goals/screens/goals_screen.dart';
import 'features/recurring/screens/recurring_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/auth/screens/sign_in_screen.dart';
import 'features/onboarding/screens/sheet_connection_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/transactions/screens/transactions_list_screen.dart';
import 'features/transactions/screens/add_edit_transaction_screen.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/budgets/screens/budgets_screen.dart';
import 'features/budgets/screens/add_edit_budget_screen.dart';
import 'features/accounts/screens/accounts_screen.dart';
import 'features/accounts/screens/add_edit_account_screen.dart';
import 'features/categories/screens/categories_manager_screen.dart';
import 'features/loans/screens/loans_screen.dart';
import 'features/loans/screens/person_loans_screen.dart';
import 'features/loans/screens/add_loan_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/wallet_capture/providers/wallet_capture_provider.dart';
import 'features/wallet_capture/screens/wallet_capture_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/home/providers/dashboard_provider.dart';
import 'features/transactions/providers/transactions_provider.dart';
import 'features/analytics/providers/analytics_provider.dart';
import 'features/budgets/providers/budgets_provider.dart';
import 'shared/widgets/app_bottom_nav.dart';
import 'shared/widgets/sync_list_refresher.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // Splash
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const SheetConnectionScreen(),
      ),

      // Main App with Bottom Navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return _MainShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/transactions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TransactionsListScreen(),
            ),
          ),
          GoRoute(
            path: '/analytics',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: '/budgets',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BudgetsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),

      // Full screen routes (without bottom nav)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/transactions/add',
        builder: (context, state) => const AddEditTransactionScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/transactions/edit/:id',
        builder: (context, state) => AddEditTransactionScreen(
          transactionId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/budgets/add',
        builder: (context, state) => const AddEditBudgetScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/budgets/edit/:id',
        builder: (context, state) => AddEditBudgetScreen(
          budgetId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounts',
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounts/add',
        builder: (context, state) => const AddEditAccountScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/accounts/edit/:id',
        builder: (context, state) => AddEditAccountScreen(
          accountId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/categories',
        builder: (context, state) => const CategoriesManagerScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/wallet-capture',
        builder: (context, state) => const WalletCaptureScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/recurring',
        builder: (context, state) => const RecurringScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/goals',
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/goals/add',
        builder: (context, state) => const AddEditGoalScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/goals/edit/:id',
        builder: (context, state) => AddEditGoalScreen(
          goalId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/loans',
        builder: (context, state) => const LoansScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/loans/add',
        builder: (context, state) => const AddLoanScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/loans/add/:personId',
        builder: (context, state) {
          final personId = state.pathParameters['personId']!;
          final isSettlement = state.uri.queryParameters['settle'] == 'true';
          return AddLoanScreen(
            personId: personId,
            isSettlement: isSettlement,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/loans/person/:id',
        builder: (context, state) => PersonLoansScreen(
          personId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});

class _MainShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const _MainShell({
    required this.child,
    required this.location,
  });

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Payments made while the app was in the background show up on return.
    if (state == AppLifecycleState.resumed) {
      ref.read(walletCaptureProvider.notifier).refresh();
      _openPaymentsIfReminderTapped();
    }
  }

  /// A tapped Google Wallet payment reminder opens the payment list,
  /// whether it started the app or brought it back.
  Future<void> _openPaymentsIfReminderTapped() async {
    final channel = ref.read(walletCaptureChannelProvider);
    try {
      if (!await channel.takeOpenRequest() || !mounted) return;
    } catch (e) {
      debugPrint('Checking for a payment reminder tap failed: $e');
      return;
    }
    final router = GoRouter.of(context);
    final current = router.routerDelegate.currentConfiguration.uri.path;
    if (current != '/wallet-capture') {
      router.push('/wallet-capture');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int _getSelectedIndex() {
    if (widget.location.startsWith('/home')) return 0;
    if (widget.location.startsWith('/transactions')) return 1;
    if (widget.location.startsWith('/analytics')) return 2;
    if (widget.location.startsWith('/budgets')) return 3;
    if (widget.location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = _getSelectedIndex();
    ref
        .read(walletCaptureChannelProvider)
        .listenForReminderTaps(_openPaymentsIfReminderTapped);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _openPaymentsIfReminderTapped());
  }

  @override
  void didUpdateWidget(covariant _MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = _getSelectedIndex();
    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      // Refreshing updates providers, which Riverpod rejects while the
      // widget tree is building, so wait for the frame to finish.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshTab(newIndex);
      });
    }
  }

  void _refreshTab(int index) {
    switch (index) {
      case 0:
        ref.read(dashboardProvider.notifier).refresh();
        break;
      case 1:
        ref.read(transactionsProvider.notifier).loadTransactions(refresh: true);
        break;
      case 2:
        ref.read(analyticsProvider.notifier).loadData();
        break;
      case 3:
        ref.read(budgetsProvider.notifier).loadBudgets();
        break;
      case 4:
        ref.read(settingsProvider.notifier).loadSettings();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tab content runs under the navigation bar, so there is something
      // behind the glass. Each tab pads its scrollable with ScreenInsets.
      extendBody: true,
      body: Builder(
        builder: (context) {
          // extendBody reports the bar's height as padding only. Tabs have
          // their own Scaffold, which places its floating button by
          // viewPadding, so report it there too.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              viewPadding:
                  media.viewPadding.copyWith(bottom: media.padding.bottom),
            ),
            child: widget.child,
          );
        },
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _getSelectedIndex()),
    );
  }
}

/// The stored App Lock switch, as [SettingsRepository] writes it.
const appLockPreferenceKey = 'settings_biometric_lock_enabled';

/// Whether App Lock was on when the app started. Set in `main` before the
/// first frame; the app then opens locked.
final startLockedProvider = Provider<bool>((ref) => false);

class SpendSheetApp extends ConsumerWidget {
  const SpendSheetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    ThemeMode themeMode;
    switch (settings.themeMode) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      default:
        themeMode = ThemeMode.system;
    }

    return _BiometricLockGuard(
      biometricService: ref.watch(biometricServiceProvider),
      windowProtection: ref.watch(windowProtectionServiceProvider),
      isLockEnabled: settings.biometricLockEnabled,
      startLocked: ref.watch(startLockedProvider),
      themeMode: themeMode,
      child: SyncListRefresher(
        child: MaterialApp.router(
          title: 'SpendSheet',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          routerConfig: router,
          builder: (context, child) {
            // System bars follow the active theme on every screen, including
            // those without an app bar.
            final theme = Theme.of(context);
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: theme.appBarTheme.systemOverlayStyle!,
              child: child!,
            );
          },
        ),
      ),
    );
  }
}

class _BiometricLockGuard extends StatefulWidget {
  final Widget child;
  final BiometricService biometricService;
  final WindowProtectionService windowProtection;
  final bool isLockEnabled;
  final bool startLocked;
  final ThemeMode themeMode;

  const _BiometricLockGuard({
    required this.child,
    required this.biometricService,
    required this.windowProtection,
    required this.isLockEnabled,
    required this.startLocked,
    required this.themeMode,
  });

  @override
  State<_BiometricLockGuard> createState() => _BiometricLockGuardState();
}

class _BiometricLockGuardState extends State<_BiometricLockGuard>
    with WidgetsBindingObserver {
  late bool _isLocked = widget.startLocked;
  bool _wasPaused = false;

  /// Android's own credential screen pauses the app while the person
  /// unlocks it; those lifecycle changes must not lock it again.
  bool _authenticating = false;

  /// Whether the loaded settings have shown App Lock on yet. Until they
  /// load, [_BiometricLockGuard.isLockEnabled] reads false, so the value
  /// stored at start-up decides.
  bool _settingsShowedLock = false;

  bool get _lockActive =>
      widget.isLockEnabled ||
      _isLocked ||
      (widget.startLocked && !_settingsShowedLock);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncWindowProtection();
    if (_isLocked) {
      // A fresh start is locked like a return from the background.
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  @override
  void didUpdateWidget(covariant _BiometricLockGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWindowProtection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Keeps the screen out of Recents thumbnails whenever App Lock is on.
  void _syncWindowProtection() {
    if (widget.isLockEnabled) _settingsShowedLock = true;
    widget.windowProtection.setProtected(_lockActive);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_lockActive || _authenticating) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasPaused = true;
      // Cover the content as the app leaves, not only when it returns.
      if (!_isLocked) setState(() => _isLocked = true);
    } else if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      if (!_isLocked) setState(() => _isLocked = true);
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;
    try {
      final success = await widget.biometricService.authenticate(
        'Unlock SpendSheet',
      );
      if (success && mounted) {
        setState(() => _isLocked = false);
      }
    } finally {
      _authenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // Nothing under the lock is read out by a screen reader.
          ExcludeSemantics(excluding: _isLocked, child: widget.child),
          if (_isLocked)
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: widget.themeMode,
              home: Builder(builder: (context) {
                final scheme = Theme.of(context).colorScheme;
                final text = Theme.of(context).textTheme;
                return Scaffold(
                  backgroundColor: scheme.surface,
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 40,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: Space.xl),
                        Text('SpendSheet is Locked', style: text.titleLarge),
                        const SizedBox(height: Space.xxl),
                        FilledButton.icon(
                          onPressed: _authenticate,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Tap to Unlock'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}
