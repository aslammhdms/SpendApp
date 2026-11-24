import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/notification_service.dart';
import '../providers/settings_provider.dart';
import '../../wallet_capture/providers/wallet_capture_provider.dart';
import '../widgets/sync_status_tile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/glass_sheet.dart';
import '../../../shared/widgets/glass_dialog.dart';
import '../../../shared/widgets/glass_app_bar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(settingsProvider.notifier).loadSettings();
      final count =
          await ref.read(settingsProvider.notifier).getPendingSyncCount();
      setState(() => _pendingCount = count);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    // Rebuild when the account changes; the value itself is not needed.
    ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      // The list has no padding of its own, so it picks up the bars'
      // insets by itself.
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          // User Info
          if (authNotifier.isSignedIn) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundImage: authNotifier.userPhotoUrl != null
                    ? NetworkImage(authNotifier.userPhotoUrl!)
                    : null,
                child: authNotifier.userPhotoUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(authNotifier.userName ?? 'User'),
              subtitle: Text(authNotifier.userEmail ?? ''),
            ),
            const Divider(),
          ],

          // Sync Status
          SyncStatusTile(
            status: settingsNotifier.syncStatus,
            lastSyncAt: settings.lastSyncAt,
            pendingCount: _pendingCount,
            onSync: () async {
              await settingsNotifier.sync();
              final count = await settingsNotifier.getPendingSyncCount();
              setState(() => _pendingCount = count);
            },
          ),
          const Divider(),

          // Currency
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Currency'),
            subtitle: Text(
              CurrencyUtils.getCurrency(settings.currency).name,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCurrencyPicker(context, settings.currency),
          ),

          // Theme
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: Text(_getThemeLabel(settings.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(context, settings.themeMode),
          ),
          const Divider(),

          // Notifications
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Enable push notifications'),
            value: settings.notificationsEnabled,
            onChanged: (value) async {
              await settingsNotifier.setNotificationsEnabled(value);
              // Google Wallet payment reminders follow this switch too.
              await ref.read(walletCaptureProvider.notifier).syncNotify();
              if (value) _requestNotificationPermission();
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.warning),
            title: const Text('Budget Alerts'),
            subtitle: const Text('Notify when approaching budget limits'),
            value: settings.budgetAlertsEnabled,
            onChanged: (value) {
              settingsNotifier.setBudgetAlertsEnabled(value);
              if (value) _requestNotificationPermission();
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('App Lock'),
            subtitle: const Text('Require biometric authentication'),
            value: settings.biometricLockEnabled,
            onChanged: (value) async {
              if (value) {
                final biometricService = ref.read(biometricServiceProvider);
                final canAuth = await biometricService.canAuthenticate();
                if (!canAuth) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Biometric authentication is not available on this device',
                        ),
                      ),
                    );
                  }
                  return;
                }
                final authenticated = await biometricService.authenticate(
                  'Verify to enable App Lock',
                );
                if (!authenticated) return;
              } else {
                // Turning the lock off is as sensitive as passing it.
                final authenticated = await ref
                    .read(biometricServiceProvider)
                    .authenticate('Verify to turn off App Lock');
                if (!authenticated) return;
              }
              settingsNotifier.setBiometricLockEnabled(value);
            },
          ),
          const Divider(),

          // Spreadsheet
          if (settings.spreadsheetUrl != null)
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('View Spreadsheet'),
              subtitle: const Text('Open in Google Sheets'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                launchUrl(
                  Uri.parse(settings.spreadsheetUrl!),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),

          // Categories
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Manage Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/categories'),
          ),

          // Accounts
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Manage Accounts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/accounts'),
          ),
          const Divider(),

          // Google Wallet capture
          ListTile(
            leading: const Icon(Icons.contactless_outlined),
            title: const Text('Google Wallet payments'),
            subtitle: const Text('Add tap-to-pay purchases as expenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/wallet-capture'),
          ),
          const Divider(),

          // Full Sync
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Full Sync'),
            subtitle: const Text('Re-download all data from Sheets'),
            onTap: () => _confirmFullSync(context),
          ),

          // Sign Out
          ListTile(
            leading:
                Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Sign Out',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => _confirmSignOut(context),
          ),
          const SizedBox(height: 32),

          // App Version
          Center(
            child: Text(
              'SpendSheet v1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, String currentCurrency) {
    showAppSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: CurrencyUtils.allCurrencies.map((currency) {
          return ListTile(
            leading:
                Text(currency.symbol, style: const TextStyle(fontSize: 20)),
            title: Text(currency.name),
            subtitle: Text(currency.code),
            trailing: currentCurrency == currency.code
                ? Icon(Icons.check,
                    color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () async {
              await ref
                  .read(settingsProvider.notifier)
                  .setCurrency(currency.code);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  void _showThemePicker(BuildContext context, String currentTheme) {
    showAppSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_auto),
            title: const Text('System'),
            trailing: currentTheme == 'system'
                ? Icon(Icons.check,
                    color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode('system');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.light_mode),
            title: const Text('Light'),
            trailing: currentTheme == 'light'
                ? Icon(Icons.check,
                    color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode('light');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark'),
            trailing: currentTheme == 'dark'
                ? Icon(Icons.check,
                    color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode('dark');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  String _getThemeLabel(String themeMode) {
    switch (themeMode) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System';
    }
  }

  Future<void> _requestNotificationPermission() async {
    final allowed =
        await ref.read(notificationServiceProvider).requestPermission();
    if (!allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Notifications are blocked for SpendSheet. Allow them in your phone's settings to get budget alerts."),
        ),
      );
    }
  }

  void _confirmFullSync(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: const Text('Full Sync'),
        content: const Text(
            'This will upload changes waiting to sync, then re-download all data from your Google Sheet. Anything that still can\'t be uploaded stays on this device and syncs later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(settingsProvider.notifier).fullSync();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Full sync completed')),
                );
              }
            },
            child: const Text('Sync'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
            'Your data stays in your Google Sheet. The copy on this device '
            'is kept for when you sign in again, and is removed if a '
            'different account signs in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authProvider.notifier).signOut();
              if (!context.mounted) return;
              if (ref.read(authProvider) == AuthState.error) {
                // Still signed in: stay here instead of showing the
                // welcome screen for an account that never left.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not sign out. Please try again.'),
                  ),
                );
                return;
              }
              context.go('/welcome');
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
