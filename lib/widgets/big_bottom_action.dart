import 'package:flutter/material.dart';

/// Широкая нижняя кнопка под большой палец.
class BigBottomAction extends StatelessWidget {
  const BigBottomAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.color,
    this.foregroundColor,
    this.labelKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color? color;
  final Color? foregroundColor;
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: SizedBox(
          width: double.infinity,
          height: 72,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color ?? scheme.primary,
              foregroundColor: foregroundColor ?? scheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            onPressed: enabled ? onPressed : null,
            child: Text(
              label,
              key: labelKey,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
