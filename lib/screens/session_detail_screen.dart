import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';
import '../models/measurement_record_model.dart';
import '../models/measurement_session_model.dart';
import '../models/template_model.dart';
import '../services/analytics_service.dart';
import '../services/export_service.dart';
import '../services/pdf_report_service.dart';
import 'analytics/session_analytics_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _db = AppDatabase.instance;
  late Future<_DetailData> _future;
  bool _isExporting = false;
  bool _isPdfExporting = false;

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
    if (_isExporting) return;
    if (data.template == null || data.session == null) return;
    if (data.records.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет данных для экспорта')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final file = await ExportService.exportSessionToCsv(
        session: data.session!,
        template: data.template!,
        records: data.records,
      );
      await ExportService.shareCsvFile(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV экспортирован')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка экспорта CSV')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Таблица замера'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Аналитика',
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SessionAnalyticsScreen(sessionId: widget.sessionId),
                ),
              );
            },
          ),
          IconButton(
            icon: _isPdfExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Экспорт PDF',
            onPressed: _isPdfExporting
                ? null
                : () async {
                    final data = await _load();
                    if (!context.mounted) return;
                    await _exportPdf(data);
                  },
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.share_outlined),
            tooltip: 'Экспорт CSV',
            onPressed: _isExporting
                ? null
                : () async {
              final data = await _load();
              if (!context.mounted) return;
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

          final pivot = _buildPivot(data.records);
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
                      columns: [
                        const DataColumn(
                          label: Text('Операция', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        ...pivot.cycles.map(
                          (c) => DataColumn(
                            label: Text('Ц$c', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                      rows: pivot.operationOrder.map((operationName) {
                        final cells = <DataCell>[
                          DataCell(
                            Text(
                              operationName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ];
                        for (final cycle in pivot.cycles) {
                          final ms = pivot.values[operationName]?[cycle];
                          final secs = ms == null ? '' : (ms / 1000.0).toStringAsFixed(2);
                          cells.add(
                            DataCell(
                              Text(
                                secs.isEmpty ? '—' : '$secs с',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          );
                        }
                        return DataRow(cells: cells);
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

  _PivotData _buildPivot(List<MeasurementRecordModel> records) {
    final sorted = List<MeasurementRecordModel>.from(records)
      ..sort((a, b) => a.id.compareTo(b.id));
    final operationOrder = <String>[];
    final values = <String, Map<int, int>>{};
    final cyclesSet = <int>{};

    for (final r in sorted) {
      cyclesSet.add(r.cycleNumber);
      values.putIfAbsent(r.operationName, () {
        operationOrder.add(r.operationName);
        return <int, int>{};
      });
      values[r.operationName]![r.cycleNumber] = r.durationMs;
    }

    final cycles = cyclesSet.toList()..sort();
    return _PivotData(operationOrder: operationOrder, cycles: cycles, values: values);
  }

  Future<void> _exportPdf(_DetailData data) async {
    if (_isPdfExporting) return;
    if (data.session == null || data.template == null) return;
    if (data.records.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет данных для отчёта')),
      );
      return;
    }

    setState(() => _isPdfExporting = true);
    try {
      final ops = await _db.getOperations(data.session!.templateId);
      final analytics = AnalyticsService.calculateSessionAnalytics(
        records: data.records,
        templateOperations: ops,
      );
      final file = await PdfReportService.exportSessionReportPdf(
        session: data.session!,
        template: data.template!,
        records: data.records,
        analytics: analytics,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'PDF-отчёт TaktFlow',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF-отчёт создан')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка создания PDF')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPdfExporting = false);
    }
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

class _PivotData {
  _PivotData({
    required this.operationOrder,
    required this.cycles,
    required this.values,
  });

  final List<String> operationOrder;
  final List<int> cycles;
  final Map<String, Map<int, int>> values;
}
