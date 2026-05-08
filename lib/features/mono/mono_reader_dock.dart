import 'package:flutter/material.dart';

class MonoReaderDock extends StatelessWidget {
  const MonoReaderDock({
    super.key,
    required this.onAddMono,
    this.onMenu,
  });

  final VoidCallback onAddMono;

  /// Owner profile menu (edit/delete/unsave). When null, dock shows **Add Mono** only.
  final VoidCallback? onMenu;

  static const double _barHeight = 74.0;

  static double occupiedHeight(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return _barHeight + bottom;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _barHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B1A18),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    onPressed: onAddMono,
                    child: const Text('Add Mono +'),
                  ),
                ),
              ),
              if (onMenu != null) ...[
                const SizedBox(width: 12),
                SizedBox(
                  height: 54,
                  width: 54,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onMenu,
                      child: Icon(
                        Icons.menu_rounded,
                        color: Colors.black.withValues(alpha: 0.84),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
