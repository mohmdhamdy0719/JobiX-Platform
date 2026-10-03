import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'research_context.dart';

final researchProvider =
    AsyncNotifierProvider<ResearchController, ResearchProgress>(
      ResearchController.new,
    );

class ResearchController extends AsyncNotifier<ResearchProgress> {
  @override
  Future<ResearchProgress> build() async => ResearchProgress.decode(
    await (await ref.watch(databaseProvider.future)).onboarding(),
  );
  Future<void> persist(ResearchProgress progress) async {
    final database = await ref.read(databaseProvider.future);
    await database.saveOnboarding(progress.encode());
    state = AsyncData(progress);
  }
}
