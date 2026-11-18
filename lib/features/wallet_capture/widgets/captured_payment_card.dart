import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/account.dart';
import '../../../data/models/category.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/money_text.dart';
import '../models/captured_payment.dart';

/// One captured payment in the review inbox: what was read, a category and
/// account to file it under, and Add / Dismiss.
class CapturedPaymentCard extends StatefulWidget {
  const CapturedPaymentCard({
    super.key,
    required this.payment,
    required this.categories,
    required this.accounts,
    required this.currency,
    required this.onAdd,
    required this.onDismiss,
    this.suggestedCategoryId,
    this.suggestedAccountId,
  });

  final CapturedPayment payment;
  final List<Category> categories;
  final List<Account> accounts;

  /// The app's currency code, used to format the amount.
  final String currency;
  final String? suggestedCategoryId;
  final String? suggestedAccountId;
  final Future<void> Function(String categoryId, String accountId) onAdd;
  final Future<void> Function() onDismiss;

  @override
  State<CapturedPaymentCard> createState() => _CapturedPaymentCardState();
}

class _CapturedPaymentCardState extends State<CapturedPaymentCard> {
  String? _categoryId;
  String? _accountId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _applySuggestions();
  }

  @override
  void didUpdateWidget(covariant CapturedPaymentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applySuggestions();
  }

  /// Pre-selects remembered choices, and the only account if there is one.
  void _applySuggestions() {
    bool has(Iterable<String> ids, String? id) => id != null && ids.contains(id);
    final categoryIds = widget.categories.map((c) => c.id);
    final accountIds = widget.accounts.map((a) => a.id);
    if (_categoryId == null && has(categoryIds, widget.suggestedCategoryId)) {
      _categoryId = widget.suggestedCategoryId;
    }
    if (_accountId == null) {
      if (has(accountIds, widget.suggestedAccountId)) {
        _accountId = widget.suggestedAccountId;
      } else if (widget.accounts.length == 1) {
        _accountId = widget.accounts.single.id;
      }
    }
  }

  /// True when the notification shows a different currency from the app's.
  bool get _currencyDiffers {
    final shown = widget.payment.currency;
    if (shown == null) return false;
    final app = CurrencyUtils.getCurrency(widget.currency);
    if (shown == app.symbol || shown == app.code) return false;
    // "US$" for an app set to USD ("$").
    if (shown.endsWith(app.symbol)) {
      final prefix = shown.substring(0, shown.length - app.symbol.length);
      if (prefix.isNotEmpty && app.code.startsWith(prefix)) return false;
    }
    return true;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final payment = widget.payment;
    final when = DateFormat.MMMd().add_jm().format(payment.postedAt);
    final details = [
      when,
      if (payment.cardLast4 != null) 'Card ••${payment.cardLast4}',
    ].join(' • ');
    final secondary = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final canAdd = _categoryId != null && _accountId != null && !_busy;
    // The suggestion goes first, so a pre-selected chip is in view without
    // scrolling. A chip tapped by hand stays where it is.
    final suggested = widget.suggestedCategoryId;
    final categories = [
      ...widget.categories.where((c) => c.id == suggested),
      ...widget.categories.where((c) => c.id != suggested),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: Sizes.iconCircle,
                    height: Sizes.iconCircle,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.contactless_outlined,
                      size: Sizes.icon,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.displayName,
                          style: text.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(details, style: secondary),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  MoneyText(
                    payment.amount,
                    currency: widget.currency,
                    kind: MoneyKind.expense,
                    prefix: '-',
                    color: scheme.onSurface,
                    style: text.titleMedium,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.lg,
                0,
              ),
              child: Text(
                // The notification as Google Wallet showed it, so a misread
                // amount or merchant is easy to spot.
                '"${[payment.title, payment.body].where((s) => s.trim().isNotEmpty).join(' — ')}"',
                style: secondary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_currencyDiffers)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.xs,
                  Space.lg,
                  0,
                ),
                child: Text(
                  'Charged in ${payment.currency}. Check the amount before adding.',
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
            const SizedBox(height: Space.md),
            SizedBox(
              height: Sizes.touchTarget,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final icon = iconForEmoji(category.icon);
                  return ChoiceChip(
                    avatar: icon != null
                        ? Icon(icon, size: 18)
                        : Text(category.icon),
                    label: Text(category.name),
                    selected: category.id == _categoryId,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _categoryId = category.id);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              height: Sizes.touchTarget,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                itemCount: widget.accounts.length,
                separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
                itemBuilder: (context, index) {
                  final account = widget.accounts[index];
                  final icon = iconForEmoji(account.icon);
                  return ChoiceChip(
                    avatar: icon != null
                        ? Icon(icon, size: 18)
                        : Text(account.icon),
                    label: Text(account.name),
                    selected: account.id == _accountId,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _accountId = account.id);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: Space.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _run(widget.onDismiss),
                    child: const Text('Dismiss'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: canAdd
                        ? () => _run(
                            () => widget.onAdd(_categoryId!, _accountId!))
                        : null,
                    child: const Text('Add expense'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
