import 'package:flutter/material.dart';

/// Верхняя панель экрана замера: только назад и заголовок.
class MeasurementTopBar extends StatelessWidget implements PreferredSizeWidget {
  const MeasurementTopBar({
    super.key,
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: BackButton(onPressed: onBack),
    );
  }
}
