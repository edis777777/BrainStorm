import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';
import 'lobby_screen.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  final String playerName;

  const JoinRoomScreen({super.key, required this.playerName});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final codeController = TextEditingController();
  bool isJoining = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> join() async {
    final code = codeController.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Įveskite galiojantį 4 skaitmenų kambario kodą.')),
      );
      return;
    }

    setState(() => isJoining = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final uid = await supabase.signInAnonymously();
      final room = await supabase.getRoomByCode(code);
      if (room == null) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kambarys nerastas.')),
          );
        }
        return;
      }

      final roomId = room['id'].toString();
      final hostUserId = room['host_user_id'].toString();

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
            isHost: uid == hostUserId,
            roomCode: code,
          ),
        ),
      );
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prisijungti nepavyko: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prisijungti prie kambario'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Įveskite 4 skaitmenų kodą, kad prisijungtumėte prie kambario.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: codeController,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kambario kodas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isJoining ? null : join,
                      child: isJoining
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Prisijungti'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
