import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../models/measurement_record_model.dart';
import '../models/measurement_session_model.dart';
import '../models/template_model.dart';
import '../services/csv_export_service.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _db = AppDatabase.instance;
  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final session = await _db.getSession(widget.sessionId);
    if (session == null) {
      return _DetailData.empty();
    }
    final template = await _db.getTemplate(session.templateId);
    final records = await _db.getRecordsForSession(widget.sessionId);
    return _DetailData(session: session, template: template, records: records);
  }

  Future<void> _export(_DetailData data) async {
    if (data.template == null) return;
    final csv = CsvExportService.buildCsv(
      records: data.records,
      template: data.template!,
    );
    final name = 'taktflow_${widget.sessionId}_${DateTime.now().millisecondsSinceEpoch}.csv';
    await CsvExportService.shareCsv(csv, name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Таблица замера'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Экспорт CSV',
            onPressed: () async {
              final data = await _load();
              if (!context.mounted) return;
              if (data.records.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Нет строк для экспорта')),
                );
                return;
              }
              await _export(data);
            },
          ),
        ],
      ),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.session == null) {
            return const Center(child: Text('Сессия не найдена'));
          }
          if (data.records.isEmpty) {
            return const Center(child: Text('В этой сессии нет отсечек'));
          }

          final df = DateFormat('yyyy-MM-dd HH:mm:ss');
          return LayoutBuilder(
            builder: (context, c) {
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: c.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      columns: const [
                        DataColumn(label: Text('Дата/время', style: TextStyle(fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('Шаблон', style: TextStyle(fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('Цикл', style: TextStyle(fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('Операция', style: TextStyle(fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('Сек', style: TextStyle(fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('Коммент.', style: TextStyle(fontWeight: FontWeight.w800))),
                      ],
                      rows: data.records.map((r) {
                        final tpl = data.template?.name ?? '—';
                        final secs = (r.durationMs / 1000).toStringAsFixed(2);
                        return DataRow(
                          cells: [
                            DataCell(Text(df.format(r.endedAt.toLocal()), style: const TextStyle(fontSize: 15))),
                            DataCell(Text(tpl, style: const TextStyle(fontSize: 15))),
                            DataCell(Text('${r.cycleNumber}', style: const TextStyle(fontSize: 15))),
                            DataCell(Text(r.operationName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                            DataCell(Text(secs, style: const TextStyle(fontSize: 15))),
                            DataCell(Text(r.comment ?? '', style: const TextStyle(fontSize: 15))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailData {
  _DetailData({
    required this.session,
    required this.template,
    required this.records,
  });

  factory _DetailData.empty() {
    return _DetailData(session: null, template: null, records: []);
  }

  final MeasurementSessionModel? session;
  final TemplateModel? template;
  final List<MeasurementRecordModel> records;
}
