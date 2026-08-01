import 'package:agent_app/features/input_tracker/input_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InputAggregator', () {
    test('akumulasi dan flush menghasilkan summary', () {
      var t = DateTime.utc(2026, 8, 1, 9, 0, 0);
      final agg = InputAggregator(now: () => t);

      agg.recordClick();
      agg.recordKeyPress();
      agg.recordKeyPress();
      agg.recordDistance(10);
      agg.recordDistance(20);

      t = DateTime.utc(2026, 8, 1, 9, 1, 0);
      final summary = agg.flush();

      expect(summary.mouseClicks, 1);
      expect(summary.keyPresses, 2);
      expect(summary.mouseDistance, closeTo(30, 0.001));
      expect(summary.startedAt, DateTime.utc(2026, 8, 1, 9, 0, 0));
      expect(summary.durationSeconds, closeTo(60, 0.001));
      expect(summary.hasActivity, isTrue);
      expect(summary.toMetadata()['active'], isTrue);
      expect(summary.toMetadata()['mouse_clicks'], 1);
    });

    test('flush mereset counter', () {
      final agg = InputAggregator();
      agg.recordClick();
      agg.recordKeyPress();
      final first = agg.flush();
      expect(first.mouseClicks, 1);

      final second = agg.flush();
      expect(second.mouseClicks, 0);
      expect(second.keyPresses, 0);
      expect(second.hasActivity, isFalse);
    });

    test('recordDistance mengabaikan nilai negatif/non-finite', () {
      final agg = InputAggregator();
      agg.recordDistance(-5);
      agg.recordDistance(double.nan);
      agg.recordDistance(double.infinity);
      final summary = agg.flush();
      expect(summary.mouseDistance, 0);
    });
  });
}
