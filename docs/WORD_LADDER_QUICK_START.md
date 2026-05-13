# Word Ladder Game - Quick Start Guide

## What Is Word Ladder?

A **daily word puzzle** where you transform a start word into a target word by changing exactly one letter at a time. Every intermediate word must be a valid English word.

**Example:** WARM → COLD
- WARM (start)
- WORM (changed A→O)
- WORD (changed M→D)
- CORD (changed W→C)
- COLD (changed R→L) ✓ Target reached!

## Getting Started

### 1. Navigate to the Game
- Open Office Buddy app
- Tap the **Brainstorm** tab in the bottom navigation (lightbulb icon)

### 2. First Puzzle Load
- The app calculates today's puzzle based on the date
- Everyone in your office gets the same puzzle today
- A new puzzle appears automatically tomorrow

### 3. Playing
1. **See the puzzle**: Start word on the left, target word on the right
2. **Type a word**: Enter a valid English word in the input field
3. **Follow the rules**:
   - Must be the same length as the start word
   - Must differ by exactly ONE letter from your last word
   - Must be a recognized English word
4. **Submit**: Tap the SUBMIT button
5. **Build your chain**: Each valid word appears above in the chain

### 4. Actions While Playing
- **UNDO**: Remove your last word and try again (keeps start word)
- **HINT**: Get a clue about the next word in the optimal path
- **See Stats**: Current steps, best score, and streak

### 5. Win & Results
- When your word matches the target: **You win!** 🎉
- Results screen shows:
  - Number of steps you took
  - Whether you matched the optimal score
  - Your streak (consecutive days played)
  - Your best score ever
  - Office leaderboard (who solved it in fewest steps)

## Validation Rules

The game checks your guess in this order. It stops at the first error:

### ❌ Check 1: Length
- "Must be X letters"
- Your word must match the length of the start word

### ❌ Check 2: One Letter Change
- "Already played this word" — You typed the same word again
- "Change only one letter at a time" — You changed 2+ letters
- You must change exactly ONE letter from your previous word

### ❌ Check 3: Real Word
- "Not a recognised word"
- The word must be in our English dictionary

## Understanding Your Score

| Metric | What It Means |
|--------|---------------|
| STEPS | Total moves to reach the target |
| BEST | Your personal best score (across all time) |
| STREAK | Days in a row you've solved the puzzle |
| OPTIMAL | The fewest possible steps (hardcoded) |

**Optimal Badge**: If your steps = optimal, you see ⭐ **Optimal!**

## Streak System

Your **streak** tracks consecutive days you play:

- **Played yesterday?** Streak increases by 1 ✅
- **Played 2+ days ago?** Streak resets to 1 (new streak)
- **Already played today?** Streak unchanged

## Office Leaderboard

After you finish, your score appears in the **OFFICE LEADERBOARD**:

- Sorted by fewest steps (best first)
- Top 3 get medals: 🏆
- Everyone else gets a number
- Updates in real-time as coworkers finish

## Daily Puzzle Schedule

- **New puzzle every day** at midnight
- Puzzle changes automatically in the app (no manual refresh needed)
- Each day's puzzle is the same for everyone in your office
- Your progress saves to your account automatically

## Can I Play Offline?

**Yes!** The game works completely offline:
- Puzzle generation is local
- Word validation is local
- Your chain tracking is local
- Firebase sync happens when you finish and have internet

## Tips & Tricks

1. **Think of common words** — The word list includes ~800 common 4-letter English words
2. **Use HINT strategically** — Hints show the first letter of the next word in the optimal path
3. **UNDO freely** — No penalty for trying and undoing
4. **Compete with coworkers** — Check the leaderboard to see who solved it fastest
5. **Keep your streak** — Play every day to build your consecutive days counter

## Common Issues

### "Not a recognised word"
- The word is real English, but not in our dictionary
- Our word list has ~800 words (not exhaustive)
- Try a different path

### "Already played today"
- You completed the puzzle earlier today
- Each puzzle can only be solved once per day
- New puzzle appears tomorrow

### "Change only one letter at a time"
- You changed 2+ letters in one guess
- Go back and make smaller changes

### Not seeing the leaderboard
- You must finish the puzzle first
- Leaderboard appears on the results screen

## What Gets Saved?

### Your Phone (Local)
- Current game chain
- Today's puzzle info

### Your Office Buddy Account (Firebase)
- Last played date
- Current streak
- Best score
- Total wins
- Your scores in the office leaderboard

## Getting Help

- **Game rules**: See the "Change one letter at a time" instruction
- **Validation errors**: Read the error message (it tells you what's wrong)
- **Hint**: Tap HINT to see the first letter of the next word
- **Undo**: Tap UNDO to remove your last word and try again

## Game Stats Example

```
Last Played: 2026-05-11
Streak: 7 days 🔥
Best Steps: 3
Total Wins: 42

Today's Result:
Steps: 5
Optimal: 4
Status: +1 from optimal
```

## Enjoy the Game! 🎮

Word Ladder is designed to be a quick, fun brain exercise during your workday. It's not just about solving the puzzle—it's about doing it efficiently and maintaining your daily streak.

**Happy word-building!** 🧠
