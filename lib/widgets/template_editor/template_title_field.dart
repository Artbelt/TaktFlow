import 'package:flutter/material.dart';

/// Крупное поле названия шаблона (визуальная иерархия над операциями).
class TemplateTitleField extends StatelessWidget {
  const TemplateTitleField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: TextField(
        controller: controller,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
        textCapitalization: TextCapitalization.sentences,
        minLines: 1,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: 'Название шаблона',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurfaceVariant),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}
