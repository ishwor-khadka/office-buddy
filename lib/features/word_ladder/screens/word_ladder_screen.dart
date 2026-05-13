import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/word_ladder_provider.dart';
import '../services/word_ladder_service.dart';
import '../services/word_ladder_firebase_service.dart';
import '../widgets/word_ladder_widgets.dart';
import 'word_ladder_result_screen.dart';

class WordLadderScreen extends ConsumerStatefulWidget {
  const WordLadderScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WordLadderScreen> createState() => _WordLadderScreenState();
}

class _WordLadderScreenState extends ConsumerState<WordLadderScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(wordLadderGameStateProvider.notifier).loadWordList();
    _checkIfAlreadyPlayed();
  }

  Future<void> _checkIfAlreadyPlayed() async {
    final stats = await WordLadderFirebaseService.getUserStats();
    if (stats != null && stats.lastPlayed == WordLadderService.getTodayDate()) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WordLadderResultScreen(
              stats: stats,
              todayDate: WordLadderService.getTodayDate(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(wordLadderGameStateProvider);
    final statsAsync = ref.watch(userGameStatsProvider);

    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Word Ladder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                'BRAIN EXERCISE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF999999),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Color(0xFFFF9800),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    statsAsync.when(
                      data: (stats) => Text(
                        '${stats?.streak ?? 0}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      loading: () => Text(
                        '0',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      error: (_, __) => Text(
                        '0',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: !gameState.isWordListLoaded
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading word list from Firestore...',
                      style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        ref
                            .read(wordLadderGameStateProvider.notifier)
                            .loadWordList(forceRefresh: true);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : gameState.isWon
            ? WordLadderResultScreen(
                stats: statsAsync.maybeWhen(
                  data: (stats) => stats,
                  orElse: () => null,
                ),
                gameState: gameState,
                todayDate: WordLadderService.getTodayDate(),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Puzzle display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        WordCard(
                          word: gameState.startWord,
                          label: 'START',
                          backgroundColor: const Color(0xFFFFF3E0),
                          textColor: const Color(0xFF8B4513),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFF999999),
                          ),
                        ),
                        WordCard(
                          word: gameState.targetWord,
                          label: 'TARGET',
                          backgroundColor: const Color(0xFFE3F2FD),
                          textColor: const Color(0xFF1565C0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Instructions
                    Text(
                      'Change one letter at a time',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Chain display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFEEEEEE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHAIN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF999999),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ChainDisplay(chain: gameState.chain),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Input field
                    InputField(
                      expectedLength: gameState.startWord.length,
                      onSubmit: (word) {
                        ref
                            .read(wordLadderGameStateProvider.notifier)
                            .submitGuess(word);
                      },
                      errorMessage: gameState.errorMessage,
                      onClear: () {
                        ref
                            .read(wordLadderGameStateProvider.notifier)
                            .clearError();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(wordLadderGameStateProvider.notifier)
                                  .undoLastWord();
                            },
                            icon: const Icon(Icons.undo),
                            label: const Text('UNDO'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Color(0xFF4CAF50),
                              side: BorderSide(color: Color(0xFF4CAF50)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final hint = ref
                                  .read(wordLadderGameStateProvider.notifier)
                                  .getHint();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(hint),
                                  duration: Duration(seconds: 3),
                                  backgroundColor: Color(0xFF1565C0),
                                ),
                              );
                            },
                            icon: const Icon(Icons.lightbulb_outline),
                            label: const Text('HINT'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Color(0xFF1565C0),
                              side: BorderSide(color: Color(0xFF1565C0)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stats
                    statsAsync.when(
                      data: (stats) => StatsDisplay(
                        currentSteps: gameState.displaySteps,
                        optimalSteps: gameState.optimalSteps,
                        bestSteps: stats?.bestSteps ?? 999,
                        streak: stats?.streak ?? 0,
                      ),
                      loading: () => StatsDisplay(
                        currentSteps: gameState.displaySteps,
                        optimalSteps: gameState.optimalSteps,
                        bestSteps: 999,
                        streak: 0,
                      ),
                      error: (_, __) => StatsDisplay(
                        currentSteps: gameState.displaySteps,
                        optimalSteps: gameState.optimalSteps,
                        bestSteps: 999,
                        streak: 0,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
