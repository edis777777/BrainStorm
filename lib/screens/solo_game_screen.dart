import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz_question.dart';
import '../services/audio_service.dart';
import '../state/app_providers.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

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

  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SoloAttempt {
  final int attemptNumber;
  final int correctCount;
  final int totalTimeMs;

  SoloAttempt({
    required this.attemptNumber,
    required this.correctCount,
    required this.totalTimeMs,
  });
}

class SoloGameScreen extends ConsumerStatefulWidget {
  final String playerName;

  const SoloGameScreen({super.key, required this.playerName});

  @override
  ConsumerState<SoloGameScreen> createState() => _SoloGameScreenState();
}

class _SoloGameScreenState extends ConsumerState<SoloGameScreen> {
  List<QuizQuestion> roundQuestions = const [];
  bool questionsLoading = true;
  String? questionsError;

  final stopwatch = Stopwatch();
  Timer? uiTimer;
  int elapsedRoundedMs = 0;
  int totalTimeMsAtLastAnswer = 0;

  int questionIndex = 0;
  int correctCount = 0;
  bool hasAnswered = false;
  bool lastAnswerCorrect = false;
  int? selectedOptionIndex;
  bool finished = false;
  bool started = false;
  List<SoloAttempt> pastAttempts = [];

  Future<void> _loadQuestions() async {
    final supabase = ref.read(supabaseServiceProvider);
    setState(() {
      questionsLoading = true;
      questionsError = null;
      roundQuestions = const [];
    });
    try {
      final userId = await supabase.signInAnonymously();
      final fetched = await supabase.fetchQuestions(
        limit: 10, 
        userId: userId,
      );
      if (!mounted) return;
      setState(() {
        roundQuestions = fetched;
        questionsLoading = false;
        questionsError = fetched.isEmpty ? 'Klausimų nerasta.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        questionsLoading = false;
        questionsError = e.toString();
      });
    }
  }

  Future<void> resetRound() async {
    uiTimer?.cancel();
    stopwatch.stop();
    stopwatch.reset();
    elapsedRoundedMs = 0;
    totalTimeMsAtLastAnswer = 0;

    questionIndex = 0;
    correctCount = 0;
    hasAnswered = false;
    lastAnswerCorrect = false;
    finished = false;
    started = false;

    audioService.playBackgroundMusic();
    await _loadQuestions();
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    uiTimer?.cancel();
    super.dispose();
  }

