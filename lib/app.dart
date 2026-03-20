import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'state/app_providers.dart';
import 'screens/registration_screen.dart';
import 'screens/home_screen.dart';

class BrainStormApp extends ConsumerWidget {
  const BrainStormApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(playerNameProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkVibrant(),
      home: nameAsync.when(
        data: (name) {
          if (name == null || name.isEmpty) {
            return const RegistrationScreen();
          }
          return HomeScreen(playerName: name);
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Text(
              'Failed to load local name: $err',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

