import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'slice_widgets.dart';
import 'tokens.dart';

class BrandedLoadingState extends StatelessWidget {
  const BrandedLoadingState({this.label, this.onDark = false, super.key});
  final String? label;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TokensV0.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(
              size: onDark ? TokensV0.splashMarkSize : TokensV0.space64,
              dark: !onDark,
            ),
            const SizedBox(height: TokensV0.space24),
            SizedBox(
              width: 190,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: TokensV0.progressHeight,
                  backgroundColor: onDark
                      ? TokensV0.deepBlue
                      : TokensV0.surfaceContainer,
                ),
              ),
            ),
            const SizedBox(height: TokensV0.space16),
            Text(
              label ?? copy.boot,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: onDark
                    ? TokensV0.inverseOnSurface
                    : TokensV0.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandedErrorState extends StatelessWidget {
  const BrandedErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.messageKey,
    super.key,
  });
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final Key? messageKey;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(TokensV0.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 56),
            const SizedBox(height: TokensV0.space20),
            Icon(Icons.error_outline, size: 28, color: TokensV0.error),
            const SizedBox(height: TokensV0.space12),
            Text(
              message,
              key: messageKey,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: TokensV0.textPrimary),
            ),
            const SizedBox(height: TokensV0.space24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NoticePanel extends StatelessWidget {
  const NoticePanel({required this.message, this.error = false, super.key});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final color = error ? TokensV0.error : TokensV0.deepBlue;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(TokensV0.space16),
        decoration: BoxDecoration(
          color: error ? TokensV0.errorContainer : TokensV0.surfaceContainerLow,
          border: BorderDirectional(start: BorderSide(color: color, width: 3)),
          borderRadius: BorderRadius.circular(TokensV0.chipRadius),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: error ? TokensV0.onErrorContainer : TokensV0.deepBlue,
          ),
        ),
      ),
    );
  }
}
