import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/ui/ui_refresh_bus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

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
import '../../../core/ui/ob_tokens.dart';

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
  bool _obscurePassword = true;
  Future<OfficeSchedule>? _scheduleFuture;
  Future<CurrencyPreference>? _currencyFuture;
  bool _notificationsGranted = true;
  bool _exactAlarmGranted = true;
  bool _sendingTest = false;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = _scheduleRepository.load();
    _currencyFuture = _currencyRepository.load();
    _checkNotificationPermissions();
  }

  Future<void> _checkNotificationPermissions() async {
    final notifStatus = await Permission.notification.status;
    final exactStatus = await Permission.scheduleExactAlarm.status;
    if (!mounted) return;
    UiRefreshBus.instance.update(this, () {
      _notificationsGranted = notifStatus.isGranted;
      _exactAlarmGranted = exactStatus.isGranted;
    });
  }

  Future<void> _sendTestNotification() async {
    UiRefreshBus.instance.update(this, () => _sendingTest = true);
    try {
      await NotificationService.showBreakReminder(
        id: 999999,
        title: 'Test notification',
        body: 'Your break and hydration reminders are working.',
        payload: AppRoutes.breakScreen,
      );
    } finally {
      if (mounted) {
        UiRefreshBus.instance.update(this, () => _sendingTest = false);
      }
    }
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
    int? lunchStart = current.lunchStartMinutes;
    int? lunchEnd = current.lunchEndMinutes;

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
                  child: SingleChildScrollView(
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
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Lunch break (suppresses reminders)',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Switch(
                              value: lunchStart != null && lunchEnd != null,
                              onChanged: (enabled) {
                                setSheetState(() {
                                  if (enabled) {
                                    lunchStart = 12 * 60;
                                    lunchEnd = 13 * 60;
                                  } else {
                                    lunchStart = null;
                                    lunchEnd = null;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        if (lunchStart != null && lunchEnd != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _OfficeTimeTile(
                                  label: 'Lunch start',
                                  value: _formatTime(lunchStart!),
                                  onTap: () => _pickTime(
                                    context: sheetContext,
                                    initialMinutes: lunchStart!,
                                    onPicked: (value) {
                                      setSheetState(() => lunchStart = value);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _OfficeTimeTile(
                                  label: 'Lunch end',
                                  value: _formatTime(lunchEnd!),
                                  onTap: () => _pickTime(
                                    context: sheetContext,
                                    initialMinutes: lunchEnd!,
                                    onPicked: (value) {
                                      setSheetState(() => lunchEnd = value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(
                              OfficeSchedule(
                                workStartMinutes: startMinutes,
                                workEndMinutes: endMinutes,
                                offDays: offDays.toList()..sort(),
                                lunchStartMinutes: lunchStart,
                                lunchEndMinutes: lunchEnd,
                              ),
                            );
                          },
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ),
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
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: _AmbientBlob(
                color: ObTokens.iris.withValues(alpha: 0.18),
                size: 260,
              ),
            ),
            Positioned(
              bottom: 80,
              left: -50,
              child: _AmbientBlob(
                color: ObTokens.mint.withValues(alpha: 0.22),
                size: 220,
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: user == null
                    ? _buildSignInView(theme, auth)
                    : _buildProfileView(theme, user),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInView(ThemeData theme, dynamic auth) {
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildSignInHero(theme)
            .animate()
            .fade(duration: 400.ms)
            .slideY(begin: -0.06, end: 0),
        const SizedBox(height: 24),
        ObGlass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                icon: LucideIcons.logIn,
                label: 'Sign In',
                iconColor: ObTokens.iris,
              ),
              const SizedBox(height: 16),
              _StyledTextField(
                controller: _email,
                label: 'Email',
                icon: LucideIcons.mail,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _StyledTextField(
                controller: _password,
                label: 'Password',
                icon: LucideIcons.lock,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? LucideIcons.eyeOff
                        : LucideIcons.eye,
                    size: 18,
                    color: ObTokens.textMuted,
                  ),
                  onPressed: () => UiRefreshBus.instance.update(
                    this,
                    () => _obscurePassword = !_obscurePassword,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _PrimaryButton(
                label: _loading ? 'Signing in…' : 'Sign In',
                icon: LucideIcons.logIn,
                onPressed: _loading ? null : _login,
                color: ObTokens.iris,
              ),
              const SizedBox(height: 10),
              _GhostButton(
                label: 'Create account',
                onPressed: _loading ? null : _signup,
              ),
              if (auth == null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.alertCircle,
                      size: 14,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Firebase is not configured yet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ).animate().fade(duration: 480.ms, delay: 80.ms).slideY(
          begin: 0.06,
          end: 0,
        ),
      ],
    );
  }

  Widget _buildSignInHero(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [ObTokens.iris, ObTokens.sky],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: ObTokens.iris.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(LucideIcons.user, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        Text('Welcome Back', style: theme.textTheme.displayLarge?.copyWith(fontSize: 26)),
        const SizedBox(height: 6),
        Text(
          'Sign in to sync your health data across devices.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProfileView(ThemeData theme, User user) {
    final initials = _getInitials(user.email ?? user.uid);

    return Column(
      children: [
        const SizedBox(height: 12),
        _buildProfileHero(theme, user, initials)
            .animate()
            .fade(duration: 400.ms)
            .slideY(begin: -0.06, end: 0),
        const SizedBox(height: 20),
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
            return _SettingsCard(
              icon: LucideIcons.building2,
              title: 'Office Schedule',
              iconColor: ObTokens.mintDeep,
              children: [
                _InfoTile(
                  label: 'Work hours',
                  value:
                      '${_formatTime(schedule.workStartMinutes)} – ${_formatTime(schedule.workEndMinutes)}',
                  icon: LucideIcons.clock,
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  label: 'Days off',
                  value: _formatOffDays(schedule.offDays),
                  icon: LucideIcons.calendarOff,
                ),
                if (schedule.lunchStartMinutes != null &&
                    schedule.lunchEndMinutes != null) ...[
                  const SizedBox(height: 8),
                  _InfoTile(
                    label: 'Lunch break',
                    value:
                        '${_formatTime(schedule.lunchStartMinutes!)} – ${_formatTime(schedule.lunchEndMinutes!)}',
                    icon: LucideIcons.utensils,
                  ),
                ],
                const SizedBox(height: 16),
                _PrimaryButton(
                  label: 'Edit Schedule',
                  icon: LucideIcons.pencil,
                  onPressed: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : () => _editOfficeSchedule(schedule),
                  color: ObTokens.mintDeep,
                ),
              ],
            );
          },
        ).animate().fade(duration: 400.ms, delay: 60.ms).slideY(
          begin: 0.06,
          end: 0,
        ),
        const SizedBox(height: 14),
        _buildNotificationsCard(theme)
            .animate()
            .fade(duration: 400.ms, delay: 90.ms)
            .slideY(begin: 0.06, end: 0),
        const SizedBox(height: 14),
        FutureBuilder<CurrencyPreference>(
          future: _currencyFuture,
          builder: (context, snapshot) {
            final currency =
                snapshot.data ?? CurrencyPreference.defaultPreference;
            return _SettingsCard(
              icon: LucideIcons.badgeDollarSign,
              title: 'Currency',
              iconColor: ObTokens.sky,
              children: [
                _InfoTile(
                  label: 'Selected',
                  value: '${currency.displayLabel}  ${currency.name}',
                  icon: LucideIcons.coins,
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  label: 'Code',
                  value: currency.code,
                  icon: LucideIcons.tag,
                ),
                const SizedBox(height: 16),
                _PrimaryButton(
                  label: 'Change Currency',
                  icon: LucideIcons.pencil,
                  onPressed: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : () => _editCurrencyPreference(currency),
                  color: ObTokens.sky,
                ),
              ],
            );
          },
        ).animate().fade(duration: 400.ms, delay: 120.ms).slideY(
          begin: 0.06,
          end: 0,
        ),
        const SizedBox(height: 24),
        ObGlass(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _DangerButton(
            label: _loading ? 'Signing out…' : 'Sign Out',
            icon: LucideIcons.logOut,
            onPressed: _loading ? null : _logout,
          ),
        ).animate().fade(duration: 400.ms, delay: 180.ms),
      ],
    );
  }

  Widget _buildNotificationsCard(ThemeData theme) {
    final hasProblem = !_notificationsGranted || !_exactAlarmGranted;
    return _SettingsCard(
      icon: LucideIcons.bell,
      title: 'Notifications',
      iconColor: ObTokens.iris,
      children: [
        if (hasProblem) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.alertTriangle,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    !_notificationsGranted
                        ? 'Notification permission is off. Reminders won\'t show.'
                        : 'Exact alarms disabled. Hydration reminders may be delayed.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _PrimaryButton(
            label: 'Open Notification Settings',
            icon: LucideIcons.settings,
            onPressed: () => openAppSettings(),
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 8),
        ] else ...[
          _InfoTile(
            label: 'Status',
            value: 'Active',
            icon: LucideIcons.checkCircle,
          ),
          const SizedBox(height: 8),
        ],
        _PrimaryButton(
          label: _sendingTest ? 'Sending…' : 'Send Test Notification',
          icon: LucideIcons.bellRing,
          onPressed: _sendingTest ? null : _sendTestNotification,
          color: ObTokens.iris,
        ),
      ],
    );
  }

  Widget _buildProfileHero(ThemeData theme, User user, String initials) {
    return ObGlass(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [ObTokens.mintDeep, ObTokens.iris],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: ObTokens.iris.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signed in', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  user.email ?? user.uid,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ObTokens.mintDeep.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ObTokens.mintDeep.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.checkCircle,
                  size: 12,
                  color: ObTokens.mintDeep,
                ),
                const SizedBox(width: 4),
                Text(
                  'Active',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ObTokens.mintDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String emailOrUid) {
    final parts = emailOrUid.split('@').first.split(RegExp(r'[._\-]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return emailOrUid.substring(0, emailOrUid.length.clamp(0, 2)).toUpperCase();
  }
}

class _AmbientBlob extends StatelessWidget {
  const _AmbientBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.titleLarge),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.children,
  });

  final IconData icon;
  final String title;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ObGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(icon: icon, label: title, iconColor: iconColor),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ObTokens.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: ObTokens.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: ObTokens.iris,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: ObTokens.iris.withValues(alpha: 0.35)),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const dangerColor = Color(0xFFE53935);
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: dangerColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: dangerColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: dangerColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ObTokens.iris, width: 1.5),
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

const Map<int, String> _weekdayLabels = <int, String>{
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};
