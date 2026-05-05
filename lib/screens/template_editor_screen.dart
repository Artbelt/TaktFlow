import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/app_database.dart';
import '../widgets/template_editor/add_operation_footer.dart';
import '../widgets/template_editor/operation_item_card.dart';
import '../widgets/template_editor/paste_operations_dialog.dart';
import '../widgets/template_editor/template_title_field.dart';

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
  final List<FocusNode> _opFocus = [];
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
        for (final preset in ['Взять заготовку', 'Установить', 'Закрутить', 'Проверить', 'Уложить']) {
          _pushRow(TextEditingController(text: preset));
        }
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
      _pushRow(TextEditingController(text: o.name));
    }
    setState(() => _loading = false);
  }

  void _pushRow(TextEditingController c) {
    _opCtrls.add(c);
    _opFocus.add(FocusNode());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _opCtrls) {
      c.dispose();
    }
    for (final f in _opFocus) {
      f.dispose();
    }
    super.dispose();
  }

  void _addOperation({required bool autofocus}) {
    HapticFeedback.lightImpact();
    setState(() {
      _pushRow(TextEditingController());
    });
    if (autofocus) {
      final i = _opCtrls.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_opFocus[i]);
        final t = _opCtrls[i].text;
        _opCtrls[i].selection = TextSelection.collapsed(offset: t.length);
      });
    }
  }

  Future<void> _pasteList() async {
    final lines = await showPasteOperationsDialog(context);
    if (lines == null || lines.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      for (final line in lines) {
        _pushRow(TextEditingController(text: line));
      }
    });
  }

  void _removeRowAt(int index) {
    setState(() {
      _opCtrls[index].dispose();
      _opFocus[index].dispose();
      _opCtrls.removeAt(index);
      _opFocus.removeAt(index);
    });
  }

  void _onReorder(int oldI, int newI) {
    HapticFeedback.selectionClick();
    setState(() {
      if (newI > oldI) newI -= 1;
      final c = _opCtrls.removeAt(oldI);
      _opCtrls.insert(newI, c);
      final f = _opFocus.removeAt(oldI);
      _opFocus.insert(newI, f);
    });
  }

  void _onSubmitRow(TextEditingController c) {
    final index = _opCtrls.indexOf(c);
    if (index < 0) return;
    final text = c.text.trim();
    if (text.isEmpty) {
      FocusScope.of(context).unfocus();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _opCtrls.insert(index + 1, TextEditingController());
      _opFocus.insert(index + 1, FocusNode());
    });
    final newIndex = index + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (newIndex < _opFocus.length) {
        FocusScope.of(context).requestFocus(_opFocus[newIndex]);
      }
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.templateId == null ? 'Новый шаблон' : 'Редактирование'),
        actions: [
          IconButton(
            tooltip: 'Вставить список операций',
            icon: const Icon(Icons.playlist_add_outlined),
            onPressed: _pasteList,
          ),
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TemplateTitleField(controller: _nameCtrl),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Операции · удерживайте ⋮⋮ для переноса · свайп влево — удалить',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: _opCtrls.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Добавьте операции для хронометража',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    buildDefaultDragHandles: false,
                    itemCount: _opCtrls.length,
                    onReorder: _onReorder,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final t = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
                          return Transform.scale(
                            scale: 1.0 + 0.02 * t.value,
                            child: Material(
                              elevation: 6 * t.value,
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.transparent,
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                    itemBuilder: (context, index) {
                      final c = _opCtrls[index];
                      final f = _opFocus[index];
                      return OperationItemCard(
                        key: ValueKey(c),
                        displayIndex: index + 1,
                        reorderIndex: index,
                        controller: c,
                        focusNode: f,
                        onDismissSwipe: () {
                          final i = _opCtrls.indexOf(c);
                          if (i >= 0) _removeRowAt(i);
                        },
                        onRemovePressed: () {
                          final i = _opCtrls.indexOf(c);
                          if (i >= 0) _removeRowAt(i);
                        },
                        onSubmitRow: _onSubmitRow,
                        onDragHandleDown: () => HapticFeedback.selectionClick(),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: AddOperationFooter(
        onPressed: () => _addOperation(autofocus: true),
      ),
    );
  }
}
