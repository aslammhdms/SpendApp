import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/category.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/empty_state.dart';

/// Shows every category in a searchable grid and returns the one chosen, or
/// null if the sheet is dismissed.
Future<Category?> showCategoryPicker(
  BuildContext context, {
  required List<Category> categories,
  String? selectedId,
}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => CategoryPickerSheet(
      categories: categories,
      selectedId: selectedId,
    ),
  );
}

class CategoryPickerSheet extends StatefulWidget {
  const CategoryPickerSheet({
    super.key,
    required this.categories,
    this.selectedId,
  });

  /// In the order set in Settings, so each category is always found in the
  /// same place.
  final List<Category> categories;
  final String? selectedId;

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.categories
        : widget.categories
            .where((c) => c.name.toLowerCase().contains(query))
            .toList();

    // Two lines of label under a 40dp icon, growing with the text size.
    final labelHeight = media.textScaler.scale(16) * 2;
    final tileHeight =
        Space.sm + Sizes.iconCircle + Space.xs + labelHeight + Space.sm;

    return Padding(
      // Keeps the grid above the keyboard while searching.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.xl, 0, Space.xl, Space.md),
              child: Text('Choose category',
                  style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: TextField(
                key: const Key('categorySearchField'),
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search categories',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            Flexible(
              child: matches.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: Space.xl),
                      child: EmptyState(
                        icon: Icons.search_off,
                        title: 'No categories match',
                        compact: true,
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(
                        Space.lg,
                        0,
                        Space.lg,
                        Space.lg,
                      ),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 104,
                        mainAxisExtent: tileHeight,
                        mainAxisSpacing: Space.sm,
                        crossAxisSpacing: Space.xs,
                      ),
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final category = matches[index];
                        return _CategoryTile(
                          category: category,
                          selected: category.id == widget.selectedId,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context, category);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground =
        selected ? scheme.onSecondaryContainer : scheme.onSurface;
    final name = category.name.trim();
    final isOneWord = !name.contains(RegExp(r'\s'));
    final label = Text(
      name,
      style: theme.textTheme.labelMedium?.copyWith(
        color: foreground,
        fontWeight: selected ? FontWeight.w600 : null,
        letterSpacing: 0,
      ),
      textAlign: TextAlign.center,
      maxLines: isOneWord ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: Radii.mdAll,
        child: InkWell(
          borderRadius: Radii.mdAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: Space.sm,
            ),
            child: Column(
              children: [
                CategoryIcon(
                  emoji: category.icon,
                  color: Color(category.color),
                ),
                const SizedBox(height: Space.xs),
                Expanded(
                  // A long single word ("Transportation") shrinks to fit
                  // rather than breaking in the middle.
                  child: isOneWord
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: label,
                        )
                      : label,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
