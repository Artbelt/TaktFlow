import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/app_database.dart';
import '../models/template_model.dart';
import '../widgets/template_editor/template_editor_helpers.dart';
import 'measurement_screen.dart';
import 'template_editor_screen.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _db = AppDatabase.instance;
  late Future<List<TemplateModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _db.getTemplates();
  }

  void _reload() {
    setState(() {
      _future = _db.getTemplates();
    });
  }

  Future<void> _confirmDelete(TemplateModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить шаблон?'),
        content: Text('«${t.name}» и все связанные замеры будут удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      await _db.deleteTemplate(t.id);
      _reload();
    }
  }

  Future<void> _openTemplate(TemplateModel t) async {
    final n = await _db.countOperations(t.id);
    if (!mounted) return;
    if (n == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте операции в шаблон перед замером')),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => MeasurementScreen(templateId: t.id)),
    );
  }

  Future<void> _duplicateTemplate(TemplateModel t) async {
    final nameCtrl = TextEditingController(text: '${t.name} (копия)');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Название копии'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название шаблона',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (!mounted || newName == null) return;
    if (newName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название копии')),
      );
      return;
    }
    await _db.duplicateTemplate(t.id, newName: newName);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Шаблон скопирован')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Шаблоны')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => const TemplateEditorScreen(),
            ),
          );
          _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('Создать шаблон'),
      ),
      body: FutureBuilder<List<TemplateModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Создайте первый шаблон.\nКнопка «Создать шаблон» внизу.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                return FutureBuilder<int>(
                  future: _db.countOperations(t.id),
                  builder: (context, countSnap) {
                    final cnt = countSnap.data ?? 0;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          t.name,
                          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${operationsCountLabelRu(cnt)} • ${_formatDate(t.createdAt)}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              tooltip: 'Действия',
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value == 'copy') {
                                  await _duplicateTemplate(t);
                                  return;
                                }
                                if (value == 'edit') {
                                  await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute<bool>(
                                      builder: (_) => TemplateEditorScreen(templateId: t.id),
                                    ),
                                  );
                                  _reload();
                                  return;
                                }
                                if (value == 'delete') {
                                  await _confirmDelete(t);
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem<String>(
                                  value: 'copy',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.content_copy_outlined),
                                    title: Text('Копировать'),
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Изменить'),
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Удалить'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _openTemplate(t),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}
