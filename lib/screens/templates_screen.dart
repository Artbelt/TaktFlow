import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/template_model.dart';
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
                  'Нет шаблонов.\nНажмите «Создать шаблон».',
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
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(t.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          'Операций: $cnt · Создан: ${_formatDate(t.createdAt)}',
                          style: const TextStyle(fontSize: 15),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Изменить',
                              onPressed: () async {
                                await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute<bool>(
                                    builder: (_) => TemplateEditorScreen(templateId: t.id),
                                  ),
                                );
                                _reload();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Удалить',
                              onPressed: () => _confirmDelete(t),
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
