import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/constants/category_defaults.dart';
import '../../../data/models/category.dart';
import '../providers/categories_provider.dart';
import '../../transactions/providers/transactions_provider.dart'
    show expenseCategoriesProvider, incomeCategoriesProvider;

class CategoriesManagerScreen extends ConsumerStatefulWidget {
  const CategoriesManagerScreen({super.key});

  @override
  ConsumerState<CategoriesManagerScreen> createState() =>
      _CategoriesManagerScreenState();
}

class _CategoriesManagerScreenState
    extends ConsumerState<CategoriesManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(categoriesManagerProvider.notifier).loadCategories();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoriesManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(
                  state.expenseCategories,
                  CategoryType.expense,
                ),
                _buildCategoryList(
                  state.incomeCategories,
                  CategoryType.income,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(
          _tabController.index == 0
              ? CategoryType.expense
              : CategoryType.income,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, CategoryType type) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            SizedBox(height: 16),
            Text('No categories yet'),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.sm,
        Space.lg,
        Space.fabClearance,
      ),
      itemCount: categories.length,
      onReorderItem: (oldIndex, newIndex) {
        final reordered = List<Category>.from(categories);
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        ref
            .read(categoriesManagerProvider.notifier)
            .reorderCategories(reordered, type);
      },
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          key: ValueKey(category.id),
          margin: const EdgeInsets.only(bottom: Space.sm),
          child: ListTile(
            leading: CategoryIcon(
              emoji: category.icon,
              color: Color(category.color),
            ),
            title: Text(category.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit ${category.name}',
                  onPressed: () => _showEditCategoryDialog(category),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete ${category.name}',
                  onPressed: () => _confirmDelete(category),
                ),
                Icon(
                  Icons.drag_indicator,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  semanticLabel: 'Drag to reorder',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog(CategoryType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CategoryFormSheet(
        type: type,
        onSave: (name, icon, color) async {
          await ref.read(categoriesManagerProvider.notifier).createCategory(
                name: name,
                type: type,
                icon: icon,
                color: color,
              );
          ref.invalidate(expenseCategoriesProvider);
          ref.invalidate(incomeCategoriesProvider);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditCategoryDialog(Category category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CategoryFormSheet(
        category: category,
        type: category.type,
        onSave: (name, icon, color) async {
          await ref.read(categoriesManagerProvider.notifier).updateCategory(
                category.copyWith(name: name, icon: icon, color: color),
              );
          ref.invalidate(expenseCategoriesProvider);
          ref.invalidate(incomeCategoriesProvider);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmDelete(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Are you sure you want to delete "${category.name}"? Transactions using this category will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(categoriesManagerProvider.notifier)
                  .deleteCategory(category.id);
              ref.invalidate(expenseCategoriesProvider);
              ref.invalidate(incomeCategoriesProvider);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final Category? category;
  final CategoryType type;
  final Future<void> Function(String name, String icon, int color) onSave;

  const _CategoryFormSheet({
    this.category,
    required this.type,
    required this.onSave,
  });

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _nameController = TextEditingController();
  String _icon = '📌';
  int _color = 0xFF6366F1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _icon = widget.category!.icon;
      _color = widget.category!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.onSave(_nameController.text.trim(), _icon, _color);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.category != null ? 'Edit Category' : 'New Category',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),

          // Preview
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(_color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: iconForEmoji(_icon) != null
                      ? Icon(iconForEmoji(_icon),
                          size: 28, color: Color(_color))
                      : Text(_icon, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Icons
          Text(
            'Icon',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: CategoryDefaults.availableIcons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final icon = CategoryDefaults.availableIcons[index];
                return GestureDetector(
                  onTap: () => setState(() => _icon = icon),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _icon == icon
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: _icon == icon
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2)
                          : null,
                    ),
                    child: Center(
                      child: iconForEmoji(icon) != null
                          ? Icon(iconForEmoji(icon), size: 22)
                          : Text(icon, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Colors
          Text(
            'Color',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CategoryDefaults.pickerColors.map((color) {
              final colorValue = color.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _color = colorValue),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: _color == colorValue
                        ? Border.all(color: contrastOn(color), width: 3)
                        : null,
                    boxShadow: _color == colorValue
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: _color == colorValue
                      ? Icon(Icons.check, color: contrastOn(color), size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.category != null ? 'Update' : 'Create'),
            ),
          ),
        ],
      ),
    );
  }
}
