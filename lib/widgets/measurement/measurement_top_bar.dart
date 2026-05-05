import 'package:flutter/material.dart';

/// Верхняя панель экрана замера: назад, пауза, отмена отсечки.
class MeasurementTopBar extends StatelessWidget implements PreferredSizeWidget {
  const MeasurementTopBar({
    super.key,
    required this.title,
    required this.started,
    required this.paused,
    required this.canUndo,
    required this.onBack,
    required this.onTogglePause,
    required this.onUndo,
  });

  final String title;
  final bool started;
  final bool paused;
  final bool canUndo;
  final VoidCallback onBack;
  final VoidCallback onTogglePause;
  final VoidCallback onUndo;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      title: Text(title),
      leading: BackButton(onPressed: onBack),
      actions: [
        IconButton(
          tooltip: paused ? 'Продолжить замер' : 'Пауза',
          iconSize: 26,
          onPressed: started ? onTogglePause : null,
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: IconButton(
            tooltip: 'Отменить отсечку',
            visualDensity: VisualDensity.compact,
            iconSize: 21,
            style: IconButton.styleFrom(
              foregroundColor: scheme.onSurface.withValues(alpha: canUndo ? 0.62 : 0.28),
            ),
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded),
          ),
        ),
      ],
    );
  }
}
