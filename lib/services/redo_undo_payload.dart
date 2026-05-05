import '../models/measurement_record_model.dart';

/// Данные для восстановления отменённой отсечки (кнопка «Вернуть» в snackbar).
class RedoUndoPayload {
  const RedoUndoPayload({
    required this.snapshot,
    required this.nextOperationIndex,
    required this.nextCycleNumber,
  });

  final MeasurementRecordModel snapshot;
  final int nextOperationIndex;
  final int nextCycleNumber;
}