  void start() {
    started = true;
    audioService.stopBackgroundMusic();
    stopwatch.start();
    uiTimer?.cancel();
    uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final ms = stopwatch.elapsedMilliseconds;
      final rounded = ((ms / 100).round() * 100).toInt();
      if (!mounted) return;
      setState(() {
        elapsedRoundedMs = rounded;
      });
    });
    setState(() {});
  }

  String formatTenths() {
    final secs = elapsedRoundedMs / 1000.0;
    return secs.toStringAsFixed(1);
  }

  Future<void> selectAnswer(int selectedIndex) async {
    if (hasAnswered || finished || !started) return;

    final q = roundQuestions[questionIndex];
    final correct = selectedIndex == q.correctIndex;

    setState(() {
      hasAnswered = true;
      lastAnswerCorrect = correct;
      selectedOptionIndex = selectedIndex;
      if (correct) {
        correctCount++;
        audioService.playCorrectSound();
      } else {
        audioService.playIncorrectSound();
      }
    });

    final isLast = questionIndex == roundQuestions.length - 1;
    if (isLast) {
      final ms = stopwatch.elapsedMilliseconds;
      totalTimeMsAtLastAnswer = ((ms / 100).round() * 100).toInt();
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    if (isLast) {
      stopwatch.stop();
      setState(() {
        finished = true;
        elapsedRoundedMs = totalTimeMsAtLastAnswer;
      });
      uiTimer?.cancel();
      
      final currentAttempt = SoloAttempt(
        attemptNumber: pastAttempts.length + 1,
        correctCount: correctCount,
        totalTimeMs: totalTimeMsAtLastAnswer,
      );
      
      final sortedAttempts = List<SoloAttempt>.from(pastAttempts)..add(currentAttempt);
      sortedAttempts.sort((a, b) {
        int cmp = b.correctCount.compareTo(a.correctCount);
        if (cmp != 0) return cmp;
        return a.totalTimeMs.compareTo(b.totalTimeMs);
      });

      final isFirstGame = pastAttempts.isEmpty;
      final isNewBest = !isFirstGame && sortedAttempts.first == currentAttempt;

      setState(() {
        pastAttempts.add(currentAttempt);
      });

      if (!isFirstGame && isNewBest) {
        audioService.playChampionSound();
      }

      final userId = await ref.read(supabaseServiceProvider).signInAnonymously();
      final qIds = roundQuestions.map<int>((q) => q.id).toList();
      await ref.read(supabaseServiceProvider).recordPlayedQuestions(
        userId: userId,
        questionIds: qIds,
      );
      return;
    }

    setState(() {
      questionIndex++;
      hasAnswered = false;
      lastAnswerCorrect = false;
      selectedOptionIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canShowStart = !started && !finished;
    final q = questionIndex < roundQuestions.length ? roundQuestions[questionIndex] : null;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: (canShowStart || (!finished && q != null)) 
            ? const SizedBox.shrink() 
            : const Text('Žaisti vienam', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
          Container(color: Colors.black.withOpacity(0.4)),
          SafeArea(
            child: finished
                ? _buildLeaderboard()
                : canShowStart
                    ? _buildLobbySolo()
                    : (q == null
                        ? Center(
                            child: questionsLoading
                                ? const CircularProgressIndicator()
                                : Text(
                                    questionsError ?? 'Klausimai neužkrauti.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800),
                                  ),
                          )
                        : _buildQuestion(q)),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbySolo() {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 16),
      child: Align(
        alignment: Alignment.topCenter,
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
                painter: _SpeechBubblePainter(color: colorScheme.primary),
                child: Container(
                  height: 140, 
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: Text(
                      "ATSAKYSITE Į 10 KLAUSIMŲ,\nSPAUSKITE PRADĖTI ŽAIDIMĄ",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                        shadows: [
                          Shadow(color: colorScheme.primary.withOpacity(0.6), blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              Builder(
                builder: (context) {
                  return Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: (questionsLoading || (roundQuestions.isEmpty && questionsError == null))
                            ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
                            : (questionsError != null)
                                ? Center(
                                    child: Text(
                                      questionsError!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 18),
                                    ),
                                  )
                                : AnimatedContainer(
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
                            onTap: start,
                            customBorder: const CircleBorder(),
                            child: Center(
                              child: Text(
                                "PRADĖTI ŽAIDIMĄ",
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
                              ), // Text
                            ), // Center
                          ), // InkWell
                        ), // Material
                      ), // AnimatedContainer
                      ), // AspectRatio
                    ), // FractionallySizedBox
                  ); // Center
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(QuizQuestion q) {
    final idx = questionIndex + 1;
    final mascotImage = !hasAnswered 
        ? 'assets/susikaupk.png' 
        : (lastAnswerCorrect ? 'assets/yes.png' : 'assets/no.png');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ATSAKYK Į 10 KLAUSIMŲ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: Colors.purpleAccent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('Klausimas', style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('$idx', style: const TextStyle(color: Colors.purpleAccent, fontSize: 24, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: Colors.purpleAccent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('Laikas', style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${formatTenths()}s', style: const TextStyle(color: Colors.purpleAccent, fontSize: 24, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 80),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              q.question,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.3),
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            itemCount: 4,
            physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final isCorrectOption = i == q.correctIndex;
                final isSelectedOption = selectedOptionIndex == i;

                Color bgColor = Colors.amber.shade700;
                Color borderColor = Colors.amber.shade100;
                Color textColor = Colors.black87;

                if (hasAnswered) {
                  if (isCorrectOption) {
                    bgColor = Colors.green.shade800;
                    borderColor = Colors.green.shade400;
                    textColor = Colors.white;
                  } else if (isSelectedOption) {
                    bgColor = Colors.red.shade800;
                    borderColor = Colors.red.shade400;
                    textColor = Colors.white;
                  } else {
                    bgColor = Colors.amber.shade200.withOpacity(0.5);
                    borderColor = Colors.amber.shade50.withOpacity(0.5);
                    textColor = Colors.black38;
                  }
                }

                return SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: hasAnswered ? null : () => selectAnswer(i),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(bgColor),
                      foregroundColor: WidgetStateProperty.all(textColor),
                      side: WidgetStateProperty.all(BorderSide(color: borderColor, width: 2)),
                      shape: WidgetStateProperty.all(
                        BeveledRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      elevation: WidgetStateProperty.all(0),
                    ),
                    child: Text(q.options[i], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                );
              },
            ),
          const SizedBox(height: 26),
          Expanded(
            child: Image.asset(mascotImage, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    final sortedAttempts = List<SoloAttempt>.from(pastAttempts);
    sortedAttempts.sort((a, b) {
      int cmp = b.correctCount.compareTo(a.correctCount);
      if (cmp != 0) return cmp;
      return a.totalTimeMs.compareTo(b.totalTimeMs);
    });

    final currentAttempt = pastAttempts.isNotEmpty ? pastAttempts.last : null;
    final isFirstGame = pastAttempts.length == 1;
    final isNewBest = !isFirstGame && currentAttempt != null && sortedAttempts.first == currentAttempt;

    String message;
    String mascotImage;

    if (isFirstGame) {
      message = 'PUIKU, BET AR GALI APLENKTI SAVE? BANDYK DAR KARTĄ.';
      mascotImage = 'assets/saunuolis.png';
    } else if (isNewBest) {
      message = 'ŠAUNUOLIS, TU APLENKEI SAVE !!! BANDYK DAR KARTĄ.';
      mascotImage = 'assets/saunuolis.png';
    } else {
      message = 'UPS ! NEPAVYKO 😢 BANDYK DAR KARTĄ.';
      mascotImage = 'assets/nenusimink.png';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: sortedAttempts.length,
            itemBuilder: (context, index) {
              final attempt = sortedAttempts[index];
              return _leaderRow(
                rank: index + 1,
                name: '${attempt.attemptNumber} BANDYMAS',
                correct: attempt.correctCount,
                ms: attempt.totalTimeMs,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Image.asset(mascotImage, fit: BoxFit.contain),
        ),
        _bottomActions(),
      ],
    );
  }

  Widget _leaderRow({
    required int rank,
    required String name,
    required int correct,
    required int ms,
  }) {
    final secs = ms / 1000.0;
    final formattedSecs = secs.toStringAsFixed(1).replaceAll('.', ',');

    Color bgColor;
    Color textColor = Colors.black;
    if (rank == 1) {
      bgColor = const Color(0xFFFFD700); // Gold
    } else if (rank == 2) {
      bgColor = const Color(0xFFEEEEEE); // Lighter Silver
    } else if (rank == 3) {
      bgColor = const Color(0xFFCD7F32); // Bronze
    } else {
      bgColor = Colors.grey.shade800;
      textColor = Colors.white; // Better contrast
    }

    return Card(
      color: bgColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$rank.',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor),
              ),
            ),
            Expanded(
              child: Text(
                name,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor),
              ),
            ),
            Text(
              '$correct/10',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor),
            ),
            const SizedBox(width: 12),
            Text(
              formattedSecs,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await resetRound();
                },
                child: const Text('ŽAISTI DAR KARTĄ'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(playerName: widget.playerName),
                  ),
                ),
                child: const Text('BAIGTI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
