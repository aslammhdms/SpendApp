/// Where a captured payment stands in the review inbox.
enum CaptureStatus { pending, added, dismissed }

/// A payment read from a Google Wallet notification, waiting for the user to
/// confirm it as an expense.
///
/// Captured payments are stored only on this device. They are not synced to
/// the spreadsheet; the expense created from one is.
class CapturedPayment {
  const CapturedPayment({
    required this.id,
    required this.title,
    required this.body,
    required this.amount,
    required this.postedAt,
    this.currency,
    this.merchant,
    this.cardLast4,
    this.status = CaptureStatus.pending,
    this.transactionId,
  });

  /// Stable ID built from the notification, so the same notification is
  /// never stored twice.
  final String id;

  /// The notification as shown, kept so the user can check what was read.
  final String title;
  final String body;

  final double amount;
  final String? currency;
  final String? merchant;
  final String? cardLast4;
  final DateTime postedAt;
  final CaptureStatus status;

  /// The expense created from this payment, once added.
  final String? transactionId;

  /// What to call this payment in lists and in the expense note.
  String get displayName =>
      merchant ?? (title.trim().isNotEmpty ? title.trim() : 'Google Wallet');

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'amount': amount,
        'currency': currency,
        'merchant': merchant,
        'card_last4': cardLast4,
        'posted_at': postedAt.toIso8601String(),
        'status': status.name,
        'transaction_id': transactionId,
      };

  static CapturedPayment fromMap(Map<String, Object?> map) => CapturedPayment(
        id: map['id'] as String,
        title: map['title'] as String,
        body: map['body'] as String,
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String?,
        merchant: map['merchant'] as String?,
        cardLast4: map['card_last4'] as String?,
        postedAt: DateTime.parse(map['posted_at'] as String),
        status: CaptureStatus.values.byName(map['status'] as String),
        transactionId: map['transaction_id'] as String?,
      );
}
