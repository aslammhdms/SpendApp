import 'package:flutter/foundation.dart';
import 'account_data_service.dart';

/// Decides what happens to the data on this device when the signed-in
/// Google account changes.
///
/// Local data is a copy of one account's spreadsheet. It may only be shown
/// to, and synced by, the account it belongs to: otherwise the next person
/// to sign in would see the previous person's finances, and their changes
/// would be sent to the wrong spreadsheet.
class AccountSession {
  AccountSession({
    required AccountDataService data,
    required Future<void> Function() pushPendingChanges,
    required Future<void> Function() stopSync,
    required Future<void> Function() discardCapturedNotifications,
    required void Function() resetAppState,
  })  : _data = data,
        _pushPendingChanges = pushPendingChanges,
        _stopSync = stopSync,
        _discardCapturedNotifications = discardCapturedNotifications,
        _resetAppState = resetAppState;

  final AccountDataService _data;
  final Future<void> Function() _pushPendingChanges;
  final Future<void> Function() _stopSync;
  final Future<void> Function() _discardCapturedNotifications;
  final void Function() _resetAppState;

  /// Call after [accountId] has signed in, before any local data is shown.
  ///
  /// Data is kept only when it is known to belong to [accountId]. After an
  /// [interactive] sign-in, data with no recorded owner is removed too: it
  /// was saved by a version that did not record owners, so it cannot be
  /// shown to belong to this account. When the app merely restores the
  /// previous session, such data is left alone, because nobody else has
  /// signed in since it was saved; the account is recorded as its owner.
  ///
  /// Returns whether local data was removed.
  Future<bool> onSignedIn(
    String accountId, {
    required bool interactive,
  }) async {
    final owner = await _data.ownerId();
    if (owner == accountId) return false;
    if (owner == null && !interactive) {
      // From here on the data has a known owner, so a different account
      // is always noticed.
      await _data.setOwnerId(accountId);
      return false;
    }

    await _stopSync();
    await _discardCapturedNotifications();
    await _data.clear();
    await _data.setOwnerId(accountId);
    _resetAppState();
    return true;
  }

  /// Call just before signing out, while the account can still reach its
  /// spreadsheet: sends what has not synced yet, then stops syncing.
  Future<void> onSigningOut() async {
    try {
      await _pushPendingChanges().timeout(const Duration(seconds: 15));
    } catch (e) {
      // Offline or too slow. The changes stay queued on the device and
      // are sent if the same account signs in again.
      debugPrint('Sync before sign-out did not finish: $e');
    }
    await _stopSync();
  }

  /// Call after signing out, so nothing loaded for the previous account
  /// stays in memory.
  void onSignedOut() => _resetAppState();
}
