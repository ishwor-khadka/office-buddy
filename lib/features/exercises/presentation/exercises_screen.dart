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

class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key});

  static const _navSelectedColor = Color(0xFF00B78B);
  static const _navUnselectedColor = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allExercises = ref.watch(exercisesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Exercise Library')),
      body: ObBackground(
        child: SafeArea(
          child: allExercises.when(
            data: (items) {
              final favorites = favoritesAsync.asData?.value ?? <String>{};
              final filtered = selectedCategory == 'All'
                  ? items
                  : items.where((e) => e.bodyPart == selectedCategory).toList();

              final quickAccess = items
                  .where((e) => favorites.contains(e.id))
                  .toList();

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ObGlass(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['All', 'Neck', 'Back', 'Wrist', 'Eyes']
                              .map((cat) {
                                final isSelected = selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(cat),
                                    selected: isSelected,
                                    onSelected: (val) {
                                      ref
                                          .read(
                                            selectedCategoryProvider.notifier,
                                          )
                                          .setCategory(cat);
                                    },
                                    selectedColor: ObTokens.mint.withValues(
                                      alpha: 0.18,
                                    ),
                                    backgroundColor: Colors.transparent,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? _navSelectedColor
                                          : _navUnselectedColor,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ).animate().fade().slideX(begin: 0.05),
                    const SizedBox(height: 14),
                    if (quickAccess.isNotEmpty) ...[
                      Text('Quick Access', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 98,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: quickAccess.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final ex = quickAccess[index];
                            return SizedBox(
                              width: 210,
                              child: ObGlass(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ExerciseDetailScreen(exercise: ex),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      const Icon(LucideIcons.star),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          ex.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final exercise = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child:
                                _buildExerciseCard(
                                      context,
                                      ref,
                                      exercise,
                                      favorites.contains(exercise.id),
                                    )
                                    .animate(key: ValueKey(exercise.id))
                                    .fade(
                                      duration: 350.ms,
                                      delay: (60 * index).ms,
                                    )
                                    .slideY(begin: 0.06),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Failed to load: $e')),
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(
    BuildContext context,
    WidgetRef ref,
    Exercise exercise,
    bool isFavorite,
  ) {
    final theme = Theme.of(context);
    final mins = (exercise.durationSeconds / 60).ceil();
    return ObGlass(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ExerciseDetailScreen(exercise: exercise),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.9),
                    theme.colorScheme.secondary.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: const Icon(LucideIcons.dumbbell, color: Colors.white),
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
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.tag,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        exercise.bodyPart,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        LucideIcons.clock,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('$mins min', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () =>
                  ref.read(favoritesProvider.notifier).toggle(exercise.id),
              icon: Icon(
                isFavorite ? LucideIcons.star : LucideIcons.starOff,
                color: isFavorite
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const Icon(LucideIcons.chevronRight),
          ],
        ),
      ),
    );
  }
}
