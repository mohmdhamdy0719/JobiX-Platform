import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'slice_widgets.dart';
import 'tokens.dart';

/// Stable native skeleton: reflects the form layout without layout jumps,
/// continuous animation, or guessed content.
class FormLoadingState extends StatelessWidget {
  const FormLoadingState({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context)!.localeName.startsWith('ar')
        ? 'جار تحميل الملف'
        : 'Loading profile',
    child: ExcludeSemantics(
      child: SliceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final width in [
              140.0,
              double.infinity,
              double.infinity,
              200.0,
            ])
              Container(
                width: width,
                height: width == 140 ? 20 : 44,
                margin: const EdgeInsetsDirectional.only(
                  bottom: TokensV0.space16,
                ),
                decoration: BoxDecoration(
                  color: TokensV0.secondarySurface,
                  borderRadius: BorderRadius.circular(TokensV0.controlRadius),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
