import 'package:flutter/material.dart';

/// Диалог: вставка нескольких операций с разбиением по строкам.
Future<List<String>?> showPasteOperationsDialog(BuildContext context) async {
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => const _PasteOperationsDialog(),
  );
}

class _PasteOperationsDialog extends StatefulWidget {
  const _PasteOperationsDialog();

  @override
  State<_PasteOperationsDialog> createState() => _PasteOperationsDialogState();
}

class _PasteOperationsDialogState extends State<_PasteOperationsDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Вставить список операций'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.multiline,
          maxLines: 12,
          minLines: 6,
          decoration: const InputDecoration(
            hintText: 'Одна операция на строку',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            final lines = _ctrl.text.split(RegExp('\r?\n'));
            final out = lines.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            Navigator.pop(context, out);
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
