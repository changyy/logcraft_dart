import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:logcraft/logcraft.dart';

/// 根據日誌級別分檔的文件輸出實現
class LevelBasedFileSink implements LogSink {
  final Map<LogLevel, IOSink> _sinks = {};
  final String _basePath;

  LevelBasedFileSink(
    String basePath, {
    Set<LogLevel> levels = const {
      LogLevel.error,
      LogLevel.critical,
    },
    bool append = true,
  }) : _basePath = basePath {
    // 為每個指定的級別創建對應的文件輸出
    for (final level in levels) {
      final path = '${_basePath}.${level.name.toLowerCase()}.log';
      print("Creating file for level ${level.name}: $path");
      _sinks[level] =
          File(path).openWrite(mode: append ? FileMode.append : FileMode.write);
    }

    // 創建通用日誌文件
    final generalLogPath = '${_basePath}.log';
    print("Creating general log file: $generalLogPath");
    _sinks[LogLevel.verbose] = File(generalLogPath)
        .openWrite(mode: append ? FileMode.append : FileMode.write);
  }

  @override
  Future<void> write(String message, LogLevel level) async {
    final bytes = utf8.encode('$message\n');

    // 寫入對應級別的專門日誌文件
    if (_sinks.containsKey(level)) {
      print("Writing to ${level.name} log: $message");
      _sinks[level]!.add(bytes);
      await _sinks[level]!.flush();
    }

    // 同時寫入通用日誌文件
    print("Writing to general log: $message");
    _sinks[LogLevel.verbose]!.add(bytes);
    await _sinks[LogLevel.verbose]!.flush();
  }

  @override
  Future<void> dispose() async {
    print("Disposing file sinks");
    for (final sink in _sinks.values) {
      await sink.flush();
      await sink.close();
    }
    _sinks.clear();
  }
}

void main() {
  group('Level-based file logging tests', () {
    late Directory tempDir;
    late String basePath;
    late LevelBasedFileSink fileSink;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('logcraft_test_');
      print("Temp directory created: ${tempDir.path}");
      basePath = '${tempDir.path}/app';

      fileSink = LevelBasedFileSink(
        basePath,
        levels: {LogLevel.error, LogLevel.critical, LogLevel.warning},
      );

      await Logger.init(LoggerConfig(
        sinks: [
          ConsoleSink(),
          fileSink,
        ],
        environment: Environment.development,
      ));
    });

    tearDown(() async {
      await Logger.dispose();
      if (await tempDir.exists()) {
        print("Cleaning up temp directory: ${tempDir.path}");
        await tempDir.delete(recursive: true);
      }
    });

    Future<String?> readLogFile(String suffix) async {
      final path = suffix == 'log'
          ? '$basePath.log' // 通用日誌文件
          : '$basePath.$suffix.log'; // 特定級別的日誌文件

      final file = File(path);
      print("Attempting to read file: ${file.path}");
      if (await file.exists()) {
        final content = await file.readAsString();
        print("File content for $suffix: $content");
        return content;
      }
      print("File not found: ${file.path}");
      return null;
    }

    test('should write to level-specific files', () async {
      await Logger.critical('Critical error message');
      await Logger.error('Error message');
      await Logger.warning('Warning message');
      await Logger.info('Info message');
      await Logger.debug('Debug message');

      // 確保文件寫入完成
      await Future.delayed(Duration(seconds: 1));
      await Logger.dispose();

      final criticalLogs = await readLogFile('critical') ?? '';
      final errorLogs = await readLogFile('error') ?? '';
      final warningLogs = await readLogFile('warning') ?? '';
      final allLogs = await readLogFile('log') ?? '';

      print('Critical logs: $criticalLogs');
      print('Error logs: $errorLogs');
      print('Warning logs: $warningLogs');
      print('All logs: $allLogs');

      expect(criticalLogs.contains('Critical error message'), isTrue,
          reason: 'Critical log file should contain critical message');
      expect(errorLogs.contains('Error message'), isTrue,
          reason: 'Error log file should contain error message');
      expect(warningLogs.contains('Warning message'), isTrue,
          reason: 'Warning log file should contain warning message');

      expect(allLogs.contains('Critical error message'), isTrue,
          reason: 'General log should contain critical message');
      expect(allLogs.contains('Error message'), isTrue,
          reason: 'General log should contain error message');
      expect(allLogs.contains('Warning message'), isTrue,
          reason: 'General log should contain warning message');
      expect(allLogs.contains('Info message'), isTrue,
          reason: 'General log should contain info message');
      expect(allLogs.contains('Debug message'), isTrue,
          reason: 'General log should contain debug message');
    });

    test('should handle errors with stack traces', () async {
      try {
        throw Exception('Test error');
      } catch (e, stack) {
        await Logger.error('Error occurred', e, stack);
      }

      // 確保文件寫入完成
      await Future.delayed(Duration(seconds: 1));
      await Logger.dispose();

      final errorLogs = await readLogFile('error') ?? '';
      final allLogs = await readLogFile('log') ?? '';

      expect(errorLogs.contains('Error occurred'), isTrue,
          reason: 'Error log should contain error message');
      expect(errorLogs.contains('Test error'), isTrue,
          reason: 'Error log should contain error details');
      expect(errorLogs.contains('Stack trace:'), isTrue,
          reason: 'Error log should contain stack trace');

      expect(allLogs.contains('Error occurred'), isTrue,
          reason: 'General log should contain error message');
      expect(allLogs.contains('Test error'), isTrue,
          reason: 'General log should contain error details');
      expect(allLogs.contains('Stack trace:'), isTrue,
          reason: 'General log should contain stack trace');
    });

    test('should respect append mode', () async {
      await Logger.error('First error');
      await Future.delayed(Duration(seconds: 1));
      await Logger.dispose();

      fileSink = LevelBasedFileSink(basePath, append: true);
      await Logger.init(LoggerConfig(
        sinks: [ConsoleSink(), fileSink],
        environment: Environment.development,
      ));

      await Logger.error('Second error');
      await Future.delayed(Duration(seconds: 1));
      await Logger.dispose();

      final errorLogs = await readLogFile('error') ?? '';

      expect(errorLogs.contains('First error'), isTrue,
          reason: 'Error log should contain first message');
      expect(errorLogs.contains('Second error'), isTrue,
          reason: 'Error log should contain second message');
    });

    test('should create new files in write mode', () async {
      await Logger.error('First error');
      await Future.delayed(Duration(seconds: 1));
      await Logger.dispose();

      fileSink = LevelBasedFileSink(basePath, append: false);
      await Logger.init(LoggerConfig(
        sinks: [ConsoleSink(), fileSink],
        environment: Environment.development,
      ));

      await Logger.error('Second error');
      await Future.delayed(Duration(seconds: 1));
      await Logger.dispose();

      final errorLogs = await readLogFile('error') ?? '';

      expect(errorLogs.contains('First error'), isFalse,
          reason: 'Error log should not contain first message');
      expect(errorLogs.contains('Second error'), isTrue,
          reason: 'Error log should contain second message');
    });
  });
}
