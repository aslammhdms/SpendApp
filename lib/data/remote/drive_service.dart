import 'package:googleapis/drive/v3.dart' as drive;
import 'package:flutter/foundation.dart';
import '../../core/constants/sheet_constants.dart';
import 'google_auth_service.dart';

class DriveService {
  final GoogleAuthService _authService;

  DriveService(this._authService);

  /// A client for the account signed in right now. It is never kept: one
  /// built for an earlier sign-in would act as that account.
  Future<drive.DriveApi> get _api async {
    final client = await _authService.getAuthClient();
    return drive.DriveApi(client);
  }

  Future<List<SpendSheetFile>> searchForSpendSheets() async {
    try {
      final api = await _api;

      final response = await api.files.list(
        // Only sheets this account owns: a sheet someone else shares must
        // never receive this phone's records.
        q: "mimeType='application/vnd.google-apps.spreadsheet' and name contains '${SheetConstants.spreadsheetTitle}' and trashed=false and 'me' in owners",
        spaces: 'drive',
        $fields: 'files(id, name, modifiedTime, webViewLink)',
        orderBy: 'modifiedTime desc',
      );

      final files = response.files ?? [];
      return files.map((file) => SpendSheetFile(
        id: file.id ?? '',
        name: file.name ?? '',
        modifiedTime: file.modifiedTime,
        webViewLink: file.webViewLink,
      )).toList();
    } catch (e) {
      // Not an empty list: "none found" would invite a duplicate sheet.
      debugPrint('Failed to search for SpendSheets: $e');
      rethrow;
    }
  }

  Future<String?> createReceiptsFolder() async {
    try {
      final api = await _api;

      // Check if folder already exists
      final existingFolders = await api.files.list(
        q: "mimeType='application/vnd.google-apps.folder' and name='${SheetConstants.receiptsFolderName}' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id)',
      );

      if (existingFolders.files?.isNotEmpty == true) {
        return existingFolders.files!.first.id;
      }

      // Create new folder
      final folder = drive.File()
        ..name = SheetConstants.receiptsFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final created = await api.files.create(folder);
      return created.id;
    } catch (e) {
      debugPrint('Failed to create receipts folder: $e');
      return null;
    }
  }
}

class SpendSheetFile {
  final String id;
  final String name;
  final DateTime? modifiedTime;
  final String? webViewLink;

  SpendSheetFile({
    required this.id,
    required this.name,
    this.modifiedTime,
    this.webViewLink,
  });
}
