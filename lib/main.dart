import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/navigation.dart';
import 'common/theme.dart';
import 'features/add_item/add_item_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/gear_list/gear_list_screen.dart';
import 'features/trips/trips_screen.dart';

void main() {
  runApp(const ProviderScope(child: BackpackApp()));
}

class BackpackApp extends StatelessWidget {
  const BackpackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backpack',
      theme: buildAppTheme(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(currentTabProvider);

    return Scaffold(
      body: switch (tab) {
        0 => const DashboardScreen(),
        1 => const GearListScreen(),
        2 => const TripsScreen(),
        _ => const Center(child: Text('Скоро здесь что-то будет')),
      },
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Главная',
                    selected: tab == 0,
                    onTap: () => ref.read(currentTabProvider.notifier).state = 0,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.list_alt,
                    label: 'Инвентарь',
                    selected: tab == 1,
                    onTap: () => ref.read(currentTabProvider.notifier).state = 1,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _AddButton(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddItemScreen()),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.map_outlined,
                    label: 'Походы',
                    selected: tab == 2,
                    onTap: () => ref.read(currentTabProvider.notifier).state = 2,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_outline,
                    label: 'Профиль',
                    selected: tab == 3,
                    onTap: () => ref.read(currentTabProvider.notifier).state = 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }
}
