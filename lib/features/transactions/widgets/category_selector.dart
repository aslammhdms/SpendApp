import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category.dart';

class CategorySelector extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<Category> onCategorySelected;

  const CategorySelector({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No categories available',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = category.id == selectedCategoryId;

        return _CategoryItem(
          category: category,
          isSelected: isSelected,
          onTap: () => onCategorySelected(category),
        );
      },
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = Color(category.color);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? categoryColor.withOpacity(0.2)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: categoryColor, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                category.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? categoryColor
                          : AppColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategorySelectorBottomSheet extends StatelessWidget {
  final List<Category> expenseCategories;
  final List<Category> incomeCategories;
  final String? selectedCategoryId;
  final bool isExpense;
  final ValueChanged<Category> onCategorySelected;

  const CategorySelectorBottomSheet({
    super.key,
    required this.expenseCategories,
    required this.incomeCategories,
    this.selectedCategoryId,
    required this.isExpense,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = isExpense ? expenseCategories : incomeCategories;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Category',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: CategorySelector(
                categories: categories,
                selectedCategoryId: selectedCategoryId,
                onCategorySelected: (category) {
                  onCategorySelected(category);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
