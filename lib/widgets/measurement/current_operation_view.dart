import 'package:flutter/material.dart';

class CurrentOperationView extends StatelessWidget {
  const CurrentOperationView({
    super.key,
    required this.title,
    required this.started,
    required this.displayKey,
  });

  final String title;
  final bool started;
  /// Ключ для корректного ellipsis при смене шага.
  final Key displayKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Text(
        started ? title : 'Нажмите СТАРТ',
        key: displayKey,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 30,
              height: 1.12,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}
