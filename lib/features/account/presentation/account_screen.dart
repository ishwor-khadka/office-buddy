import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/ui/ui_refresh_bus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/notifications/fcm_token_service.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/permissions/post_login_permission_service.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/settings/currency_preference.dart';
import '../../../core/settings/currency_preference_repository.dart';
import '../../../core/settings/office_schedule.dart';
import '../../../core/settings/office_schedule_repository.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _scheduleRepository = OfficeScheduleRepository();
  final _currencyRepository = CurrencyPreferenceRepository();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  Future<OfficeSchedule>? _scheduleFuture;
  Future<CurrencyPreference>? _currencyFuture;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = _scheduleRepository.load();
    _currencyFuture = _currencyRepository.load();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    UiRefreshBus.instance.update(this, () => _loading = true);
    try {
      final auth = FirebaseBootstrap.authOrNull;
      if (auth == null) {
        throw StateError('Firebase is not configured.');
      }
      await auth.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      unawaited(FcmTokenService.registerCurrentUserToken());
      final routedToPermissions = await _routeToPermissionsIfNeeded();
      if (routedToPermissions) return;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login failed')));
    } finally {
      if (mounted) UiRefreshBus.instance.update(this, () => _loading = false);
    }
  }

  Future<void> _signup() async {
    UiRefreshBus.instance.update(this, () => _loading = true);
    try {
      final auth = FirebaseBootstrap.authOrNull;
      if (auth == null) {
        throw StateError('Firebase is not configured.');
      }
      await auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      unawaited(FcmTokenService.registerCurrentUserToken());
      final routedToPermissions = await _routeToPermissionsIfNeeded();
      if (routedToPermissions) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created. Check email if verification is enabled.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Signup failed')));
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signup failed')));
    } finally {
      if (mounted) UiRefreshBus.instance.update(this, () => _loading = false);
    }
  }

  Future<void> _logout() async {
    UiRefreshBus.instance.update(this, () => _loading = true);
    try {
      final auth = FirebaseBootstrap.authOrNull;
      if (auth == null) return;
      await FcmTokenService.deleteCurrentUserToken();
      await auth.signOut();
    } finally {
      if (mounted) UiRefreshBus.instance.update(this, () => _loading = false);
    }
  }

  Future<bool> _routeToPermissionsIfNeeded() async {
    final hasCompletedPermissions =
        await PostLoginPermissionService.hasCompletedForCurrentUser();
    if (!mounted || hasCompletedPermissions) return false;
    context.go(AppRoutes.permissionOnboardingScreen);
    return true;
  }

  String _formatTime(int minutes) {
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final mins = (minutes % 60).toString().padLeft(2, '0');
    return '$hours:$mins';
  }

  String _formatOffDays(List<int> offDays) {
    if (offDays.isEmpty) return 'None selected';
    const labels = <int, String>{
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };
    return offDays.map((day) => labels[day] ?? day.toString()).join(', ');
  }

  Future<void> _pickTime({
    required BuildContext context,
    required int initialMinutes,
    required ValueChanged<int> onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialMinutes ~/ 60,
        minute: initialMinutes % 60,
      ),
    );
    if (picked == null) return;
    onPicked(picked.hour * 60 + picked.minute);
  }

  Future<void> _editOfficeSchedule(OfficeSchedule current) async {
    var startMinutes = current.workStartMinutes;
    var endMinutes = current.workEndMinutes;
    final offDays = current.offDays.toSet();

    final result = await showModalBottomSheet<OfficeSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                              'Update Office Timing',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _OfficeTimeTile(
                              label: 'Start',
                              value: _formatTime(startMinutes),
                              onTap: () => _pickTime(
                                context: sheetContext,
                                initialMinutes: startMinutes,
                                onPicked: (value) {
                                  setSheetState(() => startMinutes = value);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _OfficeTimeTile(
                              label: 'End',
                              value: _formatTime(endMinutes),
                              onTap: () => _pickTime(
                                context: sheetContext,
                                initialMinutes: endMinutes,
                                onPicked: (value) {
                                  setSheetState(() => endMinutes = value);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Off days',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _weekdayLabels.entries.map((entry) {
                          final selected = offDays.contains(entry.key);
                          return FilterChip(
                            label: Text(entry.value),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: (_) {
                              setSheetState(() {
                                if (!offDays.add(entry.key)) {
                                  offDays.remove(entry.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop(
                            OfficeSchedule(
                              workStartMinutes: startMinutes,
                              workEndMinutes: endMinutes,
                              offDays: offDays.toList()..sort(),
                            ),
                          );
                        },
                        child: const Text('Save Changes'),
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

    if (result == null) return;
    await _scheduleRepository.save(result);
    await NotificationService.rescheduleHydrationReminders(schedule: result);
    if (!mounted) return;
    UiRefreshBus.instance.update(this, () {
      _scheduleFuture = Future.value(result);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Office timing updated')));
  }

  Future<void> _editCurrencyPreference(CurrencyPreference current) async {
    var query = '';
    var selected = current;

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
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.45,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredOptions.length,
                          itemBuilder: (context, index) {
                            final option = filteredOptions[index];
                            final isSelected = selected.code == option.code;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              title: Text(option.name),
                              subtitle: Text(option.code),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(option.symbol),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle, size: 18),
                                  ],
                                ],
                              ),
                              onTap: () {
                                setSheetState(() => selected = option);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(selected),
                        child: const Text('Save Currency'),
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

    if (result == null) return;
    final savedToCloud = await _currencyRepository.save(result);
    if (!mounted) return;
    UiRefreshBus.instance.update(this, () {
      _currencyFuture = Future.value(result);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedToCloud
              ? 'Currency updated'
              : 'Currency updated locally. Cloud sync will retry later.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = FirebaseBootstrap.authOrNull;
    final user = auth?.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Profile')),
      body: ObBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ObGlass(
              child: SingleChildScrollView(
                child: user == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Sign in to sync',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your health logs stay on-device unless you sign in.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: Text(_loading ? 'Loading...' : 'Login'),
                          ),
                          TextButton(
                            onPressed: _loading ? null : _signup,
                            child: const Text('Create account'),
                          ),
                          if (auth == null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Firebase is not configured yet.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Signed in', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            user.email ?? user.uid,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          FutureBuilder<OfficeSchedule>(
                            future: _scheduleFuture,
                            builder: (context, snapshot) {
                              final schedule =
                                  snapshot.data ??
                                  const OfficeSchedule(
                                    workStartMinutes: 9 * 60,
                                    workEndMinutes: 18 * 60,
                                    offDays: <int>[6, 7],
                                  );

                              return ObGlass(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Office Timing',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    _InfoRow(
                                      label: 'Start time',
                                      value: _formatTime(
                                        schedule.workStartMinutes,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                      label: 'End time',
                                      value: _formatTime(
                                        schedule.workEndMinutes,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                      label: 'Off days',
                                      value: _formatOffDays(schedule.offDays),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed:
                                          snapshot.connectionState ==
                                              ConnectionState.waiting
                                          ? null
                                          : () => _editOfficeSchedule(schedule),
                                      child: const Text('Update Office Timing'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          FutureBuilder<CurrencyPreference>(
                            future: _currencyFuture,
                            builder: (context, snapshot) {
                              final currency =
                                  snapshot.data ??
                                  CurrencyPreference.defaultPreference;

                              return ObGlass(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Currency',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    _InfoRow(
                                      label: 'Selected',
                                      value:
                                          '${currency.displayLabel} - ${currency.name}',
                                    ),
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                      label: 'Code',
                                      value: currency.code,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed:
                                          snapshot.connectionState ==
                                              ConnectionState.waiting
                                          ? null
                                          : () => _editCurrencyPreference(
                                              currency,
                                            ),
                                      child: const Text('Update Currency'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loading ? null : _logout,
                            child: Text(_loading ? 'Loading...' : 'Sign out'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfficeTimeTile extends StatelessWidget {
  const _OfficeTimeTile({
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
