import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_providers.dart'; 
import 'home_screen.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';

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

  // Funkcija, kuri pasileidžia paspaudus mygtuką
  Future<void> onSubmit() async {
    final name = controller.text.trim();
    if (name.isEmpty || name.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vardas turi būti nuo 1 iki 10 simbolių')),
      );
      return;
    }

    setState(() => isSaving = true);
    
    await savePlayerName(name);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(playerName: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Attempt to start music safely.
    audioService.autoPlayOnce();

    // Naudojame spalvas iš tavo Theme
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // 1. FONAS
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/fonas.jpg'), 
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Tamsus sluoksnis ant fono, kad tekstas geriau matytųsi
          Container(color: Colors.black.withOpacity(0.3)),

          // 2. TURINYS
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logotipo tekstas su šešėliu
                      Text(
                        appTitle,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.secondary,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(color: colorScheme.secondary.withOpacity(0.5), blurRadius: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 50),

                      // Įvedimo kortelė (Pusiau permatoma)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colorScheme.secondary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Sveikas atvykęs!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Įveskite savo vardą (iki 10 simb.)',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 25),
                            
                            // Vardo laukas
                            TextField(
                              controller: controller,
                              maxLength: 10,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: 'Tavo vardas',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                counterStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.3),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: colorScheme.secondary.withOpacity(0.5)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: colorScheme.secondary, width: 2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Mygtukas
                            ElevatedButton(
                              onPressed: isSaving ? null : onSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 8,
                                shadowColor: colorScheme.primary.withOpacity(0.5),
                              ),
                              child: isSaving
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('PRADĖTI ŽAIDIMĄ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      // PERSONAŽAS APAČIOJE
                      Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Image.asset(
                          'assets/susipazinkime.png', 
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),         
          
          // Mute / Unmute mygtukas (Top Right)
          Positioned(
            top: 40,
            right: 20,
            child: ValueListenableBuilder<bool>(
              valueListenable: audioService.isPlayingNotifier,
              builder: (context, isPlaying, child) {
                return IconButton(
                  icon: Icon(
                    isPlaying ? Icons.volume_up : Icons.volume_off,
                    color: isPlaying ? colorScheme.secondary : Colors.grey,
                    size: 32,
                  ),
                  onPressed: () {
                    audioService.toggleBackgroundMusic();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}