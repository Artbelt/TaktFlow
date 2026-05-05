import 'package:flutter/material.dart';

import '../database/app_database.dart';

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({super.key, this.templateId});

  /// null — создание нового шаблона.
  final int? templateId;

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _db = AppDatabase.instance;
  final _nameCtrl = TextEditingController();
  final List<TextEditingController> _opCtrls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.templateId;
    if (id == null) {
      setState(() {
        _loading = false;
        _opCtrls.add(TextEditingController(text: 'Взять заготовку'));
        _opCtrls.add(TextEditingController(text: 'Установить'));
        _opCtrls.add(TextEditingController(text: 'Закрутить'));
        _opCtrls.add(TextEditingController(text: 'Проверить'));
        _opCtrls.add(TextEditingController(text: 'Уложить'));
      });
      return;
    }
    final t = await _db.getTemplate(id);
    final ops = await _db.getOperations(id);
    if (!mounted) return;
    if (t == null) {
      Navigator.pop(context);
      return;
    }
    _nameCtrl.text = t.name;
    for (final o in ops) {
      _opCtrls.add(TextEditingController(text: o.name));
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _opCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOperation() {
    setState(() => _opCtrls.add(TextEditingController()));
  }

  void _removeAt(int i) {
    setState(() {
      _opCtrls.removeAt(i).dispose();
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название шаблона')),
      );
      return;
    }
    final names = _opCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одну операцию')),
      );
      return;
    }

    final id = widget.templateId;
    if (id == null) {
      final newId = await _db.insertTemplate(name, DateTime.now());
      await _db.replaceOperations(newId, names);
    } else {
      await _db.updateTemplate(id, name);
      await _db.replaceOperations(id, names);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.templateId == null ? 'Новый шаблон' : 'Редактирование'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название шаблона',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Операции (удерживайте за ⋮⋮ для перетаскивания)', style: TextStyle(fontSize: 14)),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: _opCtrls.length,
              onReorder: (oldI, newI) {
                setState(() {
                  if (newI > oldI) newI -= 1;
                  final c = _opCtrls.removeAt(oldI);
                  _opCtrls.insert(newI, c);
                });
              },
              itemBuilder: (context, index) {
                final c = _opCtrls[index];
                return Card(
                  key: ValueKey(c),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.drag_handle),
                    title: TextField(
                      controller: c,
                      decoration: const InputDecoration(border: InputBorder.none, hintText: 'Название операции'),
                      style: const TextStyle(fontSize: 18),
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 3,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _removeAt(index),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addOperation,
        child: const Icon(Icons.add),
      ),
    );
  }
}
