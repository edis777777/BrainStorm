import '../models/quiz_question.dart';

// Keep this client-side so the app can run without needing a question DB.
// Multiplayer uses a shared seed to choose the same 10 questions for the round.
class QuestionBank {
  static const List<QuizQuestion> questions = [
    QuizQuestion(
      question: 'What is the next number: 2, 4, 6, 8, ?',
      options: ['9', '10', '11', '12'],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'Which planet is known as the Red Planet?',
      options: ['Mars', 'Venus', 'Jupiter', 'Mercury'],
      correctIndex: 0,
    ),
    QuizQuestion(
      question: 'What is 15 + 7?',
      options: ['20', '21', '22', '23'],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Choose the odd one out.',
      options: ['Circle', 'Square', 'Triangle', 'Rectangle'],
      correctIndex: 0,
    ),
    QuizQuestion(
      question: 'Which language is primarily used for Flutter apps?',
      options: ['Java', 'Dart', 'Kotlin', 'Swift'],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What comes next: A, C, E, G, ?',
      options: ['H', 'I', 'J', 'K'],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'Which of these is a prime number?',
      options: ['21', '25', '29', '33'],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'If today is Monday, what day is it after 10 days?',
      options: ['Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      correctIndex: 3,
    ),
    QuizQuestion(
      question: 'What is the square root of 81?',
      options: ['7', '8', '9', '10'],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Which shape has exactly 3 sides?',
      options: ['Quadrilateral', 'Triangle', 'Pentagon', 'Circle'],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What is 100 - 37?',
      options: ['52', '63', '64', '73'],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Which number is divisible by 3?',
      options: ['14', '17', '18', '20'],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Choose the pattern: 1, 1, 2, 3, 5, ?',
      options: ['7', '8', '9', '10'],
      correctIndex: 0,
    ),
    QuizQuestion(
      question: 'Which is the largest ocean?',
      options: ['Atlantic', 'Indian', 'Pacific', 'Arctic'],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What is 6 * 7?',
      options: ['36', '42', '48', '54'],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'Which of these is an even number?',
      options: ['101', '103', '104', '107'],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What comes next: 3, 6, 12, 24, ?',
      options: ['36', '40', '48', '60'],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Which country has Paris as its capital?',
      options: ['Spain', 'France', 'Italy', 'Germany'],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'A word that means “quick” is...',
      options: ['Slow', 'Fast', 'Late', 'Cold'],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What is 2^5?',
      options: ['24', '30', '32', '64'],
      correctIndex: 2,
    ),
  ];
}

