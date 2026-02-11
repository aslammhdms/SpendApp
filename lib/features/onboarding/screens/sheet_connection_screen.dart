import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/sheet_setup_provider.dart';
import '../../home/providers/dashboard_provider.dart';

class SheetConnectionScreen extends ConsumerStatefulWidget {
  const SheetConnectionScreen({super.key});

  @override
  ConsumerState<SheetConnectionScreen> createState() =>
      _SheetConnectionScreenState();
}

class _SheetConnectionScreenState extends ConsumerState<SheetConnectionScreen> {
  @override
  void initState() {
    super.initState();
    // Search for existing sheets on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sheetSetupProvider.notifier).searchExistingSheets();
    });
  }

  Future<void> _createNewSheet() async {
    final success = await ref.read(sheetSetupProvider.notifier).createNewSheet();
    if (success && mounted) {
      final setupData = ref.read(sheetSetupProvider);
      if (setupData.spreadsheetId != null) {
        await ref.read(syncEngineProvider).initialize(setupData.spreadsheetId!);
      }
      context.go('/home');
    }
  }

  Future<void> _connectToSheet(String spreadsheetId) async {
    final success = await ref.read(sheetSetupProvider.notifier).connectToSheet(spreadsheetId);
    if (success && mounted) {
      await ref.read(syncEngineProvider).initialize(spreadsheetId);
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupData = ref.watch(sheetSetupProvider);
    final isLoading = setupData.state == SheetSetupState.loading ||
        setupData.state == SheetSetupState.creating ||
        setupData.state == SheetSetupState.connecting ||
        setupData.state == SheetSetupState.searchingExisting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Sheets'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set Up Your SpendSheet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your expense data will be stored in Google Sheets for easy access and backup.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),

              // Create New Option
              _OptionCard(
                icon: Icons.add_circle_outline,
                title: 'Create New SpendSheet',
                description: 'Start fresh with a new spreadsheet',
                onTap: isLoading ? null : _createNewSheet,
                isLoading: setupData.state == SheetSetupState.creating,
              ),

              const SizedBox(height: 16),

              // Existing Sheets
              if (setupData.existingSheets.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Or connect to an existing SpendSheet:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: setupData.existingSheets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final sheet = setupData.existingSheets[index];
                      return _ExistingSheetCard(
                        name: sheet.name,
                        modifiedTime: sheet.modifiedTime,
                        onTap: isLoading
                            ? null
                            : () => _connectToSheet(sheet.id),
                        isLoading: setupData.state == SheetSetupState.connecting,
                      );
                    },
                  ),
                ),
              ] else if (setupData.state == SheetSetupState.searchingExisting) ...[
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Searching for existing SpendSheets...'),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const Spacer(),
              ],

              // Error Message
              if (setupData.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          setupData.errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool isLoading;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExistingSheetCard extends StatelessWidget {
  final String name;
  final DateTime? modifiedTime;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ExistingSheetCard({
    required this.name,
    this.modifiedTime,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.table_chart,
                        color: AppColors.secondary,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (modifiedTime != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Modified ${_formatDate(modifiedTime!)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
