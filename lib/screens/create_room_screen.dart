import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';
import 'lobby_screen.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  final String playerName;

  const CreateRoomScreen({super.key, required this.playerName});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  @override
  void initState() {
    super.initState();
    _createAndNavigate();
  }

  Future<void> _createAndNavigate() async {
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final uid = await supabase.signInAnonymously();
      final seed = Random().nextInt(1 << 31);

      final room = await supabase.createRoom(
        hostUserId: uid,
        gameSeed: seed,
      );
      final roomId = room['id'].toString();
      final roomCode = room['code'].toString();

      await supabase.addPlayerToRoom(
        roomId: roomId,
        userId: uid,
        playerName: widget.playerName,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            roomId: roomId,
            userId: uid,
            playerName: widget.playerName,
            isHost: true,
            roomCode: roomCode, 
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nepavyko sukurti kambario: $e')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kuriama...'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
