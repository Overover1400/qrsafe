import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

/// Root widget: wires the [GoRouter] and the QRSafe theme into a
/// [MaterialApp.router]. The root [ProviderScope] lives in `main.dart`.
class QRSafeApp extends ConsumerWidget {
  const QRSafeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'QRSafe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
