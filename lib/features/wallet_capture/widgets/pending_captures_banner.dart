import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/tokens.dart';
import '../providers/wallet_capture_provider.dart';

/// Home banner shown while Google Wallet payments wait for review, or
/// while capture is on but notification access is missing.
class PendingCapturesBanner extends ConsumerWidget {
  const PendingCapturesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capture = ref.watch(walletCaptureProvider);
    final count = capture.pending.length;
    if (!capture.isSupported || (count == 0 && !capture.needsAccess)) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final title = count > 0
        ? '$count Google Wallet ${count == 1 ? 'payment' : 'payments'} to review'
        : 'Google Wallet capture is paused';
    final subtitle = count > 0
        ? (count == 1
            ? 'Tap to add it as an expense'
            : 'Tap to add them as expenses')
        : 'Allow notification access to resume';

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: Radii.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/wallet-capture'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.md,
            ),
            child: Row(
              children: [
                Icon(Icons.contactless_outlined,
                    color: scheme.onSecondaryContainer),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.titleSmall
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                      Text(
                        subtitle,
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
