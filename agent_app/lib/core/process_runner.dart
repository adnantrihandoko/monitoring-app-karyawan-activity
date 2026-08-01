/// Abstraksi menjalankan proses eksternal agar mudah diuji (fake runner).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Hasil menjalankan perintah eksternal.
class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdoutBytes,
    required this.stderr,
  });

  CommandResult.text({
    required this.exitCode,
    required String stdout,
    required this.stderr,
  }) : stdoutBytes = Uint8List.fromList(utf8.encode(stdout));

  final int exitCode;
  final Uint8List stdoutBytes;
  final String stderr;

  bool get isSuccess => exitCode == 0;

  /// Output stdout sebagai teks (best-effort utf8).
  String get stdout => utf8.decode(stdoutBytes, allowMalformed: true);
}

/// Runner proses eksternal (dapat di-inject fake di unit test).
abstract class ProcessRunner {
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });
}

/// Implementasi nyata memakai `Process.run` (mendukung output binary).
class RealProcessRunner implements ProcessRunner {
  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        stdoutEncoding: null, // ambil bytes mentah (bisa PNG dll.)
        stderrEncoding: utf8,
      );
      final stdoutBytes = result.stdout is List<int>
          ? Uint8List.fromList(result.stdout as List<int>)
          : Uint8List.fromList(utf8.encode(result.stdout.toString()));
      return CommandResult(
        exitCode: result.exitCode,
        stdoutBytes: stdoutBytes,
        stderr: result.stderr?.toString() ?? '',
      );
    } on ProcessException catch (e) {
      return CommandResult(
        exitCode: -1,
        stdoutBytes: Uint8List(0),
        stderr: 'ProcessException: ${e.message}',
      );
    }
  }
}

/// Fake runner untuk unit test — mengembalikan hasil yang sudah ditentukan.
class FakeProcessRunner implements ProcessRunner {
  FakeProcessRunner({Map<String, CommandResult>? responses, this.onRun})
    : responses = responses ?? {};

  /// Peta command → hasil (key: "exe arg1 arg2...").
  final Map<String, CommandResult> responses;

  /// Callback opsional untuk merekam panggilan / mengubah hasil dinamis.
  final Future<CommandResult> Function(String exe, List<String> args)? onRun;

  final List<(String, List<String>)> calls = [];

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    calls.add((executable, arguments));
    if (onRun != null) {
      return onRun!(executable, arguments);
    }
    final key = '$executable ${arguments.join(' ')}';
    return responses[key] ??
        CommandResult.text(exitCode: 0, stdout: '', stderr: '');
  }
}
