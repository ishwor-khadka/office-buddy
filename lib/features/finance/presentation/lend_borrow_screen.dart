import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/finance/finance_repository.dart';
import '../../../core/settings/currency_preference.dart';
import '../../../core/settings/currency_preference_repository.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';

class LendBorrowScreen extends StatefulWidget {
  const LendBorrowScreen({super.key});

  @override
  State<LendBorrowScreen> createState() => _LendBorrowScreenState();
}

class _LendBorrowScreenState extends State<LendBorrowScreen> {
  final FinanceRepository _repository = FinanceRepository();
  final CurrencyPreferenceRepository _currencyRepository =
      CurrencyPreferenceRepository();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  final ValueNotifier<int> _refreshTick = ValueNotifier<int>(0);
  int _selectedTab = 0;
  bool _saving = false;
  Future<CurrencyPreference>? _currencyFuture;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _amountController = TextEditingController(text: '100');
    _currencyFuture = _currencyRepository.load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _refreshTick.dispose();
    super.dispose();
  }

  void _refresh(VoidCallback update) {
    if (!mounted) return;
    update();
    _refreshTick.value++;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _refreshTick,
      builder: (context, _, child) {
        return FutureBuilder<CurrencyPreference>(
          future: _currencyFuture,
          builder: (context, snapshot) {
            final currency =
                snapshot.data ?? CurrencyPreference.defaultPreference;
            final navigator = Navigator.of(context);
            final theme = Theme.of(context);
            final isBorrowed = _selectedTab == 0;
            final enteredName = _nameController.text.trim();
            final noteName = enteredName.isEmpty ? 'the person' : enteredName;
            final note = isBorrowed
                ? 'You borrowed money from $noteName'
                : '$noteName borrowed money from you';
            final accentColor = isBorrowed
                ? const Color(0xFFE71D3D)
                : const Color(0xFF0BA24D);

            return Scaffold(
              extendBodyBehindAppBar: true,
              body: ObBackground(
                child: Stack(
                  children: [
                    Positioned(
                      top: -60,
                      right: -40,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ObTokens.iris.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 80,
                      left: -50,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ObTokens.mintDeep.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(context),
                                const SizedBox(height: 20),
                                _buildTabBar(theme, isBorrowed),
                                const SizedBox(height: 20),
                                _buildAvatarHero(theme, isBorrowed, accentColor),
                                const SizedBox(height: 16),
                                ObGlass(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _InputField(
                                        label: "Person's Name",
                                        icon: LucideIcons.user,
                                        child: TextField(
                                          controller: _nameController,
                                          onChanged: (_) => _refresh(() {}),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                color: ObTokens.text,
                                                fontWeight: FontWeight.w600,
                                              ),
                                          decoration: const InputDecoration(
                                            hintText: 'Enter name',
                                            isDense: true,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      Divider(
                                        height: 24,
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                      _InputField(
                                        label: 'Amount',
                                        icon: LucideIcons.banknote,
                                        child: TextField(
                                          controller: _amountController,
                                          keyboardType: TextInputType.number,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                color: ObTokens.text,
                                                fontWeight: FontWeight.w600,
                                              ),
                                          decoration: InputDecoration(
                                            prefixText: '${currency.symbol} ',
                                            prefixStyle: TextStyle(
                                              color: ObTokens.textMuted,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                            ),
                                            isDense: true,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ObGlass(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        LucideIcons.info,
                                        size: 15,
                                        color: ObTokens.textMuted,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          note,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: ObTokens.textMuted,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildSaveButton(
                                  theme,
                                  navigator,
                                  isBorrowed,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            ),
            child: const Icon(
              LucideIcons.arrowLeft,
              color: ObTokens.text,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [ObTokens.iris, ObTokens.mintDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(LucideIcons.users, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          'Add Borrow / Lend',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: ObTokens.text,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(ThemeData theme, bool isBorrowed) {
    return ObGlass(
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          Expanded(
            child: _ModeTab(
              label: 'Borrowed',
              sublabel: 'You owe',
              selected: isBorrowed,
              selectedColor: const Color(0xFFE71D3D),
              onTap: () => _refresh(() => _selectedTab = 0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ModeTab(
              label: 'Lent',
              sublabel: 'They owe',
              selected: !isBorrowed,
              selectedColor: const Color(0xFF0BA24D),
              onTap: () => _refresh(() => _selectedTab = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarHero(
    ThemeData theme,
    bool isBorrowed,
    Color accentColor,
  ) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isBorrowed
                ? [const Color(0xFFFF6B6B), const Color(0xFFE71D3D)]
                : [ObTokens.mintDeep, const Color(0xFF0BA24D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.32),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            LucideIcons.user,
            color: Colors.white,
            size: 38,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(
    ThemeData theme,
    NavigatorState navigator,
    bool isBorrowed,
  ) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _saving
            ? null
            : () async {
                _refresh(() => _saving = true);
                try {
                  await _repository.addBorrowLend(
                    name: _nameController.text,
                    amount: _amountController.text,
                    isOwed: _selectedTab == 0,
                  );
                  if (!mounted) return;
                  navigator.pop(true);
                } finally {
                  if (mounted) _refresh(() => _saving = false);
                }
              },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _saving
                ? null
                : const LinearGradient(
                    colors: [ObTokens.iris, ObTokens.mintDeep],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: _saving ? Colors.white.withValues(alpha: 0.4) : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.check,
                  size: 18,
                  color: _saving ? ObTokens.textMuted : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _saving ? 'Saving…' : 'Save Transaction',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _saving ? ObTokens.textMuted : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: ObTokens.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: ObTokens.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? selectedColor.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: selected ? selectedColor : ObTokens.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                sublabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selected
                      ? selectedColor.withValues(alpha: 0.7)
                      : ObTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
