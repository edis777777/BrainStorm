import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'solo_game_screen.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';

class HomeScreen extends StatelessWidget {
  final String playerName;

  const HomeScreen({super.key, required this.playerName});

  @override
  Widget build(BuildContext context) {
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
          
          // Tamsus sluoksnis
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
                      // Antraštės dalis
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
                      const SizedBox(height: 8),
                      Text(
                        playerName,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 50),

                      // Pasirinkimų „dėžutė“
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
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SoloGameScreen(playerName: playerName),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: const Text('Žaisti vienam', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CreateRoomScreen(playerName: playerName),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: const Text('Sukurti kambarį', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => JoinRoomScreen(playerName: playerName),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: const Text('Prisijungti prie kambario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: () {
                                SystemNavigator.pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF121212), // Dark background
                                foregroundColor: colorScheme.primary, // Purple text
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
                              ),
                              child: const Text('Išeiti', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      // Personažas apačioje
                      Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Image.asset(
                          'assets/pasirink.png', 
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

