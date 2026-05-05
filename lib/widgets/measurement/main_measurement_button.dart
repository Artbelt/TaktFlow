import 'package:flutter/material.dart';

/// Главная кнопка замера: ripple от Material, лёгкое масштабирование при нажатии.
class MainMeasurementButton extends StatefulWidget {
  const MainMeasurementButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.labelKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final Key? labelKey;

  @override
  State<MainMeasurementButton> createState() => _MainMeasurementButtonState();
}

class _MainMeasurementButtonState extends State<MainMeasurementButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canPress = widget.enabled && widget.onPressed != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
        child: AnimatedScale(
          scale: (_pressed && canPress) ? 0.982 : 1,
          duration: const Duration(milliseconds: 95),
          curve: Curves.easeOut,
          child: Listener(
            onPointerDown: (_) {
              if (canPress) setState(() => _pressed = true);
            },
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: SizedBox(
              width: double.infinity,
              height: 78,
              child: Material(
                color: canPress ? (scheme.primary) : scheme.primary.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  splashColor: scheme.onPrimary.withValues(alpha: 0.22),
                  highlightColor: scheme.onPrimary.withValues(alpha: 0.06),
                  onTap: canPress ? widget.onPressed : null,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        widget.label,
                        key: widget.labelKey,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          color: canPress ? scheme.onPrimary : scheme.onPrimary.withValues(alpha: 0.65),
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
