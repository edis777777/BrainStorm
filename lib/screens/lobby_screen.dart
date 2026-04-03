import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_models.dart';
import '../state/app_providers.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String userId;
  final String playerName;
  final bool isHost;
  final String roomCode;

  const LobbyScreen({
    super.key,
    required this.roomId,
    required this.userId,
    required this.playerName,
    required this.isHost,
    required this.roomCode,
  });

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

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

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  RoomModel? room;
  List<RoomPlayerModel> players = [];

  StreamSubscription? roomSub;
  StreamSubscription? playersSub;

  bool didNavigate = false;

  bool _showReadyGreen = false;
  bool _showStartSessionGreen = false;

  int buildSeed() => Random().nextInt(1 << 31);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final supabase = ref.read(supabaseServiceProvider);

    final initialRoom = await supabase.fetchRoom(roomId: widget.roomId);

    final roomModel = RoomModel.fromJson(initialRoom);

    if (!mounted) return;
    setState(() {
      room = roomModel;
    });

    roomSub = supabase
        .roomRowStream(roomId: widget.roomId, initialRoom: initialRoom)
        .listen((newRoom) {
      if (!mounted) return;
      setState(() {
        room = RoomModel.fromJson(newRoom);
        // reset navigation guard when game state changes
        didNavigate = false;
      });
    });

    playersSub = supabase.playerRowsStream(roomId: widget.roomId).listen((rows) {
      if (!mounted) return;
      setState(() {
        players = rows.map((e) => RoomPlayerModel.fromJson(e)).toList();
      });

      final me = players.where((p) => p.userId == widget.userId).firstOrNull;
      if (me == null) return;

      if (!didNavigate) {
        if (me.finished) {
          didNavigate = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => LeaderboardScreen(
                roomId: widget.roomId,
                userId: widget.userId,
                playerName: widget.playerName,
                isHost: widget.isHost,
                roomCode: widget.roomCode,
              ),
            ),
          );
        } else if (me.started) {
          didNavigate = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                roomId: widget.roomId,
                userId: widget.userId,
                playerName: widget.playerName,
                roomCode: widget.roomCode,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    roomSub?.cancel();
    playersSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = room;
    final me = players.where((p) => p.userId == widget.userId).firstOrNull;

    final gameStarted = r?.gameStarted ?? false;
    final myReady = me?.ready ?? false;
    final myStarted = me?.started ?? false;
    final myFinished = me?.finished ?? false;

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
            child: r == null || me == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
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
                            const SizedBox(height: 16),
                            _displayRoomCode(r.code),
                            const SizedBox(height: 16),
                            _instructionBlock(),
                            const SizedBox(height: 16), // Tarpas dėl uodegytės
                            if (widget.isHost) _dynamicHostButton()
                            else _dynamicClientButton(),
                            const SizedBox(height: 24),
                            _playersList(),
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

  Widget _displayRoomCode(String code) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary, width: 2),
      ),
      child: Column(
        children: [
          Text(
            'KAMBARIO KODAS', 
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900, 
              color: colorScheme.primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            code, 
            style: TextStyle(
              fontSize: 42, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 8,
              color: colorScheme.primary,
              shadows: [
                Shadow(color: colorScheme.primary.withOpacity(0.8), blurRadius: 15),
              ]
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionBlock() {
    final gameStarted = room?.gameStarted ?? false;
    final me = players.where((p) => p.userId == widget.userId).firstOrNull;
    final myReady = me?.ready ?? false;
    final allReady = players.isNotEmpty && players.every((p) => p.ready);

    String instructionText = "";

    if (widget.isHost) {
      if (gameStarted) {
        instructionText = "Paspausk mygtuką PRADĖTI ŽAIDIMĄ.";
      } else if (allReady) {
        instructionText = "Paspausk mygtuką STARTUOTI SESIJĄ.";
      } else if (myReady) {
        instructionText = "Palauk, kol visi žaidėjai\nbus pasiruošę.";
      } else if (players.length > 1) {
        instructionText = "Visi žaidėjai (ir Tu)\nturi paspausti mygtuką 'Pasiruošęs'.";
      } else {
        instructionText = "Pasakyk kambario kodą kitiems\nžaidėjams ir palauk, kol visi prisijungs.";
      }
    } else {
      if (gameStarted) {
        instructionText = "Paspausk mygtuką PRADĖTI ŽAIDIMĄ.";
      } else if (!myReady) {
        instructionText = "Paspausk mygtuką PASIRUOŠĘS.";
      } else {
        instructionText = "Palauk, kol visi žaidėjai\nbus pasiruošę."; // ar lauksime kol hostas paleis
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _SpeechBubblePainter(color: colorScheme.secondary),
      child: Container(
        height: 140, // Fiksuojame aukštį dviem eilutėms, kad nebešokinėtų vizualika
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              instructionText,
              key: ValueKey<String>(instructionText),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.secondary,
                fontSize: 20,
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
    );
  }

  Widget _playersList() {
    return Container(
      height: 320, // Fiksuojame aukštį 4 žaidėjams
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ŽAIDĖJAI', 
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.w900, 
              color: Colors.white,
              letterSpacing: 2,
            )
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: players.map((p) {
                  final isReady = p.ready;
                  final isMe = p.userId == widget.userId;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.playerName + (isMe ? ' (Tu)' : ''),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isMe ? Theme.of(context).colorScheme.secondary : Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isReady ? Colors.green.withOpacity(0.15) : Colors.pinkAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isReady ? Colors.green : Colors.pinkAccent,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                isReady ? 'Pasiruošęs' : 'Nepasiruošęs',
                                style: TextStyle(
                                  color: isReady ? Colors.green : Colors.pinkAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dynamicClientButton() {
    final r = room;
    final me = players.where((p) => p.userId == widget.userId).firstOrNull;
    if (r == null || me == null) return const SizedBox.shrink();

    final gameStarted = r.gameStarted;
    final myReady = me.ready;
    final myStarted = me.started;
    final myFinished = me.finished;

    if (myFinished) return _postGameNote();
    if (myStarted) return _myStartedNote();

    Color bgColor;
    String text;
    VoidCallback? onPressed;

    if (gameStarted) {
      bgColor = Colors.pinkAccent;
      text = "Pradėti žaidimą";
      onPressed = () {
        didNavigate = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              roomId: widget.roomId,
              userId: widget.userId,
              playerName: widget.playerName,
              roomCode: widget.roomCode,
            ),
          ),
        );
        unawaited(ref.read(supabaseServiceProvider).markStarted(roomId: widget.roomId, userId: widget.userId));
      };
    } else {
      if (!myReady) {
        bgColor = Colors.pinkAccent;
        text = "Pasiruošęs";
        onPressed = _toggleReady;
      } else {
        if (_showReadyGreen) {
          bgColor = Colors.green;
          text = "Pasiruošęs";
          onPressed = _toggleReady;
        } else {
          bgColor = Colors.grey.shade800;
          text = "Gali atšaukti\npasiruošimą";
          onPressed = _toggleReady;
        }
      }
    }

    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.5,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: bgColor == Colors.grey.shade800 ? Colors.white38 : bgColor, width: 2.0),
              boxShadow: bgColor == Colors.grey.shade800 ? [] : [
                BoxShadow(
                  color: bgColor.withOpacity(0.15),
                  blurRadius: 25,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                child: Center(
                  child: _BlinkingText(
                    text.toUpperCase(),
                    shouldBlink: bgColor != Colors.grey.shade800,
                    key: ValueKey(text),
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                      color: bgColor == Colors.grey.shade800 ? Colors.white54 : bgColor,
                      shadows: bgColor == Colors.grey.shade800 ? [] : [
                        Shadow(color: bgColor.withOpacity(0.8), blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleReady() async {
    final me = players.where((p) => p.userId == widget.userId).firstOrNull;
    if (me == null) return;
    
    final isCurrentlyReady = me.ready;
    final supabase = ref.read(supabaseServiceProvider);
    
    if (!isCurrentlyReady) {
      if (mounted) setState(() => _showReadyGreen = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showReadyGreen = false);
      });
    } else {
      if (mounted) setState(() => _showReadyGreen = false);
    }
    
    await supabase.setReady(roomId: widget.roomId, userId: widget.userId, ready: !isCurrentlyReady);
  }

  Future<void> _handleStartSession() async {
    if (mounted) setState(() => _showStartSessionGreen = true);
    
    final seed = buildSeed();
    final supabase = ref.read(supabaseServiceProvider);
    await supabase.hostStartGame(roomId: widget.roomId, gameSeed: seed);
  }

  Widget _dynamicHostButton() {
    final r = room;
    final me = players.where((p) => p.userId == widget.userId).firstOrNull;
    if (r == null || me == null) return const SizedBox.shrink();

    final gameStarted = r.gameStarted;
    final myReady = me.ready;
    final allReady = players.isNotEmpty && players.every((p) => p.ready);
    final myStarted = me.started;
    final myFinished = me.finished;

    if (myFinished) return _postGameNote();
    if (myStarted) return _myStartedNote();

    Color bgColor;
    String text;
    VoidCallback? onPressed;

    if (gameStarted) {
      bgColor = Colors.pinkAccent;
      text = "Pradėti žaidimą";
      onPressed = () {
        didNavigate = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              roomId: widget.roomId,
              userId: widget.userId,
              playerName: widget.playerName,
              roomCode: widget.roomCode,
            ),
          ),
        );
        unawaited(ref.read(supabaseServiceProvider).markStarted(roomId: widget.roomId, userId: widget.userId));
      };
    } else if (_showStartSessionGreen) {
      bgColor = Colors.green;
      text = "Startuojama...";
      onPressed = null;
    } else if (allReady) {
      bgColor = Colors.pinkAccent;
      text = "Startuoti sesiją";
      onPressed = _handleStartSession;
    } else if (players.length <= 1) {
      bgColor = Colors.grey.shade800;
      text = "";
      onPressed = null;
    } else {
      if (!myReady) {
        bgColor = Colors.pinkAccent;
        text = "Pasiruošęs";
        onPressed = _toggleReady;
      } else {
        if (_showReadyGreen) {
          bgColor = Colors.green;
          text = "Pasiruošęs";
          onPressed = _toggleReady;
        } else {
          bgColor = Colors.grey.shade800;
          text = "Gali atšaukti\npasiruošimą";
          onPressed = _toggleReady;
        }
      }
    }

    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.5,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: bgColor == Colors.grey.shade800 ? Colors.white38 : bgColor, width: 2.0),
              boxShadow: bgColor == Colors.grey.shade800 ? [] : [
                BoxShadow(
                  color: bgColor.withOpacity(0.15),
                  blurRadius: 25,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                child: Center(
                  child: _BlinkingText(
                    text.toUpperCase(),
                    shouldBlink: bgColor != Colors.grey.shade800,
                    key: ValueKey(text),
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                      color: bgColor == Colors.grey.shade800 ? Colors.white54 : bgColor,
                      shadows: bgColor == Colors.grey.shade800 ? [] : [
                        Shadow(color: bgColor.withOpacity(0.8), blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _myStartedNote() {
    return const SizedBox(
      width: double.infinity,
      child: Card(
        color: Colors.white10,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Pradedama...', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  Widget _postGameNote() {
    return const SizedBox(
      width: double.infinity,
      child: Card(
        color: Colors.white10,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Rodoma rezultatų lentelė...', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final v in this) {
      return v;
    }
    return null;
  }
}

class _BlinkingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool shouldBlink;

  const _BlinkingText(this.text, {super.key, required this.style, this.shouldBlink = true});

  @override
  _BlinkingTextState createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<_BlinkingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200), // Vieno mirktelėjimo pusė
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);
    if (widget.shouldBlink) {
      _startBlinking();
    }
  }

  void _startBlinking() {
    _controller.repeat(reverse: true);
    // Sustabdome po 1200ms (tai padarys 3 pilnus ciklus 1->0->1)
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _controller.stop();
        _controller.value = 0.0; // Pradinis taškas reiškia opacity 1.0
      }
    });
  }

  @override
  void didUpdateWidget(_BlinkingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (widget.shouldBlink) {
        _startBlinking();
      } else {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        style: widget.style,
      ),
    );
  }
}
