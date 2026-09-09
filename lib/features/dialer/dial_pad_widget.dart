import 'package:flutter/material.dart';

/// 3x4 dial pad. `onLongPressZero` types `+`, matching every native dialer.
class DialPadWidget extends StatelessWidget {
  const DialPadWidget({super.key, required this.onKey});

  final void Function(String key) onKey;

  static const List<({String digit, String letters})> _keys = [
    (digit: '1', letters: ''),
    (digit: '2', letters: 'ABC'),
    (digit: '3', letters: 'DEF'),
    (digit: '4', letters: 'GHI'),
    (digit: '5', letters: 'JKL'),
    (digit: '6', letters: 'MNO'),
    (digit: '7', letters: 'PQRS'),
    (digit: '8', letters: 'TUV'),
    (digit: '9', letters: 'WXYZ'),
    (digit: '*', letters: ''),
    (digit: '0', letters: '+'),
    (digit: '#', letters: ''),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.5,
      children: [
        for (final key in _keys)
          _DialKey(
            digit: key.digit,
            letters: key.letters,
            onTap: () => onKey(key.digit),
            onLongPress: key.digit == '0' ? () => onKey('+') : null,
          ),
      ],
    );
  }
}

class _DialKey extends StatelessWidget {
  const _DialKey({
    required this.digit,
    required this.letters,
    required this.onTap,
    this.onLongPress,
  });

  final String digit;
  final String letters;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return InkResponse(
      onTap: onTap,
      onLongPress: onLongPress,
      radius: 44,
      child: Semantics(
        button: true,
        label: digit,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(digit, style: texts.headlineSmall),
            if (letters.isNotEmpty)
              Text(
                letters,
                style: texts.labelSmall?.copyWith(letterSpacing: 1.5),
              ),
          ],
        ),
      ),
    );
  }
}
