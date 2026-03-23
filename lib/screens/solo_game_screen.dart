import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz_question.dart';
import '../state/app_providers.dart';
import 'home_screen.dart';

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

  Future<void> _loadQuestions() async {
    final supabase = ref.read(supabaseServiceProvider);
    setState(() {
      questionsLoading = true;
      questionsError = null;
      roundQuestions = const [];
    });
    try {
      final fetched = await supabase.fetchQuestions(
  limit: 10, 
  userId: Supabase.instance.client.auth.currentUser?.id ?? 'guest_user',
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
      if (correct) correctCount++;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Žaisti vienam'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                started ? 'Laikas: ${formatTenths()}s' : 'Laikas: 0.0s',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
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
    );
  }

  Widget _buildLobbySolo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Vieno žaidėjo laukiamasis',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text('Atsakysite į 10 klausimų. Taisyklės tos pačios, reitingas individualus.'),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (questionsLoading || roundQuestions.isEmpty) ? null : start,
                  child: const Text('Pradėti'),
                ),
              ),
              if (questionsLoading) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
              if (!questionsLoading && questionsError != null) ...[
                const SizedBox(height: 12),
                Text(
                  questionsError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(QuizQuestion q) {
    final idx = questionIndex + 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Klausimas $idx / ${roundQuestions.length}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final isCorrectOption = i == q.correctIndex;
                final isSelectedOption = selectedOptionIndex == i;

                final label = () {
                  if (!hasAnswered) return q.options[i];
                  if (isCorrectOption) return 'Teisingai!';
                  if (isSelectedOption && !lastAnswerCorrect) return 'Neteisingai!';
                  return q.options[i];
                }();

                return SizedBox(
                  height: 58,
                  child: ElevatedButton(
                    onPressed: hasAnswered ? null : () => selectAnswer(i),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.disabled)) {
                          if (hasAnswered) {
                            if (isCorrectOption) return Colors.green;
                            if (isSelectedOption) return Colors.red;
                          }
                          return const Color(0xFFFFD54F).withOpacity(0.25);
                        }
                        return const Color(0xFFFFD54F); // yellow
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.disabled)) {
                          return Colors.white;
                        }
                        return Colors.black.withOpacity(0.88);
                      }),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
    );
  }

  Widget _buildLeaderboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        children: [
          const Text(
            'Rezultatai',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                _leaderRow(rank: 1, name: widget.playerName, correct: correctCount, ms: totalTimeMsAtLastAnswer),
              ],
            ),
          ),
          _bottomActions(),
        ],
      ),
    );
  }

  Widget _leaderRow({
    required int rank,
    required String name,
    required int correct,
    required int ms,
  }) {
    final secs = ms / 1000.0;
    return Card(
      color: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                '#$rank',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            Text(
              '$correct / 10',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 12),
            Text(
              '${secs.toStringAsFixed(1)}s',
              style: const TextStyle(fontWeight: FontWeight.w700),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await resetRound();
                },
                child: const Text('Žaisti dar kartą'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(playerName: widget.playerName),
                  ),
                ),
                child: const Text('Baigti'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
