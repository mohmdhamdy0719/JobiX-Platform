import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'research_context.dart';

final researchProvider =
    AsyncNotifierProvider<ResearchController, ResearchProgress>(
      ResearchController.new,
    );

class ResearchController extends AsyncNotifier<ResearchProgress> {
  @override
  Future<ResearchProgress> build() async {
    final database = await ref.watch(databaseProvider.future);
    final progress = ResearchProgress.decode(await database.onboarding());
    final completed =
        await database.setting('first_launch_completed') == 'true';
    if (completed) {
      await database.setSetting('first_launch_completed', 'true');
    }
    return progress.copy(
      done: completed || progress.onboardingDone,
      firstLaunchComplete: completed,
    );
  }

  Future<void> persist(ResearchProgress progress) async {
    final database = await ref.read(databaseProvider.future);
    await database.saveOnboarding(progress.encode());
    state = AsyncData(progress);
  }

  Future<void> finishFirstLaunch() async {
    final progress = await future;
    if (!progress.complete) throw StateError('RESEARCH_INCOMPLETE');
    final database = await ref.read(databaseProvider.future);
    final completed = progress.copy(firstLaunchComplete: true);
    await database.transaction(() async {
      await database.setSetting('first_launch_completed', 'true');
      await database.saveOnboarding(completed.encode());
    });
    state = AsyncData(completed);
  }
}
