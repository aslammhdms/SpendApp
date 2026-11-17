import '../../../data/models/category.dart';

/// How far back to look when working out which categories are used most.
const categoryUseWindow = Duration(days: 90);

/// Orders [categories] for the quick-pick strip: [pinnedId] first (the one
/// just chosen from the full list, or the one being edited), then the most
/// used, then the rest.
///
/// [categories] is expected in the order set in Settings. That order breaks
/// ties and is kept for categories with no recent use, so with no history
/// the strip looks exactly as the person arranged it.
List<Category> orderCategoriesForQuickPick(
  List<Category> categories,
  Map<String, int> useCounts, {
  String? pinnedId,
}) {
  final position = {
    for (var i = 0; i < categories.length; i++) categories[i].id: i,
  };
  int rank(Category c) => c.id == pinnedId ? 0 : 1;

  return [...categories]..sort((a, b) {
      final byPin = rank(a).compareTo(rank(b));
      if (byPin != 0) return byPin;
      final byUse = (useCounts[b.id] ?? 0).compareTo(useCounts[a.id] ?? 0);
      if (byUse != 0) return byUse;
      return position[a.id]!.compareTo(position[b.id]!);
    });
}
