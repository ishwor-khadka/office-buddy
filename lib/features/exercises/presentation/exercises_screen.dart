import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'exercise_detail_screen.dart';
import '../../../core/exercises/exercise.dart';
import '../../../core/exercises/exercise_providers.dart';
import '../../../core/exercises/favorites_providers.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';

final selectedCategoryProvider = NotifierProvider<CategoryNotifier, String>(
  CategoryNotifier.new,
);

class CategoryNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setCategory(String category) {
    state = category;
  }
}

Color _bodyPartColor(String bodyPart) => switch (bodyPart) {
  'Neck' => ObTokens.iris,
  'Back' => ObTokens.mintDeep,
  'Wrist' => ObTokens.sky,
  'Eyes' => const Color(0xFFF59E0B),
  _ => ObTokens.iris,
};

IconData _bodyPartIcon(String bodyPart) => switch (bodyPart) {
  'Neck' => LucideIcons.alignCenterVertical,
  'Back' => LucideIcons.moveVertical,
  'Wrist' => LucideIcons.hand,
  'Eyes' => LucideIcons.eye,
  _ => LucideIcons.dumbbell,
};

class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allExercises = ref.watch(exercisesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Exercise Library')),
      body: ObBackground(
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -40,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ObTokens.iris.withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ObTokens.mintDeep.withValues(alpha: 0.15),
                ),
              ),
            ),
            SafeArea(
              child: allExercises.when(
                data: (items) {
                  final favorites = favoritesAsync.asData?.value ?? <String>{};
                  final filtered = selectedCategory == 'All'
                      ? items
                      : items
                            .where((e) => e.bodyPart == selectedCategory)
                            .toList();
                  final quickAccess = items
                      .where((e) => favorites.contains(e.id))
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _CategoryStrip(
                          selected: selectedCategory,
                          onSelect: (cat) => ref
                              .read(selectedCategoryProvider.notifier)
                              .setCategory(cat),
                        ).animate().fade(duration: 280.ms).slideY(begin: -0.04),
                      ),
                      if (quickAccess.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: _SectionLabel(label: 'Quick Access'),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 88,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: quickAccess.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final ex = quickAccess[index];
                              return _QuickAccessCard(
                                exercise: ex,
                                onTap: () => _openDetail(context, ex),
                              );
                            },
                          ),
                        ).animate().fade(duration: 320.ms, delay: 40.ms),
                      ],
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: _SectionLabel(
                          label: selectedCategory == 'All'
                              ? 'All Exercises'
                              : '$selectedCategory Exercises',
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          cacheExtent: 900,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final exercise = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ExerciseCard(
                                exercise: exercise,
                                isFavorite: favorites.contains(exercise.id),
                                onTap: () => _openDetail(context, exercise),
                                onFavoriteTap: () => ref
                                    .read(favoritesProvider.notifier)
                                    .toggle(exercise.id),
                              ).animate(delay: (index * 30).ms).fade(
                                duration: 260.ms,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to load: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, Exercise exercise) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(exercise: exercise),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: ObTokens.text,
      letterSpacing: -0.2,
    ),
  );
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  static const _categories = ['All', 'Neck', 'Back', 'Wrist', 'Eyes'];

  @override
  Widget build(BuildContext context) {
    return ObGlass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories.map((cat) {
            final isSelected = selected == cat;
            final color = cat == 'All' ? ObTokens.iris : _bodyPartColor(cat);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              color,
                              color == ObTokens.iris
                                  ? ObTokens.sky
                                  : color.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (cat != 'All') ...[
                        Icon(
                          _bodyPartIcon(cat),
                          size: 13,
                          color: isSelected ? Colors.white : color,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : ObTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({required this.exercise, required this.onTap});
  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _bodyPartColor(exercise.bodyPart);
    final mins = (exercise.durationSeconds / 60).ceil();

    return SizedBox(
      width: 200,
      child: ObGlass(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.star, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      exercise.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ObTokens.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$mins min · ${exercise.bodyPart}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ObTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Exercise exercise;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _bodyPartColor(exercise.bodyPart);
    final mins = (exercise.durationSeconds / 60).ceil();
    final isDifficultEasy = exercise.difficulty == 'Easy';

    return ObGlass(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.85),
                    color == ObTokens.iris ? ObTokens.sky : color,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _bodyPartIcon(exercise.bodyPart),
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ObTokens.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Pill(label: exercise.bodyPart, color: color),
                      const SizedBox(width: 6),
                      _Pill(
                        label: '$mins min',
                        color: ObTokens.textMuted,
                        icon: LucideIcons.clock,
                      ),
                      const SizedBox(width: 6),
                      _Pill(
                        label: exercise.difficulty,
                        color: isDifficultEasy
                            ? ObTokens.mintDeep
                            : const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onFavoriteTap,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isFavorite ? LucideIcons.star : LucideIcons.starOff,
                      size: 16,
                      color: isFavorite
                          ? const Color(0xFFF59E0B)
                          : ObTokens.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: ObTokens.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
