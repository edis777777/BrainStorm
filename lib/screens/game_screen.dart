import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz_question.dart';
import '../services/supabase_service.dart';
import '../state/app_providers.dart';
import 'leaderboard_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String userId;
  final String playerName;

  const GameScreen({
    super.key,
    required this.roomId,
    required this.userId,
    required this.playerName,
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
    final seed = room['game_seed'] as int? ?? 0;
    final hostUserId = room['host_user_id']?.toString() ?? '';
    isHost = hostUserId.isNotEmpty && hostUserId == widget.userId;
    try {
      final fetched = await supabase.fetchQuestions(seed: seed, limit: 10);
      if (!mounted) return;
      setState(() {
        roundQuestions = fetched;
        questionsLoading = false;
        questionsError = fetched.isEmpty ? 'No questions found in Supabase.' : null;
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

    // Capture the timer at the moment the last answer is chosen.
    // Feedback still shows for 2 seconds, and the UI timer keeps running.
    final totalTimeMsAtLastAnswer = isLast
        ? ((stopwatch.elapsedMilliseconds / 100).round() * 100).toInt()
        : null;

    setState(() {
      hasAnswered = true;
      lastAnswerCorrect = correct;
      selectedOptionIndex = selectedIndex;
      if (correct) correctCount++;
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    if (isLast) {
      stopwatch.stop();
      uiTimer?.cancel();
      elapsedRoundedMs = totalTimeMsAtLastAnswer ?? elapsedRoundedMs;
      final totalTimeMs = totalTimeMsAtLastAnswer ?? elapsedRoundedMs;
      finished = true;

      await ref.read(supabaseServiceProvider).submitResult(
            roomId: widget.roomId,
            userId: widget.userId,
            correctCount: correctCount,
            totalTimeMs: totalTimeMs,
          );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LeaderboardScreen(
            roomId: widget.roomId,
            userId: widget.userId,
            playerName: widget.playerName,
            isHost: isHost,
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
      appBar: AppBar(
        title: const Text('Game'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Time: ${formatTenths()}s',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
      body: q == null
          ? Center(
              child: questionsLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      questionsError ?? 'No questions loaded.',
                      textAlign: TextAlign.center,
                    ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Question ${questionIndex + 1} / 10',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      elevation: 0,
                      color: Colors.white10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          q.question,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.separated(
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final disabled = hasAnswered || finished;
                          final isCorrectOption = i == q.correctIndex;
                          final isSelectedOption = selectedOptionIndex == i;

                          final background = () {
                            if (!hasAnswered) return const Color(0xFFFFD54F); // yellow
                            if (isCorrectOption) return Colors.greenAccent;
                            if (isSelectedOption && !lastAnswerCorrect) return Colors.redAccent;
                            return const Color(0xFFFFD54F).withOpacity(0.25);
                          }();
                          final foreground = hasAnswered
                              ? Colors.white
                              : Colors.black.withOpacity(0.88);

                          final label = () {
                            if (!hasAnswered) return q.options[i];
                            if (isCorrectOption && lastAnswerCorrect) return 'Correct!';
                            if (isSelectedOption && !lastAnswerCorrect) return 'Incorrect!';
                            return q.options[i];
                          }();

                          return SizedBox(
                            height: 58,
                            child: ElevatedButton(
                              onPressed: disabled ? null : () => selectAnswer(i),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: background,
                                foregroundColor: foreground,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              child: Text(label),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

