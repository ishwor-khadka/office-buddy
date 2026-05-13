import 'package:flutter/material.dart';

class WordCard extends StatelessWidget {
  final String word;
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const WordCard({
    Key? key,
    required this.word,
    required this.label,
    this.backgroundColor = const Color(0xFFFFF3E0),
    this.textColor = const Color(0xFF8B4513),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF999999),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            word,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}

class LetterCard extends StatelessWidget {
  final String letter;
  final int stepNumber;
  final bool isCurrentStep;

  const LetterCard({
    Key? key,
    required this.letter,
    required this.stepNumber,
    this.isCurrentStep = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (stepNumber >= 0)
          Text(
            stepNumber.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
            ),
          ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 50,
          decoration: BoxDecoration(
            color: isCurrentStep ? Color(0xFFE8F5E9) : Color(0xFFF5F5F5),
            border: Border.all(
              color: isCurrentStep ? Color(0xFF4CAF50) : Color(0xFFDDDDDD),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ChainDisplay extends StatelessWidget {
  final List<String> chain;
  final int currentStepIndex;

  const ChainDisplay({
    Key? key,
    required this.chain,
    this.currentStepIndex = -1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First word display
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (chain.isNotEmpty)
                for (int i = 0; i < chain.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Text(
                          i.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          chain[i],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatsDisplay extends StatelessWidget {
  final int currentSteps;
  final int optimalSteps;
  final int bestSteps;
  final int streak;
  final bool isWon;

  const StatsDisplay({
    Key? key,
    required this.currentSteps,
    required this.optimalSteps,
    required this.bestSteps,
    required this.streak,
    this.isWon = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFEEEEEE)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'STEPS',
            value: currentSteps.toString(),
            subLabel: optimalSteps > 0 ? 'Optimal: $optimalSteps' : '',
          ),
          _StatItem(
            label: 'BEST',
            value: bestSteps == 999 ? '-' : bestSteps.toString(),
          ),
          _StatItem(label: 'STREAK', value: streak.toString()),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String subLabel;

  const _StatItem({
    required this.label,
    required this.value,
    this.subLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF999999),
            letterSpacing: 0.5,
          ),
        ),
        if (subLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subLabel,
              style: TextStyle(fontSize: 9, color: Color(0xFFCCCCCC)),
            ),
          ),
      ],
    );
  }
}

class InputField extends StatefulWidget {
  final Function(String) onSubmit;
  final String? errorMessage;
  final VoidCallback onClear;
  final int expectedLength;

  const InputField({
    Key? key,
    required this.onSubmit,
    this.errorMessage,
    required this.onClear,
    required this.expectedLength,
  }) : super(key: key);

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didUpdateWidget(InputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != null &&
        widget.errorMessage != oldWidget.errorMessage) {
      // Show error feedback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'Type word...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.errorMessage != null
                    ? Color(0xFFE53935)
                    : Color(0xFFDDDDDD),
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.errorMessage != null
                    ? Color(0xFFE53935)
                    : Color(0xFFDDDDDD),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      widget.onClear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() {});
          },
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              widget.onSubmit(value);
              _controller.clear();
              setState(() {});
            }
          },
        ),
        if (widget.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.errorMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _controller.text.isEmpty
                ? null
                : () {
                    widget.onSubmit(_controller.text);
                    _controller.clear();
                    setState(() {});
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4CAF50),
              disabledBackgroundColor: Color(0xFFCCCCCC),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'SUBMIT',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
