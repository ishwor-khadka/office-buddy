# Word Ladder Game - Implementation Guide

## Overview

Word Ladder (aka "Brainstorm") is a daily word puzzle game integrated into the Office Buddy app. Players have to build a chain from a start word to a target word by changing exactly one letter at a time. Every word in the chain must be a real English word. The app automatically resets with a new puzzle every day.

## Features Implemented

### 1. Daily Puzzle System
- **Hardcoded Puzzle List**: 30+ puzzle pairs stored in `word_ladder_puzzles.dart`
- **Automatic Date-Based Selection**: Uses `(yyyymmdd % total_puzzles)` to select today's puzzle
- **No API Calls Needed**: All logic runs locally in the app

### 2. Game Mechanics
- **Three-Step Validation**:
  1. Length check: Guess must match word length
  2. One-letter difference: Exactly one letter must change from the last word
  3. Word validation: Guess must be in the word list (800+ words)
  
- **Chain Management**:
  - Starts with [startWord]
  - Appends valid guesses
  - Undo removes last word (minimum of 1 word)
  
- **Win Condition**: User's last word matches target word

### 3. Hint System
- **Path-Based Hints**: Reveals first letter of next word in optimal path
- **Fallback Hints**: Generic hints if player goes off the optimal path

### 4. Scoring & Stats
- **Steps Count**: `chain.length - 1`
- **Optimal Comparison**: Shows if player matched or exceeded optimal
- **Streak System**:
  - Increments if last played yesterday
  - Resets to 1 if played 2+ days ago
  - No change if already played today
- **Best Steps**: Tracks best score for the puzzle

### 5. Firebase Integration
- **User Stats** (`users/{userId}/game`):
  - `lastPlayed`: Date (YYYY-MM-DD)
  - `streak`: Current streak count
  - `bestSteps`: Best score ever
  - `totalWins`: Total games won

- **Daily Leaderboard** (`leaderboard/{YYYY-MM-DD}`):
  - Player name → steps taken
  - Sorted by ascending step count
  - Updated when player finishes

### 6. Responsive UI
- **Mobile-first Design**: Optimized for phones
- **Clean Layout**: 
  - Header with title and streak badge
  - Start → Target word display
  - Current chain visualization
  - Input field with validation feedback
  - Action buttons (Submit, Undo, Hint)
  - Stats display
- **Animations**: Smooth transitions and visual feedback
- **Result Screen**: Post-game leaderboard, stats, and replay option

## File Structure

```
lib/features/word_ladder/
├── data/
│   ├── word_ladder_puzzles.dart       # 30+ puzzle pairs with optimal paths
│   └── word_ladder_word_list.dart     # ~800 valid English words for validation
├── models/
│   └── word_ladder_models.dart        # GameState, UserStats, ValidationResult classes
├── services/
│   ├── word_ladder_service.dart       # Game logic (validation, scoring, hints)
│   └── word_ladder_firebase_service.dart  # Firebase read/write operations
├── providers/
│   └── word_ladder_provider.dart      # Riverpod state management
├── screens/
│   ├── word_ladder_screen.dart        # Main game screen
│   └── word_ladder_result_screen.dart # Result & leaderboard screen
└── widgets/
    └── word_ladder_widgets.dart       # Reusable UI components
```

## Navigation Integration

### Bottom Navigation
- Added "Brainstorm" tab (lightbulb icon) as the 3rd tab in the main navigation
- Updated `MainScaffold` to include Word Ladder screen
- Updated `ObBottomBar` to show 5 tabs: Home, Stats, **Brainstorm**, Sleep, Exercise

### Routes
- Added `/word-ladder-screen` route in `app_router.dart`
- Added `wordLadderScreen` constant in `app_routes.dart`

## Game Flow

1. **App Load**:
   - Check Firebase for user's `lastPlayed` date
   - If equals today: Show result screen (prevent replay)
   - Else: Load today's puzzle and show game screen

2. **Playing**:
   - User guesses words
   - Validation runs: length → one-letter diff → word exists
   - Valid words added to chain
   - After each word, check if matches target

3. **Win**:
   - Calculate steps: `chain.length - 1`
   - Calculate new streak (compare lastPlayed to yesterday)
   - Save to Firebase (user stats + leaderboard)
   - Show result screen with stats and leaderboard

## Key Implementation Details

### Validation Logic (`word_ladder_service.dart`)
```dart
WordLadderService.validateGuess(guess, startWord, lastWord)
// Returns: ValidationResult with isValid flag and error message
```

### Daily Puzzle Selection
```dart
final dateInt = int.parse('20260511');  // Today
final index = dateInt % puzzleCount;     // Get today's puzzle
final puzzle = wordLadderPuzzles[index];
```

### Streak Calculation
```dart
// If already played today: no change
// If last played yesterday: increment +1
// Otherwise: reset to 1
```

### Firebase Operations
- **Read Stats**: Async operation on game load
- **Save Result**: Atomic write to user stats + leaderboard
- **Fetch Leaderboard**: Reads daily document and sorts by steps

## State Management (Riverpod)

### Providers
- `wordLadderGameStateProvider`: Game state (chain, puzzle, win condition)
- `userGameStatsProvider`: User's stats from Firebase
- `todayLeaderboardProvider`: Today's leaderboard entries

### State Notifier
- `WordLadderGameNotifier`: Manages game actions (submitGuess, undo, hint)

## UI Components

### Word Card
Displays start/target words with colored backgrounds

### Chain Display
Shows all words in the current chain with step numbers

### Input Field
Text input with real-time validation and error messages

### Stats Display
Shows current steps, best steps, and streak

### Leaderboard Widget
Lists top performers with medals and rankings

## Responsive Design

- **Phone (< 600px)**: Single column layout, full-width components
- **Tablet (≥ 600px)**: Can be enhanced with side-by-side panels
- **Text sizing**: Scales with screen size
- **Touch targets**: Minimum 48px for easy interaction

## Edge Cases Handled

1. **User plays twice in one day**: Redirected to result screen
2. **Word not in list but valid English**: Rejected with guidance
3. **User types same word twice**: Rejected as 0 letter changes
4. **User changes multiple letters**: Rejected as > 1 letter changes
5. **Midnight transition**: Automatic via date calculation
6. **No internet (Firebase unavailable)**: Falls back to local game

## Data Storage Summary

| Data | Location | Access |
|------|----------|--------|
| Puzzle list | App code | Local only |
| Word validation list | App code | Local only |
| Daily puzzle selection | App code | Local math |
| Game chain | App memory | Temporary |
| User stats | Firebase | Read once at load, write at finish |
| Leaderboard | Firebase | Read at finish |

## Testing the Game

1. **From Bottom Nav**: Tap "Brainstorm" tab
2. **First-time player**: Sees today's puzzle and can play
3. **Already played today**: Redirected to result screen
4. **Validation**: Try invalid guesses to see error messages
5. **Leaderboard**: Finish game to see office rankings
6. **Next day**: New puzzle automatically appears

## Future Enhancements

- [ ] Difficulty levels (3-letter, 5-letter, 6-letter words)
- [ ] Weekly challenges with bonus points
- [ ] Achievements/badges for milestones
- [ ] Share results to office chat
- [ ] Sound effects for correct guesses
- [ ] Analytics on common wrong guesses
- [ ] Expand word list based on user feedback
- [ ] Multiplayer mode (race against coworkers)

## Dependencies Added

- `intl: ^0.19.0` - Date formatting

## No Breaking Changes

- All existing features remain unchanged
- Navigation updated to include new tab (5 tabs instead of 4)
- No database schema changes (only reads/writes existing docs)
