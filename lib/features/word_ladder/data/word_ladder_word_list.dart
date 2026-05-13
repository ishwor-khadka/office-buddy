import 'word_ladder_puzzles.dart';

/// Local seed used only to bootstrap Firestore when the remote list is empty.
Set<String> getDefaultWordLadderSeedWords() {
  final words = <String>{};

  for (final puzzle in wordLadderPuzzles) {
    words.add(puzzle.startWord.toUpperCase());
    words.add(puzzle.targetWord.toUpperCase());
    words.addAll(puzzle.optimalPath.map((word) => word.toUpperCase()));
  }

  return words;
}
