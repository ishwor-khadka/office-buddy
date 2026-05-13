import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word_ladder_models.dart';
import '../services/word_ladder_service.dart';
import '../services/word_ladder_firebase_service.dart';
import '../providers/word_ladder_provider.dart';

class WordLadderResultScreen extends ConsumerStatefulWidget {
  final UserGameStats? stats;
  final WordLadderGameState? gameState;
  final String todayDate;

  const WordLadderResultScreen({
    Key? key,
    this.stats,
    this.gameState,
    required this.todayDate,
  }) : super(key: key);

  @override
  ConsumerState<WordLadderResultScreen> createState() =>
      _WordLadderResultScreenState();
}

class _WordLadderResultScreenState
    extends ConsumerState<WordLadderResultScreen> {
  bool _hasBeenSaved = false;

  @override
  void initState() {
    super.initState();
    _saveResultIfNeeded();
  }

  Future<void> _saveResultIfNeeded() async {
    if (_hasBeenSaved || widget.gameState == null) return;
    if (widget.stats != null && widget.stats!.lastPlayed == widget.todayDate)
      return;

    _hasBeenSaved = true;

    final gameState = widget.gameState!;
    final stats = widget.stats;
    final steps = gameState.displaySteps;
    final oldBestSteps = stats?.bestSteps ?? 999;
    final newBestSteps = steps < oldBestSteps ? steps : oldBestSteps;

    final newStreak = WordLadderService.calculateNewStreak(
      stats?.lastPlayed ?? '',
      widget.todayDate,
      stats?.streak ?? 0,
    );

    final displayName =
        'Player'; // You can get the actual user display name from Firebase Auth

    await WordLadderFirebaseService.saveGameResult(
      steps: steps,
      newStreak: newStreak,
      newBestSteps: newBestSteps,
      todayDate: widget.todayDate,
      displayName: displayName,
    );

    // Refresh the providers
    ref.refresh(userGameStatsProvider);
    ref.refresh(todayLeaderboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(todayLeaderboardProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Result',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              'TODAY\'S PUZZLE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF999999),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: widget.gameState != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Congratulations
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color(0xFFE3F2FD)),
                    ),
                    child: Column(
                      children: [
                        Text('🎉', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          'Congratulations!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You solved the puzzle!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Score display
                  ScoreWidget(
                    gameState: widget.gameState!,
                    stats: widget.stats,
                  ),
                  const SizedBox(height: 32),

                  // Leaderboard
                  leaderboardAsync.when(
                    data: (leaderboard) =>
                        LeaderboardWidget(entries: leaderboard),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 32),

                  // Play tomorrow button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'BACK TO HOME',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Center(child: Text('No game data available')),
    );
  }
}

class ScoreWidget extends StatelessWidget {
  final WordLadderGameState gameState;
  final UserGameStats? stats;

  const ScoreWidget({Key? key, required this.gameState, this.stats})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final steps = gameState.displaySteps;
    final isOptimal = steps == gameState.optimalSteps;
    final extraSteps = steps - gameState.optimalSteps;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFFFFE0B2)),
          ),
          child: Column(
            children: [
              Text(
                steps.toString(),
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'STEPS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF999999),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              if (isOptimal)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '⭐ Optimal!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Text(
                  '+$extraSteps ${extraSteps == 1 ? 'step' : 'steps'} from optimal',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (stats != null)
          Row(
            children: [
              Expanded(
                child: _ScoreDetail(
                  label: 'Best',
                  value: stats!.bestSteps == 999
                      ? '-'
                      : stats!.bestSteps.toString(),
                  icon: '⭐',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScoreDetail(
                  label: 'Streak',
                  value: stats!.streak.toString(),
                  icon: '🔥',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScoreDetail(
                  label: 'Wins',
                  value: stats!.totalWins.toString(),
                  icon: '🏆',
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ScoreDetail extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _ScoreDetail({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Text(icon, style: TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class LeaderboardWidget extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const LeaderboardWidget({Key? key, required this.entries}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OFFICE LEADERBOARD',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF999999),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFEEEEEE)),
          ),
          child: Column(
            children: entries.asMap().entries.map((entry) {
              final index = entry.key;
              final leaderboardEntry = entry.value;
              final isTopThree = index < 3;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: index != entries.length - 1
                      ? Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isTopThree
                            ? Color(0xFFFFD700)
                            : Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          isTopThree ? '🏆' : '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isTopThree ? 14 : 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        leaderboardEntry.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    Text(
                      '${leaderboardEntry.steps} steps',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
