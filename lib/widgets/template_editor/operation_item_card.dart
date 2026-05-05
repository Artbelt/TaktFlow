import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Одна строка операции: номер, хват reorder, поле ввода, свайп, приглушённая иконка удаления.
class OperationItemCard extends StatelessWidget {
  const OperationItemCard({
    super.key,
    required this.displayIndex,
    required this.reorderIndex,
    required this.controller,
    required this.focusNode,
    required this.onDismissSwipe,
    required this.onRemovePressed,
    required this.onSubmitRow,
    this.onDragHandleDown,
  });

  /// 1…N для пользователя.
  final int displayIndex;

  /// Индекс в ReorderableListView (0-based).
  final int reorderIndex;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// После успешного свайпа удаления (виджет уже снялся из дерева).
  final VoidCallback onDismissSwipe;

  final VoidCallback onRemovePressed;

  /// Enter / «Готово» на клавиатуре для быстрого ввода.
  final void Function(TextEditingController c) onSubmitRow;

  /// Тактильный отклик при касании ручки перетаскивания.
  final VoidCallback? onDragHandleDown;

  void _selectAll() {
    final t = controller.text;
    controller.selection = TextSelection(baseOffset: 0, extentOffset: t.length);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtextStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 17,
          color: scheme.onSurface.withValues(alpha: 0.92),
        );

    return Dismissible(
      key: ValueKey<TextEditingController>(controller),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: scheme.onSurface),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDismissSwipe();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Material(
          color: Theme.of(context).cardTheme.color ?? const Color(0xFF1E1E1E),
          elevation: Theme.of(context).cardTheme.elevation ?? 2,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => onDragHandleDown?.call(),
                  child: ReorderableDragStartListener(
                    index: reorderIndex,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Tooltip(
                        message: 'Удержите и перетащите',
                        child: Icon(Icons.drag_indicator, color: scheme.onSurfaceVariant, size: 26),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$displayIndex',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onLongPress: () {
                      HapticFeedback.selectionClick();
                      focusNode.requestFocus();
                      _selectAll();
                    },
                    behavior: HitTestBehavior.translucent,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: subtextStyle,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Операция',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      onTap: () {
                        focusNode.requestFocus();
                        _selectAll();
                      },
                      onSubmitted: (_) => onSubmitRow(controller),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Удалить строку',
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  splashRadius: 20,
                  color: scheme.onSurface.withValues(alpha: 0.42),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onRemovePressed();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
