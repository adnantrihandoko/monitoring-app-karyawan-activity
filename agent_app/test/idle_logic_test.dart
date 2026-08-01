import 'package:agent_app/core/idle_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdleLogic', () {
    test('belum idle saat durasi di bawah threshold', () {
      expect(
        IdleLogic.isIdle(idleMilliseconds: 100, thresholdMilliseconds: 300000),
        isFalse,
      );
    });

    test('idle saat durasi sama dengan threshold (boundary)', () {
      expect(
        IdleLogic.isIdle(
          idleMilliseconds: 300000,
          thresholdMilliseconds: 300000,
        ),
        isTrue,
      );
    });

    test('idle saat melebihi threshold', () {
      expect(
        IdleLogic.isIdle(
          idleMilliseconds: 300001,
          thresholdMilliseconds: 300000,
        ),
        isTrue,
      );
    });

    test('evaluate menghasilkan evaluasi lengkap', () {
      final eval = IdleLogic.evaluate(
        idleMilliseconds: 350000,
        thresholdMilliseconds: 300000,
      );
      expect(eval.isIdle, isTrue);
      expect(eval.idleMilliseconds, 350000);
      expect(eval.thresholdMilliseconds, 300000);
    });

    test('idleDurationSeconds konversi ms ke detik', () {
      expect(IdleLogic.idleDurationSeconds(300000), 300.0);
      expect(IdleLogic.idleDurationSeconds(0), 0.0);
    });
  });
}
