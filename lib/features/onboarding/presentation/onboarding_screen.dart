import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/settings/currency_preference.dart';
import '../../../core/settings/currency_preference_repository.dart';
import '../../../core/settings/office_schedule.dart';
import '../../../core/settings/office_schedule_repository.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _kOnboarded = 'onboarded_v1';
  final OfficeScheduleRepository _repository = OfficeScheduleRepository();
  final CurrencyPreferenceRepository _currencyRepository =
      CurrencyPreferenceRepository();
  final ValueNotifier<int> _refreshTick = ValueNotifier<int>(0);

  int _workStartMinutes = 9 * 60;
  int _workEndMinutes = 18 * 60;
  final Set<int> _offDays = <int>{DateTime.saturday, DateTime.sunday};
  CurrencyPreference? _selectedCurrency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _refreshTick.dispose();
    super.dispose();
  }

  void _refresh(VoidCallback update) {
    if (!mounted) return;
    update();
    _refreshTick.value++;
  }

  Future<void> _loadExisting() async {
    final scheduleFuture = _repository.load();
    final currencyFuture = _currencyRepository.loadLocal();
    final schedule = await scheduleFuture;
    final currency = await currencyFuture;
    if (!mounted) return;
    _refresh(() {
      _workStartMinutes = schedule.workStartMinutes;
      _workEndMinutes = schedule.workEndMinutes;
      _offDays
        ..clear()
        ..addAll(schedule.offDays);
      _selectedCurrency = currency == null
          ? null
          : currencyPreferenceForCode(currency.code);
    });
  }

  String _fmtTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime({required bool start}) async {
    final initial = TimeOfDay(
      hour: (start ? _workStartMinutes : _workEndMinutes) ~/ 60,
      minute: (start ? _workStartMinutes : _workEndMinutes) % 60,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    _refresh(() {
      if (start) {
        _workStartMinutes = minutes;
      } else {
        _workEndMinutes = minutes;
      }
    });
  }

  void _toggleOffDay(int weekday) {
    _refresh(() {
      if (!_offDays.add(weekday)) {
        _offDays.remove(weekday);
      }
    });
  }

  Future<void> _pickCurrency() async {
    var query = '';
    var selected = _selectedCurrency;

    final result = await showModalBottomSheet<CurrencyPreference>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredOptions = supportedCurrencyPreferences
                .where((option) {
                  if (query.trim().isEmpty) return true;
                  final q = query.toLowerCase();
                  return option.name.toLowerCase().contains(q) ||
                      option.code.toLowerCase().contains(q) ||
                      option.symbol.toLowerCase().contains(q);
                })
                .toList(growable: false);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                  top: 20,
                ),
                child: ObGlass(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Choose Currency',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (value) {
                          setSheetState(() => query = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search currency, code, or symbol',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.45),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredOptions.length,
                          itemBuilder: (context, index) {
                            final option = filteredOptions[index];
                            final isSelected = selected?.code == option.code;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              title: Text(option.name),
                              subtitle: Text(option.code),
                              trailing: Text(option.symbol),
                              selected: isSelected,
                              onTap: () {
                                setSheetState(() => selected = option);
                                Navigator.of(sheetContext).pop(option);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    _refresh(() => _selectedCurrency = result);
  }

  Future<void> _finish() async {
    final selectedCurrency = _selectedCurrency;
    if (selectedCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a currency.')),
      );
      return;
    }

    _refresh(() => _saving = true);
    final schedule = OfficeSchedule(
      workStartMinutes: _workStartMinutes,
      workEndMinutes: _workEndMinutes,
      offDays: _offDays.toList()..sort(),
    );
    try {
      final scheduleSynced = await _repository.save(schedule);
      await NotificationService.rescheduleHydrationReminders(
        schedule: schedule,
      );
      final currencySynced = await _currencyRepository.save(selectedCurrency);
      final synced = scheduleSynced && currencySynced;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOnboarded, true);

      if (!synced && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally. Cloud sync will retry later.'),
          ),
        );
      }
      if (!mounted) return;
      context.go(AppRoutes.homeScreen);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save office timing: $error')),
      );
    } finally {
      if (mounted) {
        _refresh(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _refreshTick,
      builder: (context, _, child) {
        final theme = Theme.of(context);
        return Scaffold(
          body: ObBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Welcome to Office Buddy',
                      style: theme.textTheme.displayLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set your office start time, end time, and off days. You can change this later.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            ObGlass(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Work hours',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _TimePill(
                                          label: 'Start',
                                          value: _fmtTime(_workStartMinutes),
                                          onTap: () => _pickTime(start: true),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _TimePill(
                                          label: 'End',
                                          value: _fmtTime(_workEndMinutes),
                                          onTap: () => _pickTime(start: false),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            ObGlass(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Off days',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Select the days you do not work.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: _weekdayLabels.entries.map((
                                      entry,
                                    ) {
                                      final isSelected = _offDays.contains(
                                        entry.key,
                                      );
                                      return FilterChip(
                                        label: Text(entry.value),
                                        selected: isSelected,
                                        onSelected: (_) =>
                                            _toggleOffDay(entry.key),
                                        showCheckmark: false,
                                        selectedColor: ObTokens.mint.withValues(
                                          alpha: 0.34,
                                        ),
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.32),
                                        labelStyle: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          side: BorderSide(
                                            color: isSelected
                                                ? ObTokens.mint
                                                : Colors.white.withValues(
                                                    alpha: 0.35,
                                                  ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            ObGlass(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Currency',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Choose your default currency for finance tracking.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: _pickCurrency,
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.44,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _selectedCurrency == null
                                                  ? 'Please select currency'
                                                  : '${_selectedCurrency!.name} (${_selectedCurrency!.displayLabel})',
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodyLarge,
                                            ),
                                          ),
                                          const Icon(Icons.expand_more),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _saving ? null : _finish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ObTokens.mint,
                        foregroundColor: ObTokens.text,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(_saving ? 'Saving...' : 'Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

const Map<int, String> _weekdayLabels = <int, String>{
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.35),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
