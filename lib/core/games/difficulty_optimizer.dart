import '../domain/smaran_models.dart';

class DifficultyOptimizer {
  const DifficultyOptimizer();

  double metric(GameHistory game, String key) {
    final value = game.metrics[key];
    return value is num ? value.toDouble() : 0;
  }

  int nextLevel(Iterable<GameHistory> history, {int currentLevel = 1}) {
    final recent = history.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (recent.isEmpty) return currentLevel.clamp(1, 10);

    final sample = recent.take(5).toList();
    final averageAccuracy = sample
      .map((game) => metric(game, 'accuracy'))
        .reduce((a, b) => a + b) /
        sample.length;
    final averageErrors = sample
      .map((game) => metric(game, 'errors'))
        .reduce((a, b) => a + b) /
        sample.length;

    if (averageAccuracy >= .85 && averageErrors <= 1) {
      return (currentLevel + 1).clamp(1, 10);
    }
    if (averageAccuracy < .55 || averageErrors >= 4) {
      return (currentLevel - 1).clamp(1, 10);
    }
    return currentLevel.clamp(1, 10);
  }
}