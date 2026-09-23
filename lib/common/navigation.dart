import 'package:flutter_riverpod/legacy.dart';

/// Which bottom-nav tab is showing. Lives outside HomeShell's local state so
/// any screen can request a tab switch (e.g. Dashboard's "go create a trip"
/// prompt) without prop-drilling a callback.
final currentTabProvider = StateProvider<int>((ref) => 1);
