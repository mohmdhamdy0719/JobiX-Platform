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

/// Transport/read/storage failures do not prove a mutation was submitted.
/// Reserve the uncertainty guard for an actual durable submitted request.
Future<SaveIssue> confirmedSaveIssue(
  Object error,
  EntityRepository repository,
  String profile,
) async {
  final issue = saveIssue(error);
  if (issue != SaveIssue.unknown) return issue;
  try {
    return await repository.pending(profile) != null
        ? SaveIssue.unknown
        : SaveIssue.rejected;
  } catch (_) {
    return SaveIssue.rejected;
  }
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
