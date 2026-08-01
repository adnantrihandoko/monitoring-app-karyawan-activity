import 'dart:convert';
import 'dart:typed_data';

import 'package:agent_app/core/process_runner.dart';
import 'package:agent_app/features/app_tracker/app_tracker_linux.dart';
import 'package:agent_app/features/idle_detector/idle_detector_linux.dart';
import 'package:agent_app/features/input_tracker/input_tracker_linux.dart';
import 'package:agent_app/features/screenshot/screenshot_capturer_linux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('X11OutputParser', () {
    test('parseActiveWindowId dari output xprop', () {
      const out = '_NET_ACTIVE_WINDOW(WINDOW): window id # 0x2a00007\n';
      expect(X11OutputParser.parseActiveWindowId(out), '0x2a00007');
    });

    test('parseActiveWindowId null saat tidak ada id', () {
      expect(X11OutputParser.parseActiveWindowId('(nil)'), isNull);
    });

    test('parseStringValue dari _NET_WM_NAME', () {
      const out = '_NET_WM_NAME(UTF8_STRING) = "Dokumen - Firefox"\n';
      expect(X11OutputParser.parseStringValue(out), 'Dokumen - Firefox');
    });

    test('parseWmClassAppName mengambil instance name', () {
      const out = 'WM_CLASS(STRING) = "firefox", "Firefox"\n';
      expect(X11OutputParser.parseWmClassAppName(out), 'firefox');
    });
  });

  group('XPrintIdleParser', () {
    test('parse ms dari xprintidle', () {
      expect(XPrintIdleParser.parseMilliseconds('12345\n'), 12345);
      expect(XPrintIdleParser.parseMilliseconds('0'), 0);
    });

    test('parse null saat bukan angka', () {
      expect(XPrintIdleParser.parseMilliseconds(''), isNull);
      expect(XPrintIdleParser.parseMilliseconds('abc'), isNull);
    });
  });

  group('XDotoolLocationParser', () {
    test('parse axis X dan Y', () {
      const out = 'X=1234\nY=567\nSCREEN=0\n';
      expect(XDotoolLocationParser.parseAxis(out, 'X'), 1234);
      expect(XDotoolLocationParser.parseAxis(out, 'Y'), 567);
    });
  });

  group('IdentifyParser', () {
    test('parse dimensi', () {
      expect(IdentifyParser.parseDimensions('1920 1080'), (1920, 1080));
    });

    test('parse null saat format tidak dikenal', () {
      expect(IdentifyParser.parseDimensions('garbage'), isNull);
    });
  });

  group('LinuxAppTracker integration dengan FakeProcessRunner', () {
    test('activeWindow membaca WM_CLASS dan _NET_WM_NAME', () async {
      final runner = FakeProcessRunner(
        responses: {
          'xprop -root _NET_ACTIVE_WINDOW': CommandResult.text(
            exitCode: 0,
            stdout: '_NET_ACTIVE_WINDOW(WINDOW): window id # 0x2a00007\n',
            stderr: '',
          ),
          'xprop -id 0x2a00007 WM_CLASS': CommandResult.text(
            exitCode: 0,
            stdout: 'WM_CLASS(STRING) = "firefox", "Firefox"\n',
            stderr: '',
          ),
          'xprop -id 0x2a00007 _NET_WM_NAME': CommandResult.text(
            exitCode: 0,
            stdout: '_NET_WM_NAME(UTF8_STRING) = "Dokumen - Firefox"\n',
            stderr: '',
          ),
          'xprop -id 0x2a00007 WM_NAME': CommandResult.text(
            exitCode: 1,
            stdout: '',
            stderr: 'not found',
          ),
        },
      );
      final tracker = LinuxAppTracker(runner: runner);
      final info = await tracker.activeWindow();
      expect(info, isNotNull);
      expect(info!.appName, 'firefox');
      expect(info.windowTitle, 'Dokumen - Firefox');
    });

    test('activeWindow null saat xprop root gagal', () async {
      final runner = FakeProcessRunner(
        responses: {
          'xprop -root _NET_ACTIVE_WINDOW': CommandResult.text(
            exitCode: 1,
            stdout: '',
            stderr: 'cannot open display',
          ),
        },
      );
      final tracker = LinuxAppTracker(runner: runner);
      expect(await tracker.activeWindow(), isNull);
    });
  });

  group('LinuxScreenshotCapturer', () {
    test('capture menghasilkan bytes & dimensi', () async {
      final png = Uint8List.fromList(utf8.encode('fake-png-bytes'));
      final runner = FakeProcessRunner(
        responses: {
          'import -window root -quality 80 png:-': CommandResult(
            exitCode: 0,
            stdoutBytes: png,
            stderr: '',
          ),
          'identify -format %w %h png:-': CommandResult.text(
            exitCode: 0,
            stdout: '1920 1080',
            stderr: '',
          ),
        },
      );
      final capturer = LinuxScreenshotCapturer(runner: runner);
      final shot = await capturer.capture();
      expect(shot, isNotNull);
      expect(shot!.width, 1920);
      expect(shot.height, 1080);
      expect(shot.bytes, png);
      expect(shot.format, 'png');
    });

    test('capture null saat import gagal', () async {
      final runner = FakeProcessRunner(
        responses: {
          'import -window root -quality 80 png:-': CommandResult.text(
            exitCode: 1,
            stdout: '',
            stderr: 'no display',
          ),
        },
      );
      final capturer = LinuxScreenshotCapturer(runner: runner);
      expect(await capturer.capture(), isNull);
    });
  });

  group('LinuxIdleDetector', () {
    test('membaca idle ms dari xprintidle', () async {
      final runner = FakeProcessRunner(
        responses: {
          'xprintidle ': CommandResult.text(
            exitCode: 0,
            stdout: '42500\n',
            stderr: '',
          ),
        },
      );
      final detector = LinuxIdleDetector(runner: runner);
      expect(await detector.idleMilliseconds(), 42500);
    });

    test('mengembalikan 0 saat xprintidle tidak tersedia', () async {
      final runner = FakeProcessRunner(
        responses: {
          'xprintidle ': CommandResult.text(
            exitCode: -1,
            stdout: '',
            stderr: 'exec not found',
          ),
        },
      );
      final detector = LinuxIdleDetector(runner: runner);
      expect(await detector.idleMilliseconds(), 0);
    });
  });
}
