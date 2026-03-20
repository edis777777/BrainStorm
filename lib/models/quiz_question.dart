class QuizQuestion {
  final String question;
  final List<String> options; // must be length 4
  final int correctIndex; // 0..3

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestion.fromSupabaseRow(Map<String, dynamic> row) {
    final optionA = (row['option_a'] ?? '').toString();
    final optionB = (row['option_b'] ?? '').toString();
    final optionC = (row['option_c'] ?? '').toString();
    final optionD = (row['option_d'] ?? '').toString();

    final options = [optionA, optionB, optionC, optionD];
    final correctAnswerRaw = row['correct_answer'];
    final correctIndex = _parseCorrectIndex(correctAnswerRaw, options);

    return QuizQuestion(
      question: (row['question'] ?? '').toString(),
      options: options,
      correctIndex: correctIndex,
    );
  }

  static int _parseCorrectIndex(Object? correctAnswerRaw, List<String> options) {
    if (correctAnswerRaw == null) return 0;

    if (correctAnswerRaw is num) {
      final n = correctAnswerRaw.toInt();
      if (n >= 0 && n <= 3) return n;
      if (n >= 1 && n <= 4) return n - 1;
    }

    final s = correctAnswerRaw.toString().trim();
    if (s.isEmpty) return 0;

    final lower = s.toLowerCase();
    if (lower == 'a') return 0;
    if (lower == 'b') return 1;
    if (lower == 'c') return 2;
    if (lower == 'd') return 3;

    final asInt = int.tryParse(lower);
    if (asInt != null) {
      if (asInt >= 0 && asInt <= 3) return asInt;
      if (asInt >= 1 && asInt <= 4) return asInt - 1;
    }

    final byText = options.indexWhere((o) => o == s);
    if (byText >= 0) return byText;

    // Common variant: "option_a"/"option_b"/... stored in correct_answer.
    if (lower.contains('option_a') || lower == 'a_option') return 0;
    if (lower.contains('option_b') || lower == 'b_option') return 1;
    if (lower.contains('option_c') || lower == 'c_option') return 2;
    if (lower.contains('option_d') || lower == 'd_option') return 3;

    return 0;
  }
}

