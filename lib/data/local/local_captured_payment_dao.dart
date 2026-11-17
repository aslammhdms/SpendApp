import 'package:sqflite/sqflite.dart';
import '../../features/wallet_capture/models/captured_payment.dart';
import 'database_helper.dart';

/// Payments captured from Google Wallet notifications (device-local).
class LocalCapturedPaymentDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  /// Stores [payment] unless one with the same ID exists. Returns whether
  /// it was new.
  Future<bool> insertIfNew(CapturedPayment payment) async {
    final db = await _db;
    final rowId = await db.insert(
      'captured_payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return rowId != 0;
  }

  Future<List<CapturedPayment>> getPending() async {
    final db = await _db;
    final rows = await db.query(
      'captured_payments',
      where: 'status = ?',
      whereArgs: [CaptureStatus.pending.name],
      orderBy: 'posted_at DESC',
    );
    return rows.map(CapturedPayment.fromMap).toList();
  }

  Future<CapturedPayment?> getById(String id) async {
    final db = await _db;
    final rows =
        await db.query('captured_payments', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : CapturedPayment.fromMap(rows.first);
  }

  Future<int> getPendingCount() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM captured_payments WHERE status = ?',
      [CaptureStatus.pending.name],
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<void> markAdded(String id, String transactionId) async {
    final db = await _db;
    await db.update(
      'captured_payments',
      {'status': CaptureStatus.added.name, 'transaction_id': transactionId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markDismissed(String id) async {
    final db = await _db;
    await db.update(
      'captured_payments',
      {'status': CaptureStatus.dismissed.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Removes handled payments older than [cutoff]. Their IDs are only
  /// needed while Android might still show the same notification again.
  Future<int> deleteHandledBefore(DateTime cutoff) async {
    final db = await _db;
    return db.delete(
      'captured_payments',
      where: 'status != ? AND posted_at < ?',
      whereArgs: [CaptureStatus.pending.name, cutoff.toIso8601String()],
    );
  }

  Future<int> deleteAll() async {
    final db = await _db;
    return db.delete('captured_payments');
  }
}
