import 'package:flutter_riverpod/legacy.dart';

import '../data/database.dart';

/// Which bottom-nav tab is showing. Lives outside HomeShell's local state so
/// any screen can request a tab switch (e.g. Dashboard's "go create a trip"
/// prompt) without prop-drilling a callback.
final currentTabProvider = StateProvider<int>((ref) => 1);

/// A one-shot request for Инвентарь to open filtered by this condition —
/// set by Профиль's "N вещей требуют ремонта" line just before switching
/// tabs. Инвентарь applies it as it opens, then clears it.
final inventoryConditionRequestProvider = StateProvider<ItemCondition?>((ref) => null);
