import 'package:intl/intl.dart';
import '../data/word_ladder_puzzles.dart';
import '../models/word_ladder_models.dart';

class WordLadderService {
  static WordLadderPuzzle getDailyPuzzle() {
    final now = DateTime.now();
    final dateString =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final dateInt = int.parse(dateString);
    final index = dateInt % wordLadderPuzzles.length;
    return wordLadderPuzzles[index];
  }

  static String getTodayDate() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
  }

  static String getYesterdayDate() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return DateFormat('yyyy-MM-dd').format(yesterday);
  }

  static ValidationResult validateGuess(
    String guess,
    String startWord,
    String lastWord,
    Set<String> wordList,
  ) {
    // Convert to uppercase
    guess = guess.toUpperCase().trim();

    // Check 1: Length validation
    if (guess.length != startWord.length) {
      return ValidationResult.invalid('Must be ${startWord.length} letters.');
    }

    // Check 2: One letter difference
    int differences = 0;
    for (int i = 0; i < guess.length; i++) {
      if (guess[i] != lastWord[i]) {
        differences++;
      }
    }

    if (differences == 0) {
      return ValidationResult.invalid('Already played this word.');
    } else if (differences > 1) {
      return ValidationResult.invalid('Change only one letter at a time.');
    }

    // Check 3: Word list validation
    if (!wordList.contains(guess)) {
      return ValidationResult.invalid('Not a recognised word.');
    }

    return ValidationResult.valid();
  }

  static String getHint(List<String> currentChain, List<String> optimalPath) {
    final lastWord = currentChain.last;
    final lastWordIndexInOptimal = optimalPath.indexOf(lastWord);

    if (lastWordIndexInOptimal != -1 &&
        lastWordIndexInOptimal < optimalPath.length - 1) {
      final nextWord = optimalPath[lastWordIndexInOptimal + 1];
      return 'Next word starts with ${nextWord[0]}';
    }

    return 'Think about which letter is furthest from the target.';
  }

  static bool checkWinCondition(String lastWord, String targetWord) {
    return lastWord.toUpperCase() == targetWord.toUpperCase();
  }

  static int calculateNewStreak(
    String lastPlayedDate,
    String todayDate,
    int currentStreak,
  ) {
    // If already played today, don't increment
    if (lastPlayedDate == todayDate) {
      return currentStreak;
    }

    // If played yesterday, increment
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayDateStr = DateFormat('yyyy-MM-dd').format(yesterday);
    if (lastPlayedDate == yesterdayDateStr) {
      return currentStreak + 1;
    }

    // Otherwise reset to 1
    return 1;
  }
}
