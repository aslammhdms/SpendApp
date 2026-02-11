import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/remote/sheets_service.dart';
import '../../../data/remote/drive_service.dart';
import '../../../data/remote/google_auth_service.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../auth/providers/auth_provider.dart';

enum SheetSetupState {
  initial,
  loading,
  searchingExisting,
  creating,
  connecting,
  success,
  error,
}

class SheetSetupData {
  final SheetSetupState state;
  final String? spreadsheetId;
  final String? spreadsheetUrl;
  final String? errorMessage;
  final List<SpendSheetFile> existingSheets;

  const SheetSetupData({
    this.state = SheetSetupState.initial,
    this.spreadsheetId,
    this.spreadsheetUrl,
    this.errorMessage,
    this.existingSheets = const [],
  });

  SheetSetupData copyWith({
    SheetSetupState? state,
    String? spreadsheetId,
    String? spreadsheetUrl,
    String? errorMessage,
    List<SpendSheetFile>? existingSheets,
  }) {
    return SheetSetupData(
      state: state ?? this.state,
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      spreadsheetUrl: spreadsheetUrl ?? this.spreadsheetUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      existingSheets: existingSheets ?? this.existingSheets,
    );
  }
}

class SheetSetupNotifier extends StateNotifier<SheetSetupData> {
  final SheetsService _sheetsService;
  final DriveService _driveService;
  final SettingsRepository _settingsRepo;

  SheetSetupNotifier({
    required SheetsService sheetsService,
    required DriveService driveService,
    required SettingsRepository settingsRepo,
  })  : _sheetsService = sheetsService,
        _driveService = driveService,
        _settingsRepo = settingsRepo,
        super(const SheetSetupData());

  Future<void> searchExistingSheets() async {
    state = state.copyWith(state: SheetSetupState.searchingExisting);

    try {
      final sheets = await _driveService.searchForSpendSheets();
      state = state.copyWith(
        state: SheetSetupState.initial,
        existingSheets: sheets,
      );
    } catch (e) {
      state = state.copyWith(
        state: SheetSetupState.error,
        errorMessage: 'Failed to search for existing sheets: $e',
      );
    }
  }

  Future<bool> createNewSheet() async {
    state = state.copyWith(state: SheetSetupState.creating);

    try {
      final spreadsheetId = await _sheetsService.createSpendSheet();
      final spreadsheetUrl = await _sheetsService.getSpreadsheetUrl(spreadsheetId);

      // Save to settings
      await _settingsRepo.setSpreadsheetId(spreadsheetId);
      if (spreadsheetUrl != null) {
        await _settingsRepo.setSpreadsheetUrl(spreadsheetUrl);
      }

      // Create receipts folder
      await _driveService.createReceiptsFolder();

      state = state.copyWith(
        state: SheetSetupState.success,
        spreadsheetId: spreadsheetId,
        spreadsheetUrl: spreadsheetUrl,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        state: SheetSetupState.error,
        errorMessage: 'Failed to create spreadsheet: $e',
      );
      return false;
    }
  }

  Future<bool> connectToSheet(String spreadsheetId) async {
    state = state.copyWith(state: SheetSetupState.connecting);

    try {
      // Validate the spreadsheet
      final isValid = await _sheetsService.validateSpreadsheet(spreadsheetId);

      if (!isValid) {
        state = state.copyWith(
          state: SheetSetupState.error,
          errorMessage: 'This spreadsheet is not a valid SpendSheet.',
        );
        return false;
      }

      final spreadsheetUrl = await _sheetsService.getSpreadsheetUrl(spreadsheetId);

      // Save to settings
      await _settingsRepo.setSpreadsheetId(spreadsheetId);
      if (spreadsheetUrl != null) {
        await _settingsRepo.setSpreadsheetUrl(spreadsheetUrl);
      }

      state = state.copyWith(
        state: SheetSetupState.success,
        spreadsheetId: spreadsheetId,
        spreadsheetUrl: spreadsheetUrl,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        state: SheetSetupState.error,
        errorMessage: 'Failed to connect to spreadsheet: $e',
      );
      return false;
    }
  }

  void reset() {
    state = const SheetSetupData();
  }
}

final sheetsServiceProvider = Provider<SheetsService>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return SheetsService(authService);
});

final driveServiceProvider = Provider<DriveService>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  return DriveService(authService);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final sheetSetupProvider =
    StateNotifierProvider<SheetSetupNotifier, SheetSetupData>((ref) {
  return SheetSetupNotifier(
    sheetsService: ref.watch(sheetsServiceProvider),
    driveService: ref.watch(driveServiceProvider),
    settingsRepo: ref.watch(settingsRepositoryProvider),
  );
});
