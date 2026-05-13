class WordLadderPuzzle {
  final String startWord;
  final String targetWord;
  final int optimalSteps;
  final List<String> optimalPath;

  WordLadderPuzzle({
    required this.startWord,
    required this.targetWord,
    required this.optimalSteps,
    required this.optimalPath,
  });
}

final List<WordLadderPuzzle> wordLadderPuzzles = [
  WordLadderPuzzle(
    startWord: 'WARM',
    targetWord: 'COLD',
    optimalSteps: 4,
    optimalPath: ['WARM', 'WORM', 'WORD', 'CORD', 'COLD'],
  ),
  WordLadderPuzzle(
    startWord: 'HATE',
    targetWord: 'LOVE',
    optimalSteps: 3,
    optimalPath: ['HATE', 'LATE', 'LOVE'],
  ),
  WordLadderPuzzle(
    startWord: 'SHIP',
    targetWord: 'BOAT',
    optimalSteps: 4,
    optimalPath: ['SHIP', 'SHOP', 'SLOP', 'SLOT', 'BOAT'],
  ),
  WordLadderPuzzle(
    startWord: 'BACK',
    targetWord: 'FACE',
    optimalSteps: 4,
    optimalPath: ['BACK', 'PACK', 'PAGE', 'PACE', 'FACE'],
  ),
  WordLadderPuzzle(
    startWord: 'HARD',
    targetWord: 'EASY',
    optimalSteps: 4,
    optimalPath: ['HARD', 'HARE', 'FARE', 'EASY'],
  ),
  WordLadderPuzzle(
    startWord: 'WORK',
    targetWord: 'PLAY',
    optimalSteps: 4,
    optimalPath: ['WORK', 'WORM', 'WARM', 'WARY', 'PLAY'],
  ),
  WordLadderPuzzle(
    startWord: 'TIME',
    targetWord: 'LIFE',
    optimalSteps: 3,
    optimalPath: ['TIME', 'LIME', 'LIFE'],
  ),
  WordLadderPuzzle(
    startWord: 'FAST',
    targetWord: 'SLOW',
    optimalSteps: 4,
    optimalPath: ['FAST', 'LAST', 'LOST', 'SLOW'],
  ),
  WordLadderPuzzle(
    startWord: 'PAIN',
    targetWord: 'GAIN',
    optimalSteps: 1,
    optimalPath: ['PAIN', 'GAIN'],
  ),
  WordLadderPuzzle(
    startWord: 'HEAR',
    targetWord: 'HELP',
    optimalSteps: 3,
    optimalPath: ['HEAR', 'HEAP', 'HELP'],
  ),
  WordLadderPuzzle(
    startWord: 'DARK',
    targetWord: 'MARK',
    optimalSteps: 1,
    optimalPath: ['DARK', 'MARK'],
  ),
  WordLadderPuzzle(
    startWord: 'GOOD',
    targetWord: 'EVIL',
    optimalSteps: 3,
    optimalPath: ['GOOD', 'GOLD', 'EVIL'],
  ),
  WordLadderPuzzle(
    startWord: 'WEAK',
    targetWord: 'STRONG',
    optimalSteps: 4,
    optimalPath: ['WEAK', 'WEAL', 'SEAL', 'DEAL'],
  ),
  WordLadderPuzzle(
    startWord: 'RAIN',
    targetWord: 'SNOW',
    optimalSteps: 4,
    optimalPath: ['RAIN', 'RUIN', 'SHIN', 'SLOW', 'SNOW'],
  ),
  WordLadderPuzzle(
    startWord: 'FIRE',
    targetWord: 'WIRE',
    optimalSteps: 1,
    optimalPath: ['FIRE', 'WIRE'],
  ),
  WordLadderPuzzle(
    startWord: 'JOKE',
    targetWord: 'POKE',
    optimalSteps: 1,
    optimalPath: ['JOKE', 'POKE'],
  ),
  WordLadderPuzzle(
    startWord: 'RICH',
    targetWord: 'POOR',
    optimalSteps: 3,
    optimalPath: ['RICH', 'RICE', 'POOR'],
  ),
  WordLadderPuzzle(
    startWord: 'TREE',
    targetWord: 'BUSH',
    optimalSteps: 4,
    optimalPath: ['TREE', 'FREE', 'FUSE', 'BUSH'],
  ),
  WordLadderPuzzle(
    startWord: 'TALL',
    targetWord: 'SHORT',
    optimalSteps: 4,
    optimalPath: ['TALL', 'TAIL', 'SAIL', 'SORT'],
  ),
  WordLadderPuzzle(
    startWord: 'BOLD',
    targetWord: 'MEEK',
    optimalSteps: 4,
    optimalPath: ['BOLD', 'BOLE', 'MOLE', 'MEEK'],
  ),
  WordLadderPuzzle(
    startWord: 'RISE',
    targetWord: 'FALL',
    optimalSteps: 3,
    optimalPath: ['RISE', 'RILE', 'FALL'],
  ),
  WordLadderPuzzle(
    startWord: 'DAMP',
    targetWord: 'DRAY',
    optimalSteps: 2,
    optimalPath: ['DAMP', 'DAME', 'DRAY'],
  ),
  WordLadderPuzzle(
    startWord: 'BEST',
    targetWord: 'WEST',
    optimalSteps: 1,
    optimalPath: ['BEST', 'WEST'],
  ),
  WordLadderPuzzle(
    startWord: 'HIGH',
    targetWord: 'SIGH',
    optimalSteps: 1,
    optimalPath: ['HIGH', 'SIGH'],
  ),
  WordLadderPuzzle(
    startWord: 'NEAR',
    targetWord: 'FEAR',
    optimalSteps: 1,
    optimalPath: ['NEAR', 'FEAR'],
  ),
  WordLadderPuzzle(
    startWord: 'WAKE',
    targetWord: 'MAKE',
    optimalSteps: 1,
    optimalPath: ['WAKE', 'MAKE'],
  ),
  WordLadderPuzzle(
    startWord: 'BLUE',
    targetWord: 'GLUE',
    optimalSteps: 1,
    optimalPath: ['BLUE', 'GLUE'],
  ),
  WordLadderPuzzle(
    startWord: 'LOVE',
    targetWord: 'LOSE',
    optimalSteps: 2,
    optimalPath: ['LOVE', 'LOSE'],
  ),
  WordLadderPuzzle(
    startWord: 'MAKE',
    targetWord: 'TAKE',
    optimalSteps: 1,
    optimalPath: ['MAKE', 'TAKE'],
  ),
  WordLadderPuzzle(
    startWord: 'CARE',
    targetWord: 'DARE',
    optimalSteps: 1,
    optimalPath: ['CARE', 'DARE'],
  ),
  WordLadderPuzzle(
    startWord: 'HOPE',
    targetWord: 'ROPE',
    optimalSteps: 1,
    optimalPath: ['HOPE', 'ROPE'],
  ),
];
