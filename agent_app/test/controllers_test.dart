import 'package:agent_app/core/activity_buffer.dart';
import 'package:agent_app/core/app_logger.dart';
import 'package:agent_app/core/runtime_config.dart';
import 'package:agent_app/features/app_tracker/app_tracker.dart';
import 'package:agent_app/features/app_tracker/app_tracker_controller.dart';
import 'package:agent_app/features/idle_detector/idle_detector.dart';
import 'package:agent_app/features/idle_detector/idle_detector_controller.dart';
import 'package:agent_app/features/input_tracker/input_tracker.dart';
import 'package:agent_app/features/input_tracker/input_tracker_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeInputTracker implements InputTracker {
  FakeInputTracker(this.counters);
  InputCounters counters;
  @override
  Future<InputCounters> snapshot() async => counters;
}

class FakeAppTracker implements AppTracker {
  FakeAppTracker(this.windows);
  final List<AppWindowInfo?> windows;
  int index = 0;
  @override
  Future<AppWindowInfo?> activeWindow() async {
    if (index >= windows.length) return null;
    return windows[index++];
  }
}

class FlakyIdleDetector implements IdleDetector {
  FlakyIdleDetector(this.values);
  final List<int> values;
  int index = 0;
  @override
  Future<int> idleMilliseconds() async {
    if (index >= values.length) return values.last;
    return values[index++];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late ActivityBuffer buffer;

  setUp(() async {
    db = await ActivityDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    buffer = ActivityBuffer(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('AppTrackerController', () {
    test('poll pertama membuka sesi tanpa event', () async {
      final controller = AppTrackerController(
        tracker: FakeAppTracker([
          const AppWindowInfo(appName: 'firefox', windowTitle: 'Docs'),
        ]),
        buffer: buffer,
        logger: AppLogger(level: LogLevel.error),
      );
      await controller.poll();
      expect(controller.current, isNotNull);
      expect(controller.current!.appName, 'firefox');
      expect(await buffer.count(), 0);
    });

    test('perubahan window mencatat event active dengan metadata', () async {
      final controller = AppTrackerController(
        tracker: FakeAppTracker([
          const AppWindowInfo(appName: 'firefox', windowTitle: 'Docs'),
          const AppWindowInfo(appName: 'code', windowTitle: 'main.dart'),
        ]),
        buffer: buffer,
        logger: AppLogger(level: LogLevel.error),
      );
      await controller.poll();
      await controller.poll();

      expect(controller.current!.appName, 'code');
      final rows = await buffer.take(10);
      expect(rows, hasLength(1));
      expect(rows.first.activityType, 'active');
      expect(rows.first.metadata?['app_name'], 'firefox');
      expect(rows.first.metadata?['window_title'], 'Docs');
    });

    test('window sama tidak mencatat event baru', () async {
      final controller = AppTrackerController(
        tracker: FakeAppTracker([
          const AppWindowInfo(appName: 'firefox', windowTitle: 'Docs'),
          const AppWindowInfo(appName: 'firefox', windowTitle: 'Docs'),
        ]),
        buffer: buffer,
        logger: AppLogger(level: LogLevel.error),
      );
      await controller.poll();
      await controller.poll();
      expect(await buffer.count(), 0);
    });

    test('closeCurrentSession mencatat durasi sesi terakhir', () async {
      final controller = AppTrackerController(
        tracker: FakeAppTracker([
          const AppWindowInfo(appName: 'firefox', windowTitle: 'Docs'),
        ]),
        buffer: buffer,
        logger: AppLogger(level: LogLevel.error),
      );
      await controller.poll();
      await controller.closeCurrentSession();
      final rows = await buffer.take(10);
      expect(rows, hasLength(1));
      expect(rows.first.metadata?['app_name'], 'firefox');
    });

    test('setPaused menghentikan pencatatan', () async {
      final controller = AppTrackerController(
        tracker: FakeAppTracker([
          const AppWindowInfo(appName: 'firefox', windowTitle: 'Docs'),
          const AppWindowInfo(appName: 'code', windowTitle: 'main.dart'),
        ]),
        buffer: buffer,
        logger: AppLogger(level: LogLevel.error),
      );
      controller.setPaused(true);
      await controller.poll();
      await controller.poll();
      expect(controller.current, isNull);
    });
  });

  group('InputTrackerController', () {
    test('poll menghitung delta dan flush menulis ringkasan', () async {
      final controller = InputTrackerController(
        tracker: FakeInputTracker(
          const InputCounters(
            mouseClicks: 3,
            keyPresses: 5,
            mouseDistance: 100,
          ),
        ),
        buffer: buffer,
        logger: AppLogger(level: LogLevel.error),
      );
      await controller.poll();
      await controller.poll();
      final summary = await controller.flushToBuffer();

      expect(summary, isNotNull);
      expect(
        summary!.mouseClicks,
        1,
        reason: 'kehadiran input per poll dicatat sebagai 1',
      );
      expect(summary.keyPresses, 1);
      expect(summary.mouseDistance, 100);
      expect(await buffer.count(), 1);
      final rows = await buffer.take(10);
      expect(rows.first.activityType, 'active');
      expect(rows.first.metadata?['active'], isTrue);
    });

    test('paused tidak menulis ringkasan', () async {
      final controller = InputTrackerController(
        tracker: FakeInputTracker(const InputCounters.zero()),
        buffer: buffer,
        logger: AppLogger(level: LogLevel.error),
      );
      controller.setPaused(true);
      final summary = await controller.flushToBuffer();
      expect(summary, isNull);
      expect(await buffer.count(), 0);
    });
  });

  group('IdleDetectorController', () {
    test(
      'debounce: butuh N pengecekan berurutan sebelum transisi idle',
      () async {
        final controller = IdleDetectorController(
          detector: FlakyIdleDetector([350000, 350000, 350000]),
          config: RuntimeConfig(
            screenshotIntervalSeconds: 300,
            idleThresholdSeconds: 300,
          ),
          buffer: buffer,
          debounceChecks: 2,
          logger: AppLogger(level: LogLevel.error),
        );

        final r1 = await controller.checkNow();
        expect(r1.state, AgentIdleState.active);

        final r2 = await controller.checkNow();
        expect(r2.state, AgentIdleState.idle);
        expect(controller.isIdle, isTrue);

        final rows = await buffer.take(10);
        expect(rows, hasLength(1));
        expect(rows.first.activityType, 'idle');
        expect(rows.first.metadata?['idle_ms'], 350000);
      },
    );

    test('kembali active setelah idle mencatat event active', () async {
      final controller = IdleDetectorController(
        detector: FlakyIdleDetector([350000, 0]),
        config: RuntimeConfig(
          screenshotIntervalSeconds: 300,
          idleThresholdSeconds: 300,
        ),
        buffer: buffer,
        debounceChecks: 1,
        logger: AppLogger(level: LogLevel.error),
      );

      await controller.checkNow();
      expect(controller.isIdle, isTrue);

      await controller.checkNow();
      expect(controller.isIdle, isFalse);

      final rows = await buffer.take(10);
      expect(rows, hasLength(2));
      expect(rows[0].activityType, 'idle');
      expect(rows[1].activityType, 'active');
      expect(rows[1].metadata?['resumed_from_idle'], isTrue);
    });
  });
}
