import 'package:synchronized/synchronized.dart';
import 'dart:async';

// 日誌輸出接口
abstract class LogSink {
  Future<void> write(String message, LogLevel level);
  Future<void> dispose();
}

// 日誌級別枚舉
enum LogLevel {
  critical(0),
  error(1),
  warning(2),
  info(3),
  debug(4),
  verbose(5);

  final int value;
  const LogLevel(this.value);

  @override
  String toString() => name.toUpperCase();
}

// 環境枚舉
enum Environment { development, testing, production }

// 日誌配置類
class LoggerConfig {
  final List<LogSink> sinks;
  final Environment environment;
  final LogLevel initialLevel;

  const LoggerConfig({
    required this.sinks,
    this.environment = Environment.development,
    this.initialLevel = LogLevel.info,
  });
}

// 核心日誌類
class Logger {
  static final _lock = Lock();
  static LogLevel _level = LogLevel.info;
  static Environment _environment = Environment.development;
  static final List<LogSink> _sinks = [];
  static bool _initialized = false;

  // 初始化方法
  static Future<void> init(LoggerConfig config) async {
    // 使用鎖確保線程安全
    await _lock.synchronized(() async {
      if (_initialized) {
        //throw StateError('Logger has already been initialized');
        await dispose();
      }
      
      try {
        _sinks.addAll(config.sinks);
        _environment = config.environment;
        _level = config.initialLevel;
        _initialized = true;
        
        // 只在沒有明確設置日誌級別時應用環境設置
        if (_level == config.initialLevel) {
          _applyEnvironmentLogLevel(_environment);
        }
      } catch (e) {
        // 初始化失敗時清理
        await dispose();
        rethrow;
      }
    });
  }

  static void _applyEnvironmentLogLevel(Environment env) {
    switch (env) {
      case Environment.development:
        _level = LogLevel.verbose;
        break;
      case Environment.testing:
        _level = LogLevel.warning;
        break;
      case Environment.production:
        _level = LogLevel.error;
        break;
    }
  }

  // 環境設置
  static void setEnvironment(Environment env) {
    _environment = env;
    switch (env) {
      case Environment.development:
        _level = LogLevel.verbose;
        break;
      case Environment.testing:
        _level = LogLevel.warning;
        break;
      case Environment.production:
        _level = LogLevel.error;
        break;
    }
  }

  static void setLogLevel(LogLevel newLevel) {
    _level = newLevel;
  }

  // 時間戳生成
  static String _getTimestamp() {
    final dt = DateTime.now();
    return '${dt.year}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}.'
        '${dt.millisecond.toString().padLeft(3, '0')}';
  }

  static Future<void> _log(LogLevel level, String message,
      [Object? error, StackTrace? stackTrace]) async {
    if (!_initialized) {
      throw StateError('Logger has not been initialized');
    }

    await _lock.synchronized(() async {
      if (level.value <= _level.value) {
        final timestamp = _getTimestamp();
        final prefix = '[$timestamp][${level.toString()}]';
        
        final logMessage = _formatLogMessage(prefix, message, error, stackTrace);
        
        // 分別處理每個 sink 的錯誤
        final futures = _sinks.map((sink) async {
          try {
            await sink.write(logMessage, level);
          } catch (e, stackTrace) {
            // 記錄 sink 錯誤但不中斷其他 sink 的操作
            print('Sink error: $e\n$stackTrace');
          }
        });
        
        await Future.wait(futures);
      }
    });
  }

  static String _formatLogMessage(String prefix, String message, 
      Object? error, StackTrace? stackTrace) {
    final buffer = StringBuffer();
    buffer.write('$prefix $message');
    
    if (error != null) {
      buffer.write('\n$prefix Error details: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n$prefix Stack trace:\n$stackTrace');
    }
    
    return buffer.toString();
  }

  // 公開的日誌方法
  static Future<void> critical(String message,
      [Object? error, StackTrace? stackTrace]) async {
    await _log(LogLevel.critical, message, error, stackTrace);
  }

  static Future<void> error(String message,
      [Object? error, StackTrace? stackTrace]) async {
    await _log(LogLevel.error, message, error, stackTrace);
  }

  static Future<void> warning(String message) async {
    await _log(LogLevel.warning, message);
  }

  static Future<void> info(String message) async {
    await _log(LogLevel.info, message);
  }

  static Future<void> debug(String message) async {
    await _log(LogLevel.debug, message);
  }

  static Future<void> verbose(String message) async {
    await _log(LogLevel.verbose, message);
  }

  // 清理資源
  static Future<void> dispose() async {
    await Future.wait(_sinks.map((sink) => sink.dispose()));
    _sinks.clear();
    _initialized = false;
  }
}

// 控制台輸出實現示例
class ConsoleSink implements LogSink {
  @override
  Future<void> write(String message, LogLevel level) async {
    print(message);
  }

  @override
  Future<void> dispose() async {
    // 控制台輸出不需要特殊清理
  }
}
