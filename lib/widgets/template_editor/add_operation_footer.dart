import 'package:flutter/material.dart';

/// Основная кнопка добавления строки операции под списком.
class AddOperationFooter extends StatelessWidget {
  const AddOperationFooter({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                alignment: Alignment.center,
                foregroundColor: scheme.primary,
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              onPressed: onPressed,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Добавить операцию'),
            ),
          ),
        ),
      ),
    );
  }
}
