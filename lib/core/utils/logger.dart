// lib/core/utils/logger.dart

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class Logger {
  static bool isEnabled = true;
  static LogLevel minLevel = LogLevel.debug;

  static void debug(String message, {String? tag}) {
    if (isEnabled && minLevel.index <= LogLevel.debug.index) {
      _log('🐛 DEBUG', message, tag: tag);
    }
  }

  static void info(String message, {String? tag}) {
    if (isEnabled && minLevel.index <= LogLevel.info.index) {
      _log('ℹ️ INFO', message, tag: tag);
    }
  }

  static void warning(String message, {String? tag}) {
    if (isEnabled && minLevel.index <= LogLevel.warning.index) {
      _log('⚠️ WARNING', message, tag: tag);
    }
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (isEnabled && minLevel.index <= LogLevel.error.index) {
      _log('❌ ERROR', message, tag: tag);
      if (error != null) {
        _log('❌ ERROR', '  → $error', tag: tag);
      }
      if (stackTrace != null) {
        _log('❌ ERROR', '  → $stackTrace', tag: tag);
      }
    }
  }

  static void _log(String level, String message, {String? tag}) {
    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag] ' : '';
    print('$timestamp $level $tagStr$message');
  }

  // ✅ دالة خاصة لتتبع الترجمة
  static void translation(String key, {String? locale}) {
    if (isEnabled) {
      print('🌍 TRANSLATION [${locale ?? 'default'}] "$key"');
    }
  }

  // ✅ دالة خاصة لتتبع الترخيص
  static void license(String message, {String? code}) {
    if (isEnabled) {
      final codeStr = code != null ? ' (code: ${code.substring(0, code.length > 20 ? 20 : code.length)}...)' : '';
      print('🔑 LICENSE $message$codeStr');
    }
  }
}