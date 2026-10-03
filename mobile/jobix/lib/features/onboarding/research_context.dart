import 'dart:convert';

const researchOptions = <List<String>>[
  [
    'student',
    'graduate',
    'early',
    'mid',
    'experienced',
    'returning',
    'changer',
  ],
  ['first_job', 'better_job', 'change', 'advance', 'prepare', 'unsure'],
  ['city', 'country', 'remote', 'abroad', 'multiple', 'unsure'],
  ['cv', 'opportunities', 'paths', 'online', 'skills', 'interviews'],
];

class ResearchProgress {
  const ResearchProgress({
    this.onboardingPage = 0,
    this.onboardingDone = false,
    this.stage,
    this.goal,
    this.location,
    this.help = const [],
    this.mergedUser,
    this.commandKey,
  });
  final int onboardingPage;
  final bool onboardingDone;
  final String? stage, goal, location, mergedUser, commandKey;
  final List<String> help;
  int get question => stage == null
      ? 0
      : goal == null
      ? 1
      : location == null
      ? 2
      : 3;
  bool get complete =>
      stage != null && goal != null && location != null && help.isNotEmpty;

  Map<String, dynamic> get answers => {
    'career_stage': stage,
    'career_goal': goal,
    'desired_work_location': location,
    'help_areas': help,
  };
  String encode() => jsonEncode({
    ...answers,
    'page': onboardingPage,
    'done': onboardingDone,
    'merged': mergedUser,
    'key': commandKey,
  });
  factory ResearchProgress.decode(String? source) {
    if (source == null) return const ResearchProgress();
    final data = jsonDecode(source) as Map<String, dynamic>;
    return ResearchProgress(
      onboardingPage: data['page'] as int? ?? 0,
      onboardingDone: data['done'] == true,
      stage: data['career_stage'] as String?,
      goal: data['career_goal'] as String?,
      location: data['desired_work_location'] as String?,
      help: List<String>.from(data['help_areas'] as List? ?? []),
      mergedUser: data['merged'] as String?,
      commandKey: data['key'] as String?,
    );
  }
  ResearchProgress copy({
    int? page,
    bool? done,
    String? stage,
    String? goal,
    String? location,
    List<String>? help,
    String? mergedUser,
    String? commandKey,
  }) => ResearchProgress(
    onboardingPage: page ?? onboardingPage,
    onboardingDone: done ?? onboardingDone,
    stage: stage ?? this.stage,
    goal: goal ?? this.goal,
    location: location ?? this.location,
    help: help ?? this.help,
    mergedUser: mergedUser ?? this.mergedUser,
    commandKey: commandKey ?? this.commandKey,
  );
  ResearchProgress select(int question, String value) {
    if (!researchOptions[question].contains(value)) {
      throw ArgumentError('Invalid option');
    }
    if (question == 3) {
      final selected = [...help];
      if (selected.contains(value)) {
        selected.remove(value);
      } else if (selected.length < 3) {
        selected.add(value);
      }
      return copy(help: selected);
    }
    return switch (question) {
      0 => copy(stage: value),
      1 => copy(goal: value),
      _ => copy(location: value),
    };
  }
}
