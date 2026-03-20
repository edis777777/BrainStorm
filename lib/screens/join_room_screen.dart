import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../state/app_providers.dart';
import '../services/supabase_service.dart';
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

  String? extractCode(String raw) {
    final match = RegExp(r'(\d{4})').firstMatch(raw);
    return match?.group(1);
  }

  Future<void> scanAndSetCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final scanner = MobileScanner(
          onDetect: (capture) {
            final raw = capture.barcodes.first.rawValue ?? '';
            final extracted = extractCode(raw);
            if (extracted != null) {
              Navigator.of(ctx).pop(extracted);
            }
          },
        );
        return AlertDialog(
          title: const Text('Scan Room QR'),
          content: SizedBox(height: 320, width: 320, child: scanner),
        );
      },
    );

    if (code == null) return;
    codeController.text = code;
  }

  Future<void> join() async {
    final code = codeController.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 4-digit room code.')),
      );
      return;
    }

    setState(() => isJoining = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final uid = await supabase.signInAnonymously();
      final room = await supabase.getRoomByCode(code);
      if (room == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room not found.')),
        );
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
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Join failed: $e')),
      );
    } finally {
      if (mounted) setState(() => isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Room'),
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
                    'Enter the 4-digit code or scan the QR.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: codeController,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Room code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: scanAndSetCode,
                      child: const Text('Scan QR'),
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
                          : const Text('Join'),
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

