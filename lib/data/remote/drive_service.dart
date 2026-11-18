import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:flutter/foundation.dart';
import '../../core/constants/sheet_constants.dart';
import 'google_auth_service.dart';

class DriveService {
  final GoogleAuthService _authService;
  drive.DriveApi? _driveApi;

  DriveService(this._authService);

  Future<drive.DriveApi> get _api async {
    if (_driveApi == null) {
      final client = await _authService.getAuthClient();
      _driveApi = drive.DriveApi(client);
    }
    return _driveApi!;
  }

  Future<List<SpendSheetFile>> searchForSpendSheets() async {
    try {
      final api = await _api;

      final response = await api.files.list(
        q: "mimeType='application/vnd.google-apps.spreadsheet' and name contains '${SheetConstants.spreadsheetTitle}'",
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
      debugPrint('Failed to search for SpendSheets: $e');
      return [];
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

  Future<String?> uploadReceipt({
    required File imageFile,
    required String folderId,
    String? customName,
  }) async {
    try {
      final api = await _api;

      final fileName = customName ??
          'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId];

      final media = drive.Media(
        imageFile.openRead(),
        await imageFile.length(),
      );

      final uploaded = await api.files.create(
        driveFile,
        uploadMedia: media,
      );

      // Make file viewable via link
      await api.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        uploaded.id!,
      );

      // Get web view link
      final fileWithLink = await api.files.get(
        uploaded.id!,
        $fields: 'webViewLink, webContentLink',
      ) as drive.File;

      return fileWithLink.webViewLink ?? fileWithLink.webContentLink;
    } catch (e) {
      debugPrint('Failed to upload receipt: $e');
      return null;
    }
  }

  Future<String?> uploadReceiptBytes({
    required Uint8List imageBytes,
    required String folderId,
    String? customName,
  }) async {
    try {
      final api = await _api;

      final fileName = customName ??
          'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId];

      final media = drive.Media(
        Stream.value(imageBytes),
        imageBytes.length,
      );

      final uploaded = await api.files.create(
        driveFile,
        uploadMedia: media,
      );

      // Make file viewable via link
      await api.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        uploaded.id!,
      );

      // Get web view link
      final fileWithLink = await api.files.get(
        uploaded.id!,
        $fields: 'webViewLink, webContentLink',
      ) as drive.File;

      return fileWithLink.webViewLink ?? fileWithLink.webContentLink;
    } catch (e) {
      debugPrint('Failed to upload receipt bytes: $e');
      return null;
    }
  }

  Future<bool> deleteFile(String fileId) async {
    try {
      final api = await _api;
      await api.files.delete(fileId);
      return true;
    } catch (e) {
      debugPrint('Failed to delete file: $e');
      return false;
    }
  }

  Future<drive.File?> getFileInfo(String fileId) async {
    try {
      final api = await _api;
      return await api.files.get(
        fileId,
        $fields: 'id, name, modifiedTime, webViewLink, size',
      ) as drive.File;
    } catch (e) {
      debugPrint('Failed to get file info: $e');
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
