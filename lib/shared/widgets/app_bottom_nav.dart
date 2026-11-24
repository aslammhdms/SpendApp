import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_palette.dart';
import 'glass_surface.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    // Frosted glass: the shell extends each tab's content under this bar.
    return GlassSurface(
      solidColor: Theme.of(context).colorScheme.surfaceContainer,
      border: Border(top: BorderSide(color: context.palette.glassBorder)),
      child: _buildBar(context),
    );
  }

  Widget _buildBar(BuildContext context) {
    return NavigationBar(
      // The glass behind it is the background.
      backgroundColor: Colors.transparent,
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/transactions');
            break;
          case 2:
            context.go('/analytics');
            break;
          case 3:
            context.go('/budgets');
            break;
          case 4:
            context.go('/settings');
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Transactions',
        ),
        NavigationDestination(
          icon: Icon(Icons.pie_chart_outline),
          selectedIcon: Icon(Icons.pie_chart),
          label: 'Analytics',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'Budgets',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}
