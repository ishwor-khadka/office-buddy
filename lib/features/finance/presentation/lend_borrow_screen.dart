import 'package:flutter/material.dart';
import '../../../core/ui/ui_refresh_bus.dart';

import '../../../core/finance/finance_repository.dart';
import '../../../core/settings/currency_preference.dart';
import '../../../core/settings/currency_preference_repository.dart';
import '../../../core/ui/ob_background.dart';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CurrencyPreference>(
      future: _currencyFuture,
      builder: (context, snapshot) {
        final currency = snapshot.data ?? CurrencyPreference.defaultPreference;
        final navigator = Navigator.of(context);
        final theme = Theme.of(context);
        final isBorrowed = _selectedTab == 0;
        final enteredName = _nameController.text.trim();
        final noteName = enteredName.isEmpty ? 'the person' : enteredName;
        final note = isBorrowed
            ? 'You borrowed money from $noteName'
            : '$noteName borrowed money from you';

        return Scaffold(
          backgroundColor: const Color(0xFFF1F1F1),
          body: ObBackground(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF5BADE7),
                            Color(0xFF8B7AF6),
                            Color(0xFF68C9AE),
                          ],
                          stops: [0.0, 0.56, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Add Borrow/Lend',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ModeTab(
                                      label: 'Borrowed (You owe)',
                                      selected: isBorrowed,
                                      onTap: () =>
                                          UiRefreshBus.instance.update(this, () => _selectedTab = 0),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _ModeTab(
                                      label: 'Lent (They owe)',
                                      selected: !isBorrowed,
                                      onTap: () =>
                                          UiRefreshBus.instance.update(this, () => _selectedTab = 1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF52BF9B),
                                ),
                                child: const Center(
                                  child: Text(
                                    '👱',
                                    style: TextStyle(fontSize: 42),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                18,
                                18,
                                14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Person's Name",
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: const Color(0xFF6C7487),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  TextField(
                                    controller: _nameController,
                                    onChanged: (_) => UiRefreshBus.instance.update(this, () {}),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: const Color(0xFF1C2233),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const Divider(height: 18),
                                  Text(
                                    'Amount',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: const Color(0xFF6C7487),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  TextField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: const Color(0xFF1C2233),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      prefixText: '${currency.symbol} ',
                                      prefixStyle: const TextStyle(
                                        color: Color(0xFF8F97A8),
                                        fontSize: 28,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      isDense: true,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                note,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      UiRefreshBus.instance.update(this, () => _saving = true);
                                      try {
                                        await _repository.addBorrowLend(
                                          name: _nameController.text,
                                          amount: _amountController.text,
                                          isOwed: _selectedTab == 0,
                                        );
                                        if (!mounted) return;
                                        navigator.pop(true);
                                      } finally {
                                        if (mounted) {
                                          UiRefreshBus.instance.update(this, () => _saving = false);
                                        }
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF10182A),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(
                                _saving ? 'Saving...' : 'Save Transaction',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF10182A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected
                  ? const Color(0xFF1E2434)
                  : Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
