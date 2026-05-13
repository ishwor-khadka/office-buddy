import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word_ladder_models.dart';
import '../services/word_ladder_service.dart';
import '../services/word_ladder_firebase_service.dart';

final wordLadderGameStateProvider =
    NotifierProvider<WordLadderGameNotifier, WordLadderGameState>(
      WordLadderGameNotifier.new,
    );

final userGameStatsProvider = FutureProvider<UserGameStats?>((ref) async {
  return WordLadderFirebaseService.getUserStats();
});

final todayLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  final todayDate = WordLadderService.getTodayDate();
  return WordLadderFirebaseService.getTodayLeaderboard(todayDate);
});

class WordLadderGameNotifier extends Notifier<WordLadderGameState> {
  Set<String> _wordList = {};

  @override
  WordLadderGameState build() {
    final initialState = _initializeGame();
    Future.microtask(() => loadWordList());
    return initialState;
  }

  static WordLadderGameState _initializeGame() {
    final puzzle = WordLadderService.getDailyPuzzle();
    return WordLadderGameState(
      startWord: puzzle.startWord,
      targetWord: puzzle.targetWord,
      optimalSteps: puzzle.optimalSteps,
      chain: [puzzle.startWord],
      optimalPath: puzzle.optimalPath,
      errorMessage: null,
      isWon: false,
      isPlaying: true,
      isWordListLoaded: false,
    );
  }

  Future<void> loadWordList({bool forceRefresh = false}) async {
    final words = await WordLadderFirebaseService.getWordList(
      forceRefresh: forceRefresh,
    );
    _wordList = words;
    state = state.copyWith(isWordListLoaded: true, errorMessage: null);
  }

  void submitGuess(String guess) {
    if (!state.isPlaying) return;
    if (!state.isWordListLoaded) {
      state = state.copyWith(errorMessage: 'Loading word list. Please wait.');
      return;
    }

    final validation = WordLadderService.validateGuess(
      guess,
      state.startWord,
      state.lastWord,
      _wordList,
    );

    if (!validation.isValid) {
      state = state.copyWith(errorMessage: validation.errorMessage);
      return;
    }

    final newChain = [...state.chain, guess.toUpperCase()];
    final isWon = WordLadderService.checkWinCondition(guess, state.targetWord);

    state = state.copyWith(
      chain: newChain,
      errorMessage: null,
      isWon: isWon,
      isPlaying: !isWon,
    );
  }

  void undoLastWord() {
    if (state.chain.length <= 1 || state.isWon) return;

    final newChain = state.chain.sublist(0, state.chain.length - 1);
    state = state.copyWith(chain: newChain, errorMessage: null);
  }

  String getHint() {
    return WordLadderService.getHint(state.chain, state.optimalPath);
  }

  void resetGame() {
    state = _initializeGame().copyWith(
      isWordListLoaded: state.isWordListLoaded,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
