import 'package:synchronized/synchronized.dart';
import 'dart:async';

/// Defines an interface for log output destinations.
///
/// Implement this interface to create custom log output handlers
/// that can process and route log messages to different destinations
/// such as console, file, network, etc.
abstract class LogSink {
  /// Writes a log message to the sink.
  ///
  /// [message] The formatted log message to be written
  /// [level] The severity level of the log message
  Future<void> write(String message, LogLevel level);

  /// Releases any resources held by the sink.
  ///
  /// This method should be called when the sink is no longer needed
  /// to ensure proper cleanup of resources.
  Future<void> dispose();
}

/// Defines the severity levels for log messages.
///
/// Log levels are ordered from most severe (critical) to least severe (verbose).
/// Each level has an associated integer value that can be used for comparison.
enum LogLevel {
  /// System is unusable, immediate attention required
  critical(0),

  /// Error conditions that should be addressed
  error(1),

  /// Warning messages for potentially harmful situations
  warning(2),

  /// General informational messages
  info(3),

  /// Detailed debug information
  debug(4),

  /// Highly detailed tracing information
  verbose(5);

  /// The numeric value associated with this log level
  final int value;

  const LogLevel(this.value);

  @override
  String toString() => name.toUpperCase();
}

/// Defines the execution environment of the application.
///
/// Different environments can have different logging configurations
/// appropriate for their use case.
enum Environment {
  /// Development environment with verbose logging
  development,

  /// Testing environment with moderate logging
  testing,

  /// Production environment with minimal logging
  production
}

/// Configuration settings for the logger system.
///
/// This class holds all the necessary configuration parameters
/// to initialize the logging system with the desired behavior.
class LoggerConfig {
  /// List of sinks where log messages will be written
  final List<LogSink> sinks;

  /// The execution environment setting
  final Environment environment;

  /// The initial logging level
  final LogLevel initialLevel;

  /// Creates a new logger configuration.
  ///
  /// [sinks] List of output destinations for log messages
  /// [environment] The execution environment, defaults to development
  /// [initialLevel] The initial log level, defaults to info
  ///
  /// Example:
  /// ```dart
  /// final config = LoggerConfig(
  ///   sinks: [ConsoleSink()],
  ///   environment: Environment.development,
  ///   initialLevel: LogLevel.debug,
  /// );
  /// ```
  const LoggerConfig({
    required this.sinks,
    this.environment = Environment.development,
    this.initialLevel = LogLevel.info,
  });
}

/// A static logging utility class that provides thread-safe logging capabilities.
///
/// The Logger class manages log message routing to configured sinks with
/// support for different log levels and environments. It ensures thread-safety
/// using synchronization locks.
class Logger {
  static final _lock = Lock();
  static LogLevel _level = LogLevel.info;
  static Environment _environment = Environment.development;
  static final List<LogSink> _sinks = [];
  static bool _initialized = false;

  /// Initializes the logging system with the provided configuration.
  ///
  /// This method must be called before using any logging functions.
  /// Subsequent calls will dispose of the existing configuration before
  /// applying the new one.
  ///
  /// [config] The configuration settings for the logger
  ///
  /// Example:
  /// ```dart
  /// await Logger.init(LoggerConfig(
  ///   sinks: [ConsoleSink()],
  ///   environment: Environment.development,
  /// ));
  /// ```
  static Future<void> init(LoggerConfig config) async {
    await _lock.synchronized(() async {
      if (_initialized) {
        await dispose();
      }

      try {
        _sinks.addAll(config.sinks);
        _environment = config.environment;
        _level = config.initialLevel;
        _initialized = true;

        if (_level == config.initialLevel) {
          _applyEnvironmentLogLevel(_environment);
        }
      } catch (e) {
        await dispose();
        rethrow;
      }
    });
  }

  /// Applies the appropriate log level for the given environment.
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

  /// Sets the execution environment and adjusts log level accordingly.
  ///
  /// [env] The new environment setting to apply
  static void setEnvironment(Environment env) {
    _environment = env;
    _applyEnvironmentLogLevel(env);
  }

  /// Sets the minimum log level that will be processed.
  ///
  /// [newLevel] The new minimum log level
  static void setLogLevel(LogLevel newLevel) {
    _level = newLevel;
  }

  /// Generates a timestamp string for log messages.
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

  /// Internal logging implementation.
  static Future<void> _log(LogLevel level, String message,
      [Object? error, StackTrace? stackTrace]) async {
    if (!_initialized) {
      return;
    }

    await _lock.synchronized(() async {
      if (level.value <= _level.value) {
        final timestamp = _getTimestamp();
        final prefix = '[$timestamp][${level.toString()}]';

        final logMessage =
            _formatLogMessage(prefix, message, error, stackTrace);

        final futures = _sinks.map((sink) async {
          try {
            await sink.write(logMessage, level);
          } catch (e, stackTrace) {
            print('Sink error: $e\n$stackTrace');
          }
        });

        await Future.wait(futures);
      }
    });
  }

  /// Formats a log message with optional error and stack trace information.
  static String _formatLogMessage(
      String prefix, String message, Object? error, StackTrace? stackTrace) {
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

  /// Logs a critical message.
  ///
  /// [message] The message to log
  /// [error] Optional error object
  /// [stackTrace] Optional stack trace
  static Future<void> critical(String message,
      [Object? error, StackTrace? stackTrace]) async {
    await _log(LogLevel.critical, message, error, stackTrace);
  }

  /// Logs an error message.
  ///
  /// [message] The message to log
  /// [error] Optional error object
  /// [stackTrace] Optional stack trace
  static Future<void> error(String message,
      [Object? error, StackTrace? stackTrace]) async {
    await _log(LogLevel.error, message, error, stackTrace);
  }

  /// Logs a warning message.
  ///
  /// [message] The message to log
  static Future<void> warning(String message) async {
    await _log(LogLevel.warning, message);
  }

  /// Logs an informational message.
  ///
  /// [message] The message to log
  static Future<void> info(String message) async {
    await _log(LogLevel.info, message);
  }

  /// Logs a debug message.
  ///
  /// [message] The message to log
  static Future<void> debug(String message) async {
    await _log(LogLevel.debug, message);
  }

  /// Logs a verbose message.
  ///
  /// [message] The message to log
  static Future<void> verbose(String message) async {
    await _log(LogLevel.verbose, message);
  }

  /// Disposes of all sinks and resets the logger.
  ///
  /// This method should be called when the logger is no longer needed
  /// or before reinitializing with a new configuration.
  static Future<void> dispose() async {
    await Future.wait(_sinks.map((sink) => sink.dispose()));
    _sinks.clear();
    _initialized = false;
  }
}

/// A basic implementation of [LogSink] that writes to the console.
///
/// This sink implements simple console output for log messages using
/// the standard print function.
class ConsoleSink implements LogSink {
  /// Writes a log message to the console.
  ///
  /// [message] The formatted message to write
  /// [level] The severity level of the message
  @override
  Future<void> write(String message, LogLevel level) async {
    print(message);
  }

  /// Cleanup method (no-op for console output).
  @override
  Future<void> dispose() async {
    // No cleanup needed for console output
  }
}
