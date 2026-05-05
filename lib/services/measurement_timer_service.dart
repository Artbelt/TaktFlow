import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/measurement_record_model.dart';
import '../models/operation_model.dart';
import 'redo_undo_payload.dart';

/// Управляет циклом замера: старт, пауза, отсечки, откат.
///
/// Время операции считается по «настенным часам» минус накопленные паузы:
/// - при входе в паузу запоминаем момент начала паузы;
/// - при выходе добавляем длительность интервала к сумме «вычтенного» времени;
/// - пока пауза активна, из разности «сейчас − старт операции» дополнительно
///   вычитается незавершённый интервал паузы.
/// Так длительность операции не включает время, пока замер на паузе.
class MeasurementTimerService extends ChangeNotifier {
  MeasurementTimerService({
    required this.templateId,
    required this.templateName,
    required List<OperationModel> operations,
  }) : _operations = List<OperationModel>.from(operations) {
    _operations.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  final int templateId;
  final String templateName;
  final List<OperationModel> _operations;

  int? _sessionId;
  int _cycleNumber = 1;
  int _operationIndex = 0;
  bool _started = false;
  bool _paused = false;

  /// Момент начала отсчёта текущей операции (реальное время).
  DateTime? _opWallStart;

  /// Сумма полностью завершённых интервалов паузы для текущей операции (мс).
  int _pauseAccumMs = 0;

  /// Начало текущего (ещё не завершённого) интервала паузы.
  DateTime? _pauseStartedAt;

  Timer? _ticker;
  final AppDatabase _db = AppDatabase.instance;

  int? get sessionId => _sessionId;
  bool get started => _started;
  bool get paused => _paused;
  int get cycleNumber => _cycleNumber;
  int get operationIndex => _operationIndex;

  List<OperationModel> get operations => List.unmodifiable(_operations);

  OperationModel? get currentOperation =>
      _operations.isEmpty ? null : _operations[_operationIndex];

  /// Активное время текущей операции без учёта пауз (мс).
  int get activeElapsedMs {
    if (_opWallStart == null) return 0;
    final now = DateTime.now();
    final wallMs = now.difference(_opWallStart!).inMilliseconds;
    var subtractPauseMs = _pauseAccumMs;
    if (_pauseStartedAt != null) {
      subtractPauseMs += now.difference(_pauseStartedAt!).inMilliseconds;
    }
    return wallMs - subtractPauseMs;
  }

  String? get nextOperationName {
    if (_operations.isEmpty) return null;
    if (!_started) return _operations.first.name;
    final nextIdx = (_operationIndex + 1) % _operations.length;
    return _operations[nextIdx].name;
  }

  Future<List<MeasurementRecordModel>> loadRecentTicks() async {
    if (_sessionId == null) return [];
    return _db.getLastRecordsForSession(_sessionId!, 5);
  }

  void _ensureTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_started && !_paused) notifyListeners();
    });
  }

  /// Первый тап: создаёт сессию и начинает отсчёт первой операции.
  Future<void> start() async {
    if (_operations.isEmpty) return;
    if (_started) return;
    final now = DateTime.now();
    _sessionId = await _db.insertSession(templateId: templateId, startedAt: now);
    _started = true;
    _cycleNumber = 1;
    _operationIndex = 0;
    _resetTimerForNewOperation(now);
    _ensureTicker();
    notifyListeners();
  }

  void _resetTimerForNewOperation(DateTime now) {
    _opWallStart = now;
    _pauseAccumMs = 0;
    _pauseStartedAt = null;
    _paused = false;
  }

  /// Завершает текущую операцию, пишет запись, переходит к следующей
  /// или к следующему циклу (после последней операции).
  /// Возвращает `true`, если была завершена последняя операция цикла.
  Future<bool> completeCurrentOperation() async {
    if (!_started || _sessionId == null || _operations.isEmpty) return false;
    if (_opWallStart == null) return false;

    final now = DateTime.now();
    final op = _operations[_operationIndex];
    final startedAt = _opWallStart!;
    final durationMs = activeElapsedMs;

    await _db.insertRecord(
      sessionId: _sessionId!,
      templateId: templateId,
      operationId: op.id,
      operationName: op.name,
      cycleNumber: _cycleNumber,
      startedAt: startedAt,
      endedAt: now,
      durationMs: durationMs,
    );

    final isLast = _operationIndex == _operations.length - 1;
    if (isLast) {
      _operationIndex = 0;
      _cycleNumber++;
    } else {
      _operationIndex++;
    }
    _resetTimerForNewOperation(now);
    notifyListeners();
    return isLast;
  }

  void togglePause() {
    if (!_started || _opWallStart == null) return;
    final now = DateTime.now();
    if (!_paused) {
      _pauseStartedAt = now;
      _paused = true;
    } else {
      if (_pauseStartedAt != null) {
        _pauseAccumMs += now.difference(_pauseStartedAt!).inMilliseconds;
        _pauseStartedAt = null;
      }
      _paused = false;
    }
    notifyListeners();
  }

  /// Удаляет последнюю запись ([undoLastTickForRedo] с данными для «Вернуть»).
  Future<void> undoLastTick() async {
    await undoLastTickForRedo();
  }

  /// Как [undoLastTick], плюс данные для восстановления (snackbar «Вернуть»).
  Future<RedoUndoPayload?> undoLastTickForRedo() async {
    if (_sessionId == null) return null;

    final nextIdx = _operationIndex;
    final nextCycle = _cycleNumber;

    final last = await _db.getLastRecordForSession(_sessionId!);
    if (last == null) return null;

    await _db.deleteRecord(last.id);

    final idx = _operations.indexWhere((o) => o.id == last.operationId);
    _operationIndex = idx >= 0 ? idx : 0;
    _cycleNumber = last.cycleNumber;
    _resetTimerForNewOperation(DateTime.now());
    notifyListeners();
    return RedoUndoPayload(
      snapshot: last,
      nextOperationIndex: nextIdx,
      nextCycleNumber: nextCycle,
    );
  }

  Future<void> redoUndoneTick(RedoUndoPayload payload) async {
    if (_sessionId == null) return;
    final r = payload.snapshot;
    await _db.insertRecord(
      sessionId: _sessionId!,
      templateId: r.templateId,
      operationId: r.operationId,
      operationName: r.operationName,
      cycleNumber: r.cycleNumber,
      startedAt: r.startedAt,
      endedAt: r.endedAt,
      durationMs: r.durationMs,
      comment: r.comment,
    );
    _operationIndex = payload.nextOperationIndex;
    _cycleNumber = payload.nextCycleNumber;
    _resetTimerForNewOperation(DateTime.now());
    notifyListeners();
  }

  Future<void> endSession() async {
    if (_sessionId != null) {
      await _db.updateSessionEnded(_sessionId!, DateTime.now());
    }
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
