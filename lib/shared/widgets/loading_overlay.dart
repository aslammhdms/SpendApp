import 'package:material_ui/material_ui.dart';
import '../../core/theme/tokens.dart';
import 'app_loader.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: scheme.scrim.withValues(alpha: 0.4),
            child: Center(
              child: Card(
                color: scheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLoader(),
                      if (message != null) ...[
                        const SizedBox(height: Space.lg),
                        Text(message!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
