import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'solo_game_screen.dart';

class HomeScreen extends StatelessWidget {
  final String playerName;

  const HomeScreen({super.key, required this.playerName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proto Mūšis'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                playerName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SoloGameScreen(playerName: playerName),
                        ),
                      );
                    },
                    child: const Text('Žaisti vienam'),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateRoomScreen(playerName: playerName),
                        ),
                      );
                    },
                    child: const Text('Sukurti kambarį'),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JoinRoomScreen(playerName: playerName),
                        ),
                      );
                    },
                    child: const Text('Prisijungti prie kambario'),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Išeiti'),
                    ),
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

