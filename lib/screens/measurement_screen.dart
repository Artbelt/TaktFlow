import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/measurement_record_model.dart';
import '../models/template_model.dart';
import '../services/measurement_timer_service.dart';
import '../widgets/big_bottom_action.dart';
import '../widgets/section_title.dart';

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key, required this.templateId});

  final int templateId;

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  final _db = AppDatabase.instance;
  MeasurementTimerService? _service;
  TemplateModel? _template;
  bool _loading = true;
  List<MeasurementRecordModel> _recent = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final t = await _db.getTemplate(widget.templateId);
    final ops = await _db.getOperations(widget.templateId);
    if (!mounted) return;
    if (t == null || ops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет операций для замера')),
      );
      Navigator.pop(context);
      return;
    }
    _template = t;
    _service = MeasurementTimerService(
      templateId: t.id,
      templateName: t.name,
      operations: ops,
    );
    setState(() => _loading = false);
  }

  Future<void> _refreshRecent() async {
    if (_service?.sessionId == null) {
      _recent = [];
      return;
    }
    _recent = await _db.getLastRecordsForSession(_service!.sessionId!, 5);
  }

  Future<bool> _confirmExit() async {
    final s = _service;
    if (s == null || !s.started) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Завершить замер?'),
        content: const Text('Активная сессия будет закрыта и сохранена в истории.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Остаться')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Выйти')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _leave() async {
    final s = _service;
    if (s != null && s.started) {
      await s.endSession();
    }
    s?.dispose();
    _service = null;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handlePop() async {
    final allow = await _confirmExit();
    if (allow && mounted) await _leave();
  }

  String _formatElapsed(int ms) {
    final sec = ms / 1000.0;
    if (sec >= 60) {
      final m = sec ~/ 60;
      final s = sec - m * 60;
      return '$mм ${s.toStringAsFixed(1)}с';
    }
    return '${sec.toStringAsFixed(1)} с';
  }

  @override
  void dispose() {
    _service?.dispose();
    _service = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _service == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final service = _service!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handlePop();
      },
      child: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final op = service.currentOperation;
          final elapsed = service.activeElapsedMs;
          final mainLabel = !service.started
              ? 'СТАРТ'
              : 'ЗАВЕРШИТЬ: ${op?.name ?? ""}';

          return Scaffold(
            appBar: AppBar(
              title: Text(_template?.name ?? 'Замер'),
              leading: BackButton(onPressed: _handlePop),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Цикл: ${service.cycleNumber}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    service.started ? (op?.name ?? '') : 'Нажмите СТАРТ',
                    key: ValueKey<String>(
                      '${service.cycleNumber}_${service.operationIndex}_${op?.name ?? ''}',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  service.paused ? 'ПАУЗА' : 'Секундомер',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: service.paused ? Theme.of(context).colorScheme.error : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _formatElapsed(elapsed),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Далее: ${service.nextOperationName ?? "—"}',
                    key: ValueKey<String>(
                      'next_${service.cycleNumber}_${service.operationIndex}_${service.nextOperationName ?? ""}',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: !service.started ? null : service.togglePause,
                          child: Text(service.paused ? 'Продолжить' : 'Пауза'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _recent.isEmpty
                              ? null
                              : () async {
                                  await service.undoLastTick();
                                  await _refreshRecent();
                                  setState(() {});
                                },
                          child: const Text('Отменить отсечку'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Последние отсечки'),
                Expanded(
                  child: _recent.isEmpty
                      ? const Center(child: Text('Пока нет записей', style: TextStyle(fontSize: 16)))
                      : ListView.builder(
                          itemCount: _recent.length,
                          itemBuilder: (context, i) {
                            final r = _recent[_recent.length - 1 - i];
                            return ListTile(
                              title: Text(r.operationName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                'Цикл ${r.cycleNumber} · ${_formatElapsed(r.durationMs)} · ${_formatClock(r.endedAt)}',
                              ),
                            );
                          },
                        ),
                ),
                BigBottomAction(
                  label: mainLabel,
                  labelKey: ValueKey<String>(
                    'cta_${service.started}_${service.cycleNumber}_${service.operationIndex}_${op?.name ?? ""}',
                  ),
                  enabled: op != null,
                  onPressed: () async {
                    if (!service.started) {
                      await service.start();
                    } else {
                      await service.completeCurrentOperation();
                    }
                    await _refreshRecent();
                    setState(() {});
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatClock(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}:${l.second.toString().padLeft(2, '0')}';
  }
}
