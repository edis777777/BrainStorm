import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';
import '../theme/app_theme.dart';
import 'lobby_screen.dart';

class _SpeechBubblePainter extends CustomPainter {
  final Color color;
  final double cutSize;

  _SpeechBubblePainter({required this.color, this.cutSize = 25.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    path.moveTo(0, 0); 
    path.lineTo(size.width - cutSize, 0); 
    path.lineTo(size.width, cutSize); 
    path.lineTo(size.width, size.height); 
    
    // Tail
    path.lineTo(size.width - 30, size.height + 18); 
    path.lineTo(size.width - 50, size.height); 
    
    path.lineTo(cutSize, size.height); 
    path.lineTo(0, size.height - cutSize); 
    path.close(); 

    canvas.drawShadow(path, color, 8.0, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.secondary),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/fonas.jpg'), 
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.3)),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        appTitle,
                        textAlign: TextAlign.center,
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
                      const SizedBox(height: 12),
                      Text(
                        widget.playerName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      CustomPaint(
                        painter: _SpeechBubblePainter(color: colorScheme.secondary),
                        child: Container(
                          height: 140, 
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Center(
                            child: Text(
                              "ĮVESKITE 4 SKAITMENŲ KODĄ,\nKAD PRISIJUNGTUMĖTE PRIE KAMBARIO",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.secondary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1.3,
                                shadows: [
                                  Shadow(color: colorScheme.secondary.withOpacity(0.6), blurRadius: 10),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      TextField(
                        controller: codeController,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Kambario kodas',
                          labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18, letterSpacing: 1),
                          counterStyle: TextStyle(color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.black45,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade600, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.5,
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                                border: Border.all(color: Colors.pinkAccent, width: 2.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pinkAccent.withOpacity(0.15),
                                    blurRadius: 25,
                                    spreadRadius: 5,
                                  )
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: isJoining ? null : join,
                                  customBorder: const CircleBorder(),
                                  child: Center(
                                    child: isJoining
                                      ? const CircularProgressIndicator(color: Colors.pinkAccent)
                                      : Text(
                                          "PRISIJUNGTI",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 20, 
                                            fontWeight: FontWeight.w900,
                                            color: Colors.pinkAccent,
                                            height: 1.3,
                                            shadows: [
                                              Shadow(color: Colors.pinkAccent.withOpacity(0.8), blurRadius: 10),
                                            ],
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
