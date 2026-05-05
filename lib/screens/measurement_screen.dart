import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/app_database.dart';
import '../models/measurement_record_model.dart';
import '../models/template_model.dart';
import '../services/measurement_timer_service.dart';
import '../widgets/measurement/current_operation_view.dart';
import '../widgets/measurement/last_ticks_list.dart';
import '../widgets/measurement/main_measurement_button.dart';
import '../widgets/measurement/measurement_status_banner.dart';
import '../widgets/measurement/measurement_top_bar.dart';
import '../widgets/measurement/next_operation_view.dart';
import '../widgets/measurement/timer_view.dart';

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key, required this.templateId});

  final int templateId;

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  static const _debounceMs = 250;

  final _db = AppDatabase.instance;
  MeasurementTimerService? _service;
  TemplateModel? _template;
  bool _loading = true;

  List<MeasurementRecordModel> _recent = [];
  DateTime? _lastMainTap;

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
    _recent = await _db.getLastRecordsForSession(_service!.sessionId!, 3);
  }

  bool _mainDebounceConsume() {
    final now = DateTime.now();
    if (_lastMainTap != null && now.difference(_lastMainTap!).inMilliseconds < _debounceMs) {
      return false;
    }
    _lastMainTap = now;
    return true;
  }

  Future<bool> _confirmExit() async {
    final s = _service;
    if (s == null || !s.started) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из замера?'),
        content: const Text('Замер не завершён. Выйти?'),
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

  Future<void> _togglePausePressed() async {
    final s = _service;
    if (s == null || !s.started) return;
    HapticFeedback.selectionClick();
    s.togglePause();
  }

  Future<void> _undoPressed() async {
    final s = _service;
    if (s == null || !s.started || _recent.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final payload = await s.undoLastTickForRedo();
    await _refreshRecent();
    setState(() {});

    if (!mounted || payload == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Отсечка отменена'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Вернуть',
            onPressed: () async {
              await s.redoUndoneTick(payload);
              await _refreshRecent();
              if (mounted) setState(() {});
            },
          ),
        ),
      );

    HapticFeedback.lightImpact();
  }

  String _primaryLabel(MeasurementTimerService service, String opName) {
    if (!service.started) return 'СТАРТ';
    if (service.paused) return 'ПРОДОЛЖИТЬ: $opName';
    return 'ЗАВЕРШИТЬ: $opName';
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
    final op = service.currentOperation;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handlePop();
      },
      child: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final currentOp = service.currentOperation;
          final opName = currentOp?.name ?? '';
          final elapsed = service.activeElapsedMs;
          final canUndo = service.started && _recent.isNotEmpty;

          Future<void> onPrimary() async {
            if (!_mainDebounceConsume()) return;
            final s = _service!;
            final cOp = s.currentOperation;
            if (cOp == null) return;

            if (!s.started) {
              HapticFeedback.lightImpact();
              await s.start();
            } else if (s.paused) {
              HapticFeedback.lightImpact();
              s.togglePause();
            } else {
              final cycleBoundary = await s.completeCurrentOperation();
              HapticFeedback.lightImpact();
              if (cycleBoundary) {
                HapticFeedback.mediumImpact();
              }
            }

            await _refreshRecent();
            setState(() {});
          }

          return Scaffold(
            appBar: MeasurementTopBar(
              title: _template?.name ?? 'Замер',
              started: service.started,
              paused: service.paused,
              canUndo: canUndo,
              onBack: _handlePop,
              onTogglePause: _togglePausePressed,
              onUndo: _undoPressed,
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MeasurementStatusBanner(
                  started: service.started,
                  paused: service.paused,
                  cycleNumber: service.cycleNumber,
                ),
                CurrentOperationView(
                  title: opName,
                  started: service.started,
                  displayKey: ValueKey<String>(
                    '${service.cycleNumber}_${service.operationIndex}_$opName',
                  ),
                ),
                MeasurementTimerView(
                  elapsedMs: elapsed,
                  tickerKey: ValueKey<int>(elapsed ~/ 100),
                ),
                const Spacer(),
                NextOperationView(
                  nextNameOrDash: service.nextOperationName ?? '—',
                  displayKey: ValueKey<String>(
                    'next_${service.cycleNumber}_${service.operationIndex}_${service.nextOperationName ?? ''}',
                  ),
                ),
                LastTicksList(
                  recordsNewestFirst: List<MeasurementRecordModel>.from(_recent.reversed),
                ),
                MainMeasurementButton(
                  label: _primaryLabel(service, opName),
                  labelKey: ValueKey<String>(
                    'cta_${service.started}_${service.paused}_${service.cycleNumber}_${service.operationIndex}_$opName',
                  ),
                  enabled: op != null,
                  onPressed: op != null ? onPrimary : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
