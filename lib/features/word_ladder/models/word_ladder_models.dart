class WordLadderGameState {
  final String startWord;
  final String targetWord;
  final int optimalSteps;
  final List<String> chain;
  final List<String> optimalPath;
  final String? errorMessage;
  final bool isWon;
  final bool isPlaying;
  final bool isWordListLoaded;

  const WordLadderGameState({
    required this.startWord,
    required this.targetWord,
    required this.optimalSteps,
    required this.chain,
    required this.optimalPath,
    required this.errorMessage,
    required this.isWon,
    required this.isPlaying,
    required this.isWordListLoaded,
  });

  int get displaySteps => chain.length - 1;
  String get lastWord => chain.isNotEmpty ? chain.last : '';
  int get stepsFromOptimal => displaySteps - optimalSteps;

  WordLadderGameState copyWith({
    String? startWord,
    String? targetWord,
    int? optimalSteps,
    List<String>? chain,
    List<String>? optimalPath,
    String? errorMessage,
    bool? isWon,
    bool? isPlaying,
    bool? isWordListLoaded,
  }) {
    return WordLadderGameState(
      startWord: startWord ?? this.startWord,
      targetWord: targetWord ?? this.targetWord,
      optimalSteps: optimalSteps ?? this.optimalSteps,
      chain: chain ?? this.chain,
      optimalPath: optimalPath ?? this.optimalPath,
      errorMessage: errorMessage,
      isWon: isWon ?? this.isWon,
      isPlaying: isPlaying ?? this.isPlaying,
      isWordListLoaded: isWordListLoaded ?? this.isWordListLoaded,
    );
  }
}

class UserGameStats {
  final String lastPlayed;
  final int streak;
  final int bestSteps;
  final int totalWins;

  const UserGameStats({
    required this.lastPlayed,
    required this.streak,
    required this.bestSteps,
    required this.totalWins,
  });

  UserGameStats copyWith({
    String? lastPlayed,
    int? streak,
    int? bestSteps,
    int? totalWins,
  }) {
    return UserGameStats(
      lastPlayed: lastPlayed ?? this.lastPlayed,
      streak: streak ?? this.streak,
      bestSteps: bestSteps ?? this.bestSteps,
      totalWins: totalWins ?? this.totalWins,
    );
  }
}

class LeaderboardEntry {
  final String name;
  final int steps;

  const LeaderboardEntry({required this.name, required this.steps});
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult({required this.isValid, this.errorMessage});

  factory ValidationResult.valid() => ValidationResult(isValid: true);

  factory ValidationResult.invalid(String message) =>
      ValidationResult(isValid: false, errorMessage: message);
}
