/// Logger sederhana untuk agent.
library;

/// Level log.
enum LogLevel { debug, info, warning, error }

/// Logger minimal berbasis print. Bisa diganti dengan logging proper.
class AppLogger {
  AppLogger({this.level = LogLevel.info});

  LogLevel level;

  void _log(LogLevel l, String tag, String message) {
    if (l.index < level.index) return;
    final t = DateTime.now().toIso8601String();
    // ignore: avoid_print
    print('[$t][${l.name.toUpperCase()}][$tag] $message');
  }

  void debug(String tag, String message) => _log(LogLevel.debug, tag, message);
  void info(String tag, String message) => _log(LogLevel.info, tag, message);
  void warning(String tag, String message) =>
      _log(LogLevel.warning, tag, message);
  void error(String tag, String message) => _log(LogLevel.error, tag, message);
}
