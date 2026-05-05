import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/measurement_record_model.dart';
import '../models/template_model.dart';

class CsvExportService {
  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String buildCsv({
    required List<MeasurementRecordModel> records,
    required TemplateModel template,
  }) {
    final buf = StringBuffer();
    buf.writeln(
      'date_time,template_name,cycle_number,operation_name,duration_seconds,comment',
    );
    final df = DateFormat('yyyy-MM-dd HH:mm:ss');
    for (final r in records) {
      final dt = df.format(r.endedAt.toLocal());
      final secs = (r.durationMs / 1000).toStringAsFixed(3);
      final row = [
        _escape(dt),
        _escape(template.name),
        r.cycleNumber.toString(),
        _escape(r.operationName),
        secs,
        _escape(r.comment ?? ''),
      ].join(',');
      buf.writeln(row);
    }
    return buf.toString();
  }

  static Future<void> shareCsv(String csv, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv, encoding: utf8);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Экспорт замера CSV',
      ),
    );
  }
}
