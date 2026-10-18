import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/navigation.dart';
import 'common/theme.dart';
import 'data/database.dart';
import 'data/providers.dart';
import 'features/add_item/add_item_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/gear_list/gear_list_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/trips/trips_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // One connection, opened here and handed to Riverpod, rather than letting
  // databaseProvider open its own — the app's theme preference has to be
  // read before the first frame, so something has to open the database
  // before runApp regardless.
  final db = AppDatabase();
  final settings = await db.select(db.appSettings).getSingle();
  appThemeMode.value = settings.themeMode;

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const BackpackApp(),
    ),
  );
}

/// A plain `const HomeShell()` below (or a `StatelessWidget` here) would let
/// Flutter treat the whole app subtree as unchanged when the system's
/// light/dark setting flips — [AppColors] reads the platform brightness
/// directly rather than through an `InheritedWidget`, so nothing "depends"
/// on it in the way Flutter's rebuild tracking looks for. Observing
/// [WidgetsBindingObserver] and forcing a `setState` on change is what
/// actually gets every descendant to rebuild and re-read the new colors.
class BackpackApp extends StatefulWidget {
  const BackpackApp({super.key});

  @override
  State<BackpackApp> createState() => _BackpackAppState();
}

class _BackpackAppState extends State<BackpackApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The system-brightness case is covered by the observer below; this
    // covers the user's own choice from Профиль changing instead.
    appThemeMode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appThemeMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backpack',
      theme: buildAppTheme(),
      // Not `const` — a `const HomeShell()` would be the exact same object
      // reference on every rebuild, and Flutter skips rebuilding a child
      // entirely when it's handed the identical widget instance again, which
      // would defeat the observer above.
      home: HomeShell(),
    );
  }
}

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(currentTabProvider);

    return Scaffold(
      // Not `const` here either, for the same reason as `home:` above — a
      // canonicalized const screen widget would never rebuild on a
      // brightness change even though its own ancestor just did.
      body: switch (tab) {
        0 => DashboardScreen(),
        1 => GearListScreen(),
        2 => TripsScreen(),
        _ => ProfileScreen(),
      },
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
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
        decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }
}
