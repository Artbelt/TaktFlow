import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/measurement_session_model.dart';
import '../services/export_service.dart';
import 'analytics/session_analytics_screen.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = AppDatabase.instance;
  late Future<_HistoryData> _future;
  final Set<int> _exportingSessionIds = <int>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HistoryData> _load() async {
    final sessions = await _db.getAllSessions();
    final agg = await _db.getSessionAggregates();
    final templates = await _db.getTemplates();
    final names = {for (final t in templates) t.id: t.name};
    return _HistoryData(sessions: sessions, aggregates: agg, templateNames: names);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _exportSession(MeasurementSessionModel s) async {
    if (_exportingSessionIds.contains(s.id)) return;
    setState(() => _exportingSessionIds.add(s.id));
    try {
      final template = await _db.getTemplate(s.templateId);
      final records = await _db.getRecordsForSession(s.id);
      if (!mounted) return;
      if (template == null || records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет данных для экспорта')),
        );
        return;
      }
      final file = await ExportService.exportSessionToCsv(
        session: s,
        template: template,
        records: records,
      );
      await ExportService.shareCsvFile(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV экспортирован')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка экспорта CSV')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingSessionIds.remove(s.id));
      }
    }
  }

  Future<void> _confirmDeleteSession(MeasurementSessionModel s, String templateName) async {
    final time = _formatFullContext(s.startedAt);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить замер?'),
        content: Text(
          'Будут удалены все отсечки этой сессии.\n\n$time\n$templateName',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _db.deleteSession(s.id);
      _reload();
    }
  }

  String _dayKey(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month}-${l.day}';
  }

  String _formatDay(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}.${l.year}';
  }

  List<_HistoryRow> _buildRows(_HistoryData data) {
    final sorted = List<MeasurementSessionModel>.from(data.sessions)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final out = <_HistoryRow>[];
    String? lastGroup;
    for (final s in sorted) {
      final tplName = data.templateNames[s.templateId] ?? 'Шаблон #${s.templateId}';
      final group = '${_dayKey(s.startedAt)}|${s.templateId}';
      if (group != lastGroup) {
        out.add(_HistoryRow.header('${_formatDay(s.startedAt)} · $tplName'));
        lastGroup = group;
      }
      final a = data.aggregates[s.id];
      final cycles = a?.maxCycle ?? 0;
      final ops = a?.count ?? 0;
      out.add(_HistoryRow.session(s, tplName, cycles, ops));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История замеров')),
      body: FutureBuilder<_HistoryData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить историю',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final data = snap.data!;
          if (data.sessions.isEmpty) {
            return Center(
              child: Text(
                'Замеров пока нет',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            );
          }

          final rows = _buildRows(data);

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final it = rows[i];
                if (it.isHeader) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      it.title!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  );
                }
                final s = it.session!;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    title: Text(
                      '${_formatClock(s.startedAt)} — ${it.templateName}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Циклов (max): ${it.cycles} · Отсечек: ${it.operations}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: _exportingSessionIds.contains(s.id)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2),
                                )
                              : const Icon(Icons.ios_share_outlined),
                          tooltip: 'Экспорт CSV',
                          onPressed: _exportingSessionIds.contains(s.id)
                              ? null
                              : () => _exportSession(s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.analytics_outlined),
                          tooltip: 'Аналитика',
                          onPressed: () async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => SessionAnalyticsScreen(sessionId: s.id),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Удалить замер',
                          onPressed: () => _confirmDeleteSession(s, it.templateName),
                        ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => SessionDetailScreen(sessionId: s.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatClock(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  String _formatFullContext(DateTime d) {
    final l = d.toLocal();
    final date = '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}.${l.year}';
    final time =
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}:${l.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _HistoryData {
  _HistoryData({
    required this.sessions,
    required this.aggregates,
    required this.templateNames,
  });

  final List<MeasurementSessionModel> sessions;
  final Map<int, ({int count, int maxCycle})> aggregates;
  final Map<int, String> templateNames;
}

class _HistoryRow {
  _HistoryRow._({
    required this.isHeader,
    this.title,
    this.session,
    this.templateName = '',
    this.cycles = 0,
    this.operations = 0,
  });

  factory _HistoryRow.header(String title) {
    return _HistoryRow._(isHeader: true, title: title);
  }

  factory _HistoryRow.session(
    MeasurementSessionModel s,
    String templateName,
    int cycles,
    int operations,
  ) {
    return _HistoryRow._(
      isHeader: false,
      session: s,
      templateName: templateName,
      cycles: cycles,
      operations: operations,
    );
  }

  final bool isHeader;
  final String? title;
  final MeasurementSessionModel? session;
  final String templateName;
  final int cycles;
  final int operations;
}
