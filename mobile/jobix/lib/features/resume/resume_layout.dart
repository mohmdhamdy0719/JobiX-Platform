import 'dart:convert';

/// Stable profile section IDs. Defaults never remove profile content.
class ResumeLayout {
  ResumeLayout({
    List<String> order = sectionKeys,
    Set<String> hidden = const {},
  }) : order = List.unmodifiable(order),
       hidden = Set.unmodifiable(hidden) {
    if (order.length != sectionKeys.length ||
        order.toSet().length != sectionKeys.length ||
        !order.every(sectionKeys.contains) ||
        !hidden.every(sectionKeys.contains)) {
      throw ArgumentError('INVALID_RESUME_LAYOUT');
    }
  }

  static const sectionKeys = [
    'summary',
    'target_role',
    'experience',
    'volunteer',
    'education',
    'certification',
    'achievement',
    'project',
    'skill',
    'language',
  ];
  static const renderVersion = 'export-layout-v1';
  static const templateVersion = 3;
  final List<String> order;
  final Set<String> hidden;

  factory ResumeLayout.fromConfiguration(Map<String, dynamic> configuration) {
    final visibility = configuration['section_visibility'] as Map? ?? {};
    final stored = configuration['section_order'] as List?;
    // Legacy profiles keep their relative order; Target Role used to be part
    // of the personal header and was not represented in section_order.
    final order = stored == null ? [...sectionKeys] : List<String>.from(stored);
    if (!order.contains('target_role')) {
      order.insert(
        order.contains('summary') ? order.indexOf('summary') + 1 : 0,
        'target_role',
      );
    }
    return ResumeLayout(
      order: order,
      hidden: {
        for (final key in visibility.keys)
          if (visibility[key] == false) key as String,
      },
    );
  }

  Map<String, dynamic> get visibility => {
    for (final key in sectionKeys)
      if (hidden.contains(key)) key: false,
  };
  String get fingerprint => jsonEncode([
    order,
    [...hidden]..sort(),
  ]);
  ResumeLayout toggle(String key, bool enabled) => ResumeLayout(
    order: order,
    hidden: {...hidden}
      ..removeWhere((value) => value == key && enabled)
      ..addAll(enabled ? const <String>[] : [key]),
  );
  ResumeLayout reorder(int oldIndex, int newIndex) {
    final next = [...order];
    if (newIndex > oldIndex) newIndex--;
    next.insert(newIndex, next.removeAt(oldIndex));
    return ResumeLayout(order: next, hidden: hidden);
  }
}
