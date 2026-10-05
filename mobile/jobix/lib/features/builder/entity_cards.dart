import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../career_profile/profile_sections.dart';
import 'entity_labels.dart';

Future<bool> confirmRemove(BuildContext context) async {
  final copy = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(copy.removeTitle),
          content: Text(copy.removeBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(copy.cancelAction),
            ),
            TextButton(
              key: const Key('confirm-remove'),
              style: TextButton.styleFrom(foregroundColor: TokensV0.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text(copy.removeAction),
            ),
          ],
        ),
      ) ??
      false;
}

/// One reusable list for every repeatable section: cards with status,
/// present indicator, expand, edit/remove menu, and an add action.
class EntityCardList extends StatelessWidget {
  const EntityCardList({
    required this.section,
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
    this.unsaved = const [],
    this.showHeading = true,
    this.enabled = true,
    super.key,
  });
  final EntitySection section;
  final List<ProfileItem> items, unsaved;
  final VoidCallback onAdd;
  final ValueChanged<ProfileItem> onEdit, onRemove;
  final bool showHeading, enabled;

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: TokensV0.space8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sectionTitle(copy, section),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (items.isNotEmpty)
                  Text(
                    copy.itemsAdded(items.length),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: TokensV0.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        if (items.isEmpty && unsaved.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: TokensV0.space8),
            child: Text(
              section == EntitySection.experience
                  ? copy.emptyExperience
                  : copy.emptySection,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: TokensV0.textSecondary,
              ),
            ),
          ),
        for (final item in items)
          _EntityCard(
            item: item,
            enabled: enabled,
            onEdit: () => onEdit(item),
            onRemove: () => onRemove(item),
          ),
        for (final item in unsaved)
          _EntityCard(
            item: item,
            enabled: enabled,
            unsaved: true,
            onEdit: () => onEdit(item),
            onRemove: null,
          ),
        const SizedBox(height: TokensV0.space4),
        OutlinedButton.icon(
          key: Key('add-${section.key}'),
          onPressed: enabled ? onAdd : null,
          icon: const Icon(Icons.add_circle_outline),
          label: Text(addLabel(copy, section)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: TokensV0.primary,
            side: const BorderSide(color: TokensV0.border),
            backgroundColor: TokensV0.surfaceCard,
          ),
        ),
      ],
    );
  }
}

class _EntityCard extends StatefulWidget {
  const _EntityCard({
    required this.item,
    required this.onEdit,
    required this.onRemove,
    required this.enabled,
    this.unsaved = false,
  });
  final ProfileItem item;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;
  final bool enabled, unsaved;
  @override
  State<_EntityCard> createState() => _EntityCardState();
}

class _EntityCardState extends State<_EntityCard> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final item = widget.item;
    final title = itemTitle(item);
    final subtitle = itemSubtitle(copy, item, locale);
    final description = item.text('description');
    final complete = widget.unsaved ? false : item.complete;
    final current = item.section.hasCurrent && item.flag('is_current');
    return Card(
      key: Key('card-${item.section.key}-${item.id}'),
      margin: const EdgeInsetsDirectional.only(bottom: TokensV0.space12),
      elevation: 0,
      color: TokensV0.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TokensV0.cardRadius),
        side: const BorderSide(color: TokensV0.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(TokensV0.cardRadius),
        onTap: description.isEmpty
            ? null
            : () => setState(() => expanded = !expanded),
        child: Padding(
          padding: const EdgeInsets.all(TokensV0.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: TokensV0.surfaceContainerLow,
                    foregroundColor: TokensV0.deepBlue,
                    child: Text(
                      title.isEmpty ? '•' : initials(title),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: TokensV0.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title.isEmpty ? copy.notProvided : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (current) ...[
                              const SizedBox(width: TokensV0.space8),
                              _Badge(
                                label: copy.presentLabel,
                                color: TokensV0.primary,
                              ),
                            ],
                          ],
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: TokensV0.textSecondary,
                            ),
                          ),
                        const SizedBox(height: TokensV0.space4),
                        _Badge(
                          label: widget.unsaved
                              ? copy.notSavedYet
                              : complete
                              ? copy.itemComplete
                              : copy.itemIncomplete,
                          color: complete ? TokensV0.success : TokensV0.warning,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: Key('menu-${item.section.key}-${item.id}'),
                    tooltip: copy.moreActions,
                    enabled: widget.enabled,
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (value) => value == 'edit'
                        ? widget.onEdit()
                        : widget.onRemove?.call(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(copy.editAction),
                      ),
                      if (widget.onRemove != null)
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(copy.removeAction),
                        ),
                    ],
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: TokensV0.space8),
                Text(
                  description,
                  maxLines: expanded ? null : 2,
                  overflow: expanded ? null : TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(TokensV0.chipRadius),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
