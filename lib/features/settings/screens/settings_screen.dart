import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/remote/sync_engine.dart';
import '../providers/settings_provider.dart';
import '../widgets/sync_status_tile.dart';
import '../../auth/providers/auth_provider.dart';

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
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
            onChanged: (value) {
              settingsNotifier.setNotificationsEnabled(value);
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.warning),
            title: const Text('Budget Alerts'),
            subtitle: const Text('Notify when approaching budget limits'),
            value: settings.budgetAlertsEnabled,
            onChanged: (value) {
              settingsNotifier.setBudgetAlertsEnabled(value);
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('App Lock'),
            subtitle: const Text('Require biometric authentication'),
            value: settings.biometricLockEnabled,
            onChanged: (value) {
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

          // Full Sync
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Full Sync'),
            subtitle: const Text('Re-download all data from Sheets'),
            onTap: () => _confirmFullSync(context),
          ),

          // Sign Out
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
            onTap: () => _confirmSignOut(context),
          ),
          const SizedBox(height: 32),

          // App Version
          Center(
            child: Text(
              'SpendSheet v1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, String currentCurrency) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: CurrencyUtils.allCurrencies.map((currency) {
          return ListTile(
            leading: Text(currency.symbol, style: const TextStyle(fontSize: 20)),
            title: Text(currency.name),
            subtitle: Text(currency.code),
            trailing: currentCurrency == currency.code
                ? const Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () {
              ref.read(settingsProvider.notifier).setCurrency(currency.code);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showThemePicker(BuildContext context, String currentTheme) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_auto),
            title: const Text('System'),
            trailing: currentTheme == 'system'
                ? const Icon(Icons.check, color: AppColors.primary)
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
                ? const Icon(Icons.check, color: AppColors.primary)
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
                ? const Icon(Icons.check, color: AppColors.primary)
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

  void _confirmFullSync(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Full Sync'),
        content: const Text(
            'This will re-download all data from your Google Sheet. Local changes that haven\'t been synced will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(settingsProvider.notifier).fullSync();
              if (mounted) {
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
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
            'Are you sure you want to sign out? Your local data will remain on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).signOut();
              if (mounted) {
                context.go('/welcome');
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
