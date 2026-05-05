import 'package:flutter/material.dart';

import '../../database/app_database.dart';
import '../../models/analytics_models.dart';
import '../../models/measurement_session_model.dart';
import '../../models/operation_model.dart';
import '../../models/template_model.dart';
import '../../services/analytics_service.dart';
import '../../utils/analytics/duration_format.dart';
import '../../widgets/analytics/bottleneck_card.dart';
import '../../widgets/analytics/operation_analytics_card.dart';
import '../../widgets/analytics/summary_metric_card.dart';
import '../../widgets/section_title.dart';

class SessionAnalyticsScreen extends StatefulWidget {
  const SessionAnalyticsScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  State<SessionAnalyticsScreen> createState() => _SessionAnalyticsScreenState();
}

class _SessionAnalyticsScreenState extends State<SessionAnalyticsScreen> {
  final _db = AppDatabase.instance;
  late Future<_AnalyticsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnalyticsData> _load() async {
    final session = await _db.getSession(widget.sessionId);
    if (session == null) return _AnalyticsData.empty();
    final template = await _db.getTemplate(session.templateId);
    final records = await _db.getRecordsForSession(session.id);
    final ops = await _db.getOperations(session.templateId);
    if (template == null) return _AnalyticsData.empty();
    final analytics = AnalyticsService.calculateSessionAnalytics(
      records: records,
      templateOperations: ops,
    );
    return _AnalyticsData(
      session: session,
      template: template,
      operations: ops,
      analytics: analytics,
      recordsCount: records.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Аналитика')),
      body: FutureBuilder<_AnalyticsData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data;
          if (data == null || data.session == null || data.template == null) {
            return const Center(child: Text('Нет данных для аналитики'));
          }

          final a = data.analytics!;
          if (data.recordsCount == 0 || a.operations.isEmpty) {
            return const Center(child: Text('Нет данных для аналитики'));
          }

          final warning = a.completedCyclesCount < 3
              ? 'Данных пока мало. Для надёжной аналитики сделайте хотя бы 3 цикла.'
              : null;
          final maxAvg = a.operations.fold<int>(0, (m, o) => o.averageMs > m ? o.averageMs : m);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.template!.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Сессия #${data.session!.id}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (warning != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            warning,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.7,
                children: [
                  SummaryMetricCard(
                    title: 'Средний цикл',
                    value: formatDurationMs(a.averageCycleMs),
                  ),
                  SummaryMetricCard(
                    title: 'Циклов',
                    value: '${a.completedCyclesCount}',
                    subtitle: 'только завершённые',
                  ),
                  SummaryMetricCard(
                    title: 'Узкое место',
                    value: formatDurationMs(a.bottleneckAverageMs),
                    subtitle: a.bottleneckOperationName,
                  ),
                  SummaryMetricCard(
                    title: 'Разброс',
                    value: formatDurationMs(a.averageSpreadMs),
                    subtitle: 'средний по операциям',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BottleneckCard(
                operationName: a.bottleneckOperationName,
                averageMs: a.bottleneckAverageMs,
              ),
              const SectionTitle('Операции по убыванию времени'),
              ...a.operations.map(
                (op) => OperationAnalyticsCard(data: op, maxAverageMs: maxAvg),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsData {
  const _AnalyticsData({
    required this.session,
    required this.template,
    required this.operations,
    required this.analytics,
    required this.recordsCount,
  });

  factory _AnalyticsData.empty() {
    return const _AnalyticsData(
      session: null,
      template: null,
      operations: [],
      analytics: null,
      recordsCount: 0,
    );
  }

  final MeasurementSessionModel? session;
  final TemplateModel? template;
  final List<OperationModel> operations;
  final SessionAnalytics? analytics;
  final int recordsCount;
}
