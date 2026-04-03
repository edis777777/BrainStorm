import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz_question.dart';
import '../services/audio_service.dart';
import '../state/app_providers.dart';
import 'leaderboard_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String userId;
  final String playerName;
  final String roomCode;

  const GameScreen({
    super.key,
    required this.roomId,
    required this.userId,
    required this.playerName,
    required this.roomCode,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  List<QuizQuestion> roundQuestions = const [];
  bool questionsLoading = true;
  String? questionsError;

  final stopwatch = Stopwatch();
  Timer? uiTimer;

  int elapsedRoundedMs = 0;
  int questionIndex = 0;
  int correctCount = 0;

  bool hasAnswered = false;
  bool lastAnswerCorrect = false;
  int? selectedOptionIndex;
  bool finished = false;
  bool isHost = false;

  @override
  void initState() {
    super.initState();
    audioService.stopBackgroundMusic();
    // Start immediately after navigation so the timer measures from the click.
    startStopwatch();
    _loadQuestions();
  }

  @override
  void dispose() {
    uiTimer?.cancel();
    super.dispose();
  }

  void startStopwatch() {
    stopwatch.start();
    uiTimer?.cancel();
    uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final ms = stopwatch.elapsedMilliseconds;
      final rounded = ((ms / 100).round() * 100).toInt();
      setState(() => elapsedRoundedMs = rounded);
    });
    setState(() {});
  }

  Future<void> _loadQuestions() async {
    final supabase = ref.read(supabaseServiceProvider);
    final room = await supabase.fetchRoom(roomId: widget.roomId);
    final hostUserId = room['host_user_id']?.toString() ?? '';
    isHost = hostUserId.isNotEmpty && hostUserId == widget.userId;
    try {
      final currentQuestionIdsJson = room['current_question_ids'] as List<dynamic>? ?? [];
      final currentQuestionIds = currentQuestionIdsJson.map((e) => int.parse(e.toString())).toList();
      
      final fetched = await supabase.fetchQuestionsByIds(currentQuestionIds);
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

  String formatTenths() {
    final secs = elapsedRoundedMs / 1000.0;
    return secs.toStringAsFixed(1);
  }

  Future<void> selectAnswer(int selectedIndex) async {
    if (finished || hasAnswered) return;
    if (questionIndex >= roundQuestions.length) return;

    final q = roundQuestions[questionIndex];
    final correct = selectedIndex == q.correctIndex;
    final isLast = questionIndex == roundQuestions.length - 1;

    final totalTimeMsAtLastAnswer = isLast ? ((stopwatch.elapsedMilliseconds / 100).round() * 100).toInt() : null;

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

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    if (isLast) {
      stopwatch.stop();
      uiTimer?.cancel();
      elapsedRoundedMs = totalTimeMsAtLastAnswer ?? elapsedRoundedMs;
      final totalTimeMs = totalTimeMsAtLastAnswer ?? elapsedRoundedMs;
      finished = true;

      if (widget.userId.isNotEmpty) {
        final qIds = roundQuestions.map<int>((q) => q.id).toList();
        await ref.read(supabaseServiceProvider).recordPlayedQuestions(
          userId: widget.userId,
          questionIds: qIds,
        );
      }

      await ref
          .read(supabaseServiceProvider)
          .submitResult(roomId: widget.roomId, userId: widget.userId, correctCount: correctCount, totalTimeMs: totalTimeMs);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LeaderboardScreen(
            roomId: widget.roomId,
            userId: widget.userId,
            playerName: widget.playerName,
            isHost: isHost,
            roomCode: widget.roomCode,
          ),
        ),
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
    final q = questionIndex < roundQuestions.length ? roundQuestions[questionIndex] : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: (q != null && !finished)
            ? const SizedBox.shrink()
            : const Text('Žaidimas', style: TextStyle(color: Colors.white)),
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
            child: q == null
                ? Center(
                    child: questionsLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            questionsError ?? 'Klausimai neužkrauti.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800),
                          ),
                  )
                : _buildQuestion(q),
          ),
        ],
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
                    onPressed: hasAnswered || finished ? null : () => selectAnswer(i),
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
}
