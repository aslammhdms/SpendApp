import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/local/database_helper.dart';

/// Keeps track of which Google account the data on this device belongs to,
/// and removes that data when another account takes over.
class AccountDataService {
  AccountDataService({DatabaseHelper? database})
      : _database = database ?? DatabaseHelper.instance;

  final DatabaseHelper _database;

  /// Deliberately outside the `settings_` prefix, so clearing the settings
  /// does not forget the owner.
  static const _ownerKey = 'account.owner_id';

  /// Preferences that describe one account's data rather than the device:
  /// the spreadsheet link and sync time, which budget alerts were shown, and
  /// the categories and accounts remembered for Google Wallet payments.
  static const _accountKeys = [
    'settings_spreadsheet_id',
    'settings_spreadsheet_url',
    'settings_last_sync_at',
  ];
  static const _accountKeyPrefixes = [
    'budget_alert.',
    'wallet_capture.category.',
    'wallet_capture.account.',
  ];

  /// The Google account id the local data belongs to. Null on a fresh
  /// install, and for data saved before owners were recorded.
  Future<String?> ownerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ownerKey);
  }

  Future<void> setOwnerId(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerKey, accountId);
  }

  /// Removes everything that belongs to the current owner and leaves the
  /// app as a fresh install would: default categories and accounts, no
  /// spreadsheet. Device preferences (theme, currency, app lock) are kept.
  Future<void> clear() async {
    await _database.resetToFreshInstall();

    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      final belongsToAccount = _accountKeys.contains(key) ||
          _accountKeyPrefixes.any(key.startsWith);
      if (belongsToAccount) await prefs.remove(key);
    }
    await prefs.remove(_ownerKey);
  }
}
