import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/word_ladder_word_list.dart';
import '../models/word_ladder_models.dart';

class WordLadderFirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static Set<String>? _cachedWordList;
  static const _wordLadderCollection = 'word_ladder';
  static const _wordListDocument = 'word_list';

  static String get userId => _auth.currentUser?.uid ?? '';

  static Future<Set<String>> getWordList({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedWordList != null) {
      return _cachedWordList!;
    }

    try {
      final wordListDoc = await _firestore
          .collection(_wordLadderCollection)
          .doc(_wordListDocument)
          .get();

      if (!wordListDoc.exists || wordListDoc.data() == null) {
        final seedWords = getDefaultWordLadderSeedWords();
        await _firestore
            .collection(_wordLadderCollection)
            .doc(_wordListDocument)
            .set({
              'words': seedWords.toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
        _cachedWordList = seedWords;
        return seedWords;
      }

      final rawWords = wordListDoc.data()?['words'] as List<dynamic>? ?? [];
      final firestoreWords = rawWords
          .whereType<String>()
          .map((word) => word.trim().toUpperCase())
          .where((word) => word.isNotEmpty)
          .toSet();

      if (firestoreWords.isEmpty) {
        final seedWords = getDefaultWordLadderSeedWords();
        await _firestore
            .collection(_wordLadderCollection)
            .doc(_wordListDocument)
            .set({
              'words': seedWords.toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        _cachedWordList = seedWords;
        return seedWords;
      }

      _cachedWordList = firestoreWords;
      return firestoreWords;
    } catch (e) {
      print('Error fetching word list: $e');
      final fallbackWords = getDefaultWordLadderSeedWords();
      _cachedWordList = fallbackWords;
      return fallbackWords;
    }
  }

  static Future<UserGameStats?> getUserStats() async {
    try {
      if (userId.isEmpty) return null;

      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists || doc.data() == null) {
        return const UserGameStats(
          lastPlayed: '',
          streak: 0,
          bestSteps: 999,
          totalWins: 0,
        );
      }

      final gameData = doc.data()?['game'] as Map<String, dynamic>?;
      if (gameData == null) {
        return const UserGameStats(
          lastPlayed: '',
          streak: 0,
          bestSteps: 999,
          totalWins: 0,
        );
      }

      return UserGameStats(
        lastPlayed: gameData['lastPlayed'] as String? ?? '',
        streak: gameData['streak'] as int? ?? 0,
        bestSteps: gameData['bestSteps'] as int? ?? 999,
        totalWins: gameData['totalWins'] as int? ?? 0,
      );
    } catch (e) {
      print('Error fetching user stats: $e');
      return null;
    }
  }

  static Future<void> saveGameResult({
    required int steps,
    required int newStreak,
    required int newBestSteps,
    required String todayDate,
    required String displayName,
  }) async {
    try {
      if (userId.isEmpty) return;

      // Update user stats
      await _firestore.collection('users').doc(userId).set({
        'game': {
          'lastPlayed': todayDate,
          'streak': newStreak,
          'bestSteps': newBestSteps,
          'totalWins': FieldValue.increment(1),
        },
      }, SetOptions(merge: true));

      // Update leaderboard
      await _firestore.collection('leaderboard').doc(todayDate).set({
        displayName: steps,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving game result: $e');
    }
  }

  static Future<List<LeaderboardEntry>> getTodayLeaderboard(
    String todayDate,
  ) async {
    try {
      final doc = await _firestore
          .collection('leaderboard')
          .doc(todayDate)
          .get();

      if (!doc.exists || doc.data() == null) {
        return [];
      }

      final data = doc.data() as Map<String, dynamic>;
      final entries = data.entries
          .map((e) => LeaderboardEntry(name: e.key, steps: e.value as int))
          .toList();

      entries.sort((a, b) => a.steps.compareTo(b.steps));
      return entries;
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }
}
