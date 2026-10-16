import 'package:flutter/material.dart';

/// Shared JobiX alert surface. Keeps confirmation semantics in the caller while
/// standardizing safe-area spacing, scrolling, shape, and typography.
class JobixAlertDialog extends StatelessWidget {
  const JobixAlertDialog({
    this.icon,
    this.title,
    this.content,
    this.actions,
    this.semanticLabel,
    super.key,
  });

  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: icon,
    title: title,
    content: content,
    actions: actions,
    semanticLabel: semanticLabel,
    scrollable: true,
    actionsAlignment: MainAxisAlignment.end,
    actionsOverflowAlignment: OverflowBarAlignment.end,
    actionsOverflowDirection: VerticalDirection.down,
    contentPadding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 8),
    actionsPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
  );
}

abstract final class JobixDialogAction {
  static Widget primary({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
  }) => FilledButton(key: key, onPressed: onPressed, child: child);

  static Widget secondary({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
  }) => TextButton(key: key, onPressed: onPressed, child: child);

  static Widget destructive({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
  }) => TextButton(
    key: key,
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: const Color(0xFFB42332)),
    child: child,
  );
}
