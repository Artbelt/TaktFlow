import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/measurement_record_model.dart';
import '../models/measurement_session_model.dart';
import '../models/template_model.dart';

class ExportService {
  static final RegExp _illegalFileChars = RegExp(r'[\\/:*?"<>|]');

  /// CSV escaping:
  /// - экранируем кавычки двойными кавычками;
  /// - оборачиваем в кавычки, если есть разделитель ';', кавычка или перенос.
  static String _escapeCsv(String value) {
    if (value.contains(';') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _safeFilePart(String raw) {
    final replaced = raw.trim().replaceAll(_illegalFileChars, '_');
    final compact = replaced.replaceAll(RegExp(r'\s+'), '_');
    if (compact.isEmpty) return 'template';
    return compact;
  }

  static String _buildSessionCsv({
    required MeasurementSessionModel session,
    required TemplateModel template,
    required List<MeasurementRecordModel> records,
  }) {
    final buf = StringBuffer();
    final sorted = List<MeasurementRecordModel>.from(records)
      ..sort((a, b) => a.id.compareTo(b.id));

    final operationOrder = <String>[];
    final operationToCycleDuration = <String, Map<int, String>>{};
    final cycles = <int>{};

    for (final r in sorted) {
      cycles.add(r.cycleNumber);
      operationToCycleDuration.putIfAbsent(r.operationName, () {
        operationOrder.add(r.operationName);
        return <int, String>{};
      });
      operationToCycleDuration[r.operationName]![r.cycleNumber] =
          (r.durationMs / 1000.0).toStringAsFixed(2);
    }

    final cycleList = cycles.toList()..sort();
    final header = <String>[
      'template_name',
      'session_id',
      'operation_name',
      ...cycleList.map((c) => 'cycle_$c'),
    ].join(';');
    buf.writeln(header);

    for (final operation in operationOrder) {
      final row = <String>[
        _escapeCsv(template.name),
        session.id.toString(),
        _escapeCsv(operation),
        ...cycleList.map((c) => _escapeCsv(operationToCycleDuration[operation]?[c] ?? '')),
      ].join(';');
      buf.writeln(row);
    }

    // Доп. блок внизу оставляет ключевые метаданные сессии для отчётности.
    final df = DateFormat('yyyy-MM-dd HH:mm:ss');
    buf.writeln();
    buf.writeln('date_time;template_name;session_id');
    buf.writeln(
      '${_escapeCsv(df.format(session.startedAt.toLocal()))};${_escapeCsv(template.name)};${session.id}',
    );
    return buf.toString();
  }

  static String _buildAllTemplateSessionsCsv({
    required TemplateModel template,
    required List<MeasurementRecordModel> records,
  }) {
    final buf = StringBuffer();
    buf.writeln(
      'date_time;template_name;session_id;cycle_number;operation_name;duration_seconds;duration_ms;comment',
    );
    final df = DateFormat('yyyy-MM-dd HH:mm:ss');
    for (final r in records) {
      final row = <String>[
        _escapeCsv(df.format(r.endedAt.toLocal())),
        _escapeCsv(template.name),
        r.sessionId.toString(),
        r.cycleNumber.toString(),
        _escapeCsv(r.operationName),
        (r.durationMs / 1000.0).toStringAsFixed(2),
        r.durationMs.toString(),
        _escapeCsv(r.comment ?? ''),
      ].join(';');
      buf.writeln(row);
    }
    return buf.toString();
  }

  static Future<File> exportSessionToCsv({
    required MeasurementSessionModel session,
    required TemplateModel template,
    required List<MeasurementRecordModel> records,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeTemplate = _safeFilePart(template.name);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(session.startedAt.toLocal());
    final file = File('${dir.path}/taktflow_${safeTemplate}_$stamp.csv');
    final csv = _buildSessionCsv(session: session, template: template, records: records);
    // BOM нужен для корректного открытия UTF-8 CSV в Excel с кириллицей.
    final bytes = utf8.encode('\uFEFF$csv');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> exportTemplateAllToCsv({
    required TemplateModel template,
    required List<MeasurementRecordModel> records,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeTemplate = _safeFilePart(template.name);
    final file = File('${dir.path}/taktflow_${safeTemplate}_all.csv');
    final csv = _buildAllTemplateSessionsCsv(template: template, records: records);
    // BOM нужен для корректного открытия UTF-8 CSV в Excel с кириллицей.
    final bytes = utf8.encode('\uFEFF$csv');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> shareCsvFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Экспорт замера TaktFlow',
      ),
    );
  }
}
