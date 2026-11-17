import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dark_theme.dart';
import 'core/services/biometric_service.dart';
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
import 'features/settings/providers/settings_provider.dart';
import 'features/home/providers/dashboard_provider.dart';
import 'features/transactions/providers/transactions_provider.dart';
import 'features/analytics/providers/analytics_provider.dart';
import 'features/budgets/providers/budgets_provider.dart';
import 'shared/widgets/app_bottom_nav.dart';

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
          return _MainShell(child: child, location: state.uri.path);
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
        path: '/transactions/add',
        builder: (context, state) => const AddEditTransactionScreen(),
      ),
      GoRoute(
        path: '/transactions/edit/:id',
        builder: (context, state) => AddEditTransactionScreen(
          transactionId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/budgets/add',
        builder: (context, state) => const AddEditBudgetScreen(),
      ),
      GoRoute(
        path: '/budgets/edit/:id',
        builder: (context, state) => AddEditBudgetScreen(
          budgetId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        path: '/accounts/add',
        builder: (context, state) => const AddEditAccountScreen(),
      ),
      GoRoute(
        path: '/accounts/edit/:id',
        builder: (context, state) => AddEditAccountScreen(
          accountId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesManagerScreen(),
      ),
      GoRoute(
        path: '/loans',
        builder: (context, state) => const LoansScreen(),
      ),
      GoRoute(
        path: '/loans/add',
        builder: (context, state) => const AddLoanScreen(),
      ),
      GoRoute(
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

class _MainShellState extends ConsumerState<_MainShell> {
  int _currentIndex = 0;

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
    _currentIndex = _getSelectedIndex();
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
      body: widget.child,
      bottomNavigationBar: AppBottomNav(currentIndex: _getSelectedIndex()),
    );
  }
}

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
      isLockEnabled: settings.biometricLockEnabled,
      child: MaterialApp.router(
        title: 'SpendSheet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: DarkTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}

class _BiometricLockGuard extends StatefulWidget {
  final Widget child;
  final BiometricService biometricService;
  final bool isLockEnabled;

  const _BiometricLockGuard({
    required this.child,
    required this.biometricService,
    required this.isLockEnabled,
  });

  @override
  State<_BiometricLockGuard> createState() => _BiometricLockGuardState();
}

class _BiometricLockGuardState extends State<_BiometricLockGuard>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _wasPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isLockEnabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasPaused = true;
    } else if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      setState(() => _isLocked = true);
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    final success = await widget.biometricService.authenticate(
      'Unlock SpendSheet',
    );
    if (success && mounted) {
      setState(() => _isLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (_isLocked)
            MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock,
                        size: 64,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'SpendSheet is Locked',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _authenticate,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Tap to Unlock'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
