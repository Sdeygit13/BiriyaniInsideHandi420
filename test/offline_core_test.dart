import 'package:flutter_test/flutter_test.dart';
import 'package:smaran_flutter/core/domain/smaran_models.dart';
import 'package:smaran_flutter/core/games/difficulty_optimizer.dart';
import 'package:smaran_flutter/core/sync/sync_queue.dart';

void main() {
  test('difficulty increases after accurate low-error sessions', () {
    final now = DateTime(2026, 9, 11);
    final history = List.generate(
      3,
      (index) => GameHistory(
        gameId: 'memory',
        score: 90,
        metrics: const {'accuracy': .9, 'errors': 0},
        difficultyLevel: 2,
        timestamp: now.subtract(Duration(days: index)),
      ),
    );

    expect(DifficultyOptimizer().nextLevel(history, currentLevel: 2), 3);
  });

  test('sync queue retains items when offline and flushes when online', () async {
    final queue = OfflineFirstSyncQueue();
    final item = SyncQueueItem(
      id: 'log-1',
      tableName: 'interaction_logs',
      payloadJson: '{}',
    );
    queue.enqueue(item);
    var sent = 0;
    final transport = _TestTransport(() async => sent++);

    await queue.flush(transport, online: false);
    expect(queue.pendingItems, hasLength(1));

    await queue.flush(transport, online: true);
    expect(sent, 1);
    expect(item.status, SyncStatus.synced);
  });
}

class _TestTransport implements SyncTransport {
  final Future<void> Function() callback;

  const _TestTransport(this.callback);

  @override
  Future<void> send(SyncQueueItem item) => callback();
}