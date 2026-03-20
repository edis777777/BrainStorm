import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../state/app_providers.dart';
import '../services/supabase_service.dart';
import 'lobby_screen.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  final String playerName;

  const CreateRoomScreen({super.key, required this.playerName});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  bool isCreating = true;
  String? roomId;
  String? roomCode;
  String? userId;

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final uid = await supabase.signInAnonymously();

      final r = Random();
      String? createdRoomId;
      String? createdCode;
      const maxAttempts = 20;

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        final code = r.nextInt(10000).toString().padLeft(4, '0');
        final seed = r.nextInt(1 << 31);
        try {
          final id = await supabase.createRoom(
            hostUserId: uid,
            code: code,
            gameSeed: seed,
          );
          createdRoomId = id;
          createdCode = code;
          break;
        } catch (_) {
          // Most likely collision with unique room code; retry.
          continue;
        }
      }

      if (createdRoomId == null || createdCode == null) {
        throw StateError('Failed to generate a unique room code. Try again.');
      }

      await supabase.addPlayerToRoom(
        roomId: createdRoomId,
        userId: uid,
        playerName: widget.playerName,
      );

      if (!mounted) return;
      setState(() {
        userId = uid;
        roomId = createdRoomId;
        roomCode = createdCode;
        isCreating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isCreating = false);
      // In a real app we'd show a proper dialog.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create room failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Room'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isCreating)
                    const CircularProgressIndicator()
                  else ...[
                    const Text(
                      'Room Code (4 digits)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      roomCode ?? '',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    QrImageView(
                      data: roomCode ?? '',
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.transparent,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (roomId != null && userId != null)
                            ? () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => LobbyScreen(
                                      roomId: roomId!,
                                      userId: userId!,
                                      playerName: widget.playerName,
                                      isHost: true,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: const Text('Open Lobby'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

