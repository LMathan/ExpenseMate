import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardIndexProvider = StateProvider<int>((ref) {
  return 0;
});

final analyticsMonthProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});
