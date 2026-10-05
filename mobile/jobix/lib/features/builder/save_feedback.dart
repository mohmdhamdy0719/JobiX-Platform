import '../../l10n/app_localizations.dart';
import '../career_profile/entity_repository.dart';

enum SaveIssue { pending, conflict, duplicate, missing, rejected, unknown }

SaveIssue saveIssue(Object error) {
  if (error is PendingSaveException) return SaveIssue.pending;
  return switch (rejectionCode(error)) {
    'VERSION_CONFLICT' => SaveIssue.conflict,
    'DUPLICATE_ITEM' => SaveIssue.duplicate,
    'ITEM_NOT_FOUND' => SaveIssue.missing,
    null => SaveIssue.unknown,
    _ => SaveIssue.rejected,
  };
}

String saveIssueText(AppLocalizations copy, SaveIssue issue) => switch (issue) {
  SaveIssue.pending => copy.savePending,
  SaveIssue.conflict => copy.saveConflict,
  SaveIssue.duplicate => copy.duplicateItem,
  SaveIssue.missing => copy.itemNotFound,
  SaveIssue.rejected => copy.saveFailed,
  // Outcome unknown: the request is kept and retried with the same key.
  SaveIssue.unknown => copy.outcomeUnknown,
};
