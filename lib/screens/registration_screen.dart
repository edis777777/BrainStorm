import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';
import 'home_screen.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final controller = TextEditingController();
  bool isSaving = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> onSubmit() async {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    if (name.length > 10) return;

    setState(() {
      isSaving = true;
    });
    await savePlayerName(name);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(playerName: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brain Storm'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Įveskite savo vardą (daugiausiai 10 simbolių)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Vardas',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isSaving ? null : onSubmit,
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Tęsti'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
