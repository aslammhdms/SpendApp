import 'package:material_ui/material_ui.dart';
import '../../core/theme/tokens.dart';

/// Categories and accounts store an emoji as their icon (it is saved in the
/// user's spreadsheet). The UI shows a matching Material icon instead, so
/// icons look the same on every device. Emoji not in this table are shown
/// as they are.
const Map<String, IconData> _iconForEmoji = {
  // Built-in expense categories
  '🍔': Icons.restaurant_outlined,
  '🛒': Icons.shopping_cart_outlined,
  '🚗': Icons.directions_car_outlined,
  '🛍': Icons.shopping_bag_outlined,
  '🎬': Icons.movie_outlined,
  '📱': Icons.smartphone_outlined,
  '🏥': Icons.local_hospital_outlined,
  '📚': Icons.menu_book_outlined,
  '💅': Icons.spa_outlined,
  '🏋': Icons.fitness_center_outlined,
  '🏠': Icons.home_outlined,
  '🛡': Icons.shield_outlined,
  '✈': Icons.flight_outlined,
  '🎁': Icons.card_giftcard_outlined,
  '📺': Icons.tv_outlined,
  '🐾': Icons.pets_outlined,
  '👶': Icons.child_friendly_outlined,
  '🧾': Icons.receipt_long_outlined,
  '📈': Icons.trending_up,
  '💸': Icons.payments_outlined,
  // Built-in income categories
  '💰': Icons.savings_outlined,
  '💻': Icons.laptop_outlined,
  '🏢': Icons.business_outlined,
  '📊': Icons.insights_outlined,
  '🏘': Icons.apartment_outlined,
  '🎀': Icons.redeem_outlined,
  '↩': Icons.undo_rounded,
  '💵': Icons.attach_money,
  // Accounts
  '🏦': Icons.account_balance_outlined,
  '💳': Icons.credit_card_outlined,
  // Other icons offered in the category editor
  '🎮': Icons.sports_esports_outlined,
  '🎵': Icons.music_note_outlined,
  '☕': Icons.coffee_outlined,
  '🍕': Icons.local_pizza_outlined,
  '🍺': Icons.sports_bar_outlined,
  '⛽': Icons.local_gas_station_outlined,
  '🚌': Icons.directions_bus_outlined,
  '🚇': Icons.subway_outlined,
  '🎓': Icons.school_outlined,
  '💊': Icons.medication_outlined,
  '🔧': Icons.build_outlined,
  '🎨': Icons.palette_outlined,
  '📷': Icons.photo_camera_outlined,
  '🎤': Icons.mic_none_outlined,
  '⚽': Icons.sports_soccer_outlined,
  '🏀': Icons.sports_basketball_outlined,
  '🎾': Icons.sports_tennis_outlined,
  '🏊': Icons.pool_outlined,
  '🚴': Icons.directions_bike_outlined,
  '🧘': Icons.self_improvement_outlined,
};

/// Black or white, whichever reads better on [background]. For marks drawn
/// on user-chosen colors (color picker swatches), which the theme can't know.
Color contrastOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);

/// The Material icon for a stored emoji, or null if there is none.
IconData? iconForEmoji(String emoji) =>
    _iconForEmoji[emoji.replaceAll('\uFE0F', '').trim()];

/// A category or account icon in a circle tinted with its [color].
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.emoji,
    required this.color,
    this.size = Sizes.iconCircle,
    this.semanticLabel,
  });

  /// The emoji stored on the category or account.
  final String emoji;

  /// The category's own color; the circle is a light tint of it.
  final Color color;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Lift dark category colors in dark mode so the icon stays legible.
    final fg = isDark
        ? Color.lerp(color, Theme.of(context).colorScheme.onSurface, 0.3)!
        : color;
    final icon = iconForEmoji(emoji);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fg.withValues(alpha: isDark ? 0.18 : 0.14),
          shape: BoxShape.circle,
        ),
        child: icon != null
            ? Icon(icon, size: size * 0.5, color: fg)
            : Text(emoji, style: TextStyle(fontSize: size * 0.45)),
      ),
    );
  }
}
