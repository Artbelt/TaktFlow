import 'dart:math' as math;

/// Компактная подпись: «N операций • dd.MM.yyyy» с корректным склонением.
String operationsCountLabelRu(int count) {
  final n = math.max(count, 0);
  late final String suffix;
  if (n % 10 == 1 && n % 100 != 11) {
    suffix = 'операция';
  } else if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) {
    suffix = 'операции';
  } else {
    suffix = 'операций';
  }
  return '$n $suffix';
}
