import 'package:flutter/material.dart';

import 'tokens.dart';

enum JobixFeedbackKind { success, warning, error }

/// Replaces the active notice instead of building an unbounded snackbar queue.
void showJobixFeedback(
  BuildContext context,
  String message, {
  JobixFeedbackKind kind = JobixFeedbackKind.success,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.removeCurrentSnackBar();
  messenger.clearSnackBars();
  final (background, foreground, icon) = switch (kind) {
    JobixFeedbackKind.success => (
      const Color(0xFFE8F5EE),
      TokensV0.success,
      Icons.check_circle_outline,
    ),
    JobixFeedbackKind.warning => (
      const Color(0xFFFFF2D6),
      TokensV0.warning,
      Icons.info_outline,
    ),
    JobixFeedbackKind.error => (
      TokensV0.errorContainer,
      TokensV0.onErrorContainer,
      Icons.error_outline,
    ),
  };
  messenger.showSnackBar(
    SnackBar(
      key: ValueKey('jobix-feedback-${kind.name}'),
      content: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: TokensV0.space8),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      // Keep floating feedback above fixed bottom actions and Android's
      // gesture/navigation inset rather than intercepting the primary CTA.
      margin: EdgeInsetsDirectional.fromSTEB(
        12,
        0,
        12,
        84 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TokensV0.controlRadius),
        side: const BorderSide(color: TokensV0.border),
      ),
    ),
  );
}
