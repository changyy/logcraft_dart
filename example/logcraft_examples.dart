import 'package:logcraft/logcraft.dart';
import 'dart:io';
import 'dart:convert';

/// 用於檔案輸出的簡單實現
class FileSink implements LogSink {
  final IOSink _sink;

  FileSink(String path) : _sink = File(path).openWrite(mode: FileMode.append);

  @override
  Future<void> write(String message, LogLevel level) async {
    _sink.writeln(message);
    await _sink.flush();
  }

  @override
  Future<void> dispose() async {
    await _sink.flush();
    await _sink.close();
  }
}

/// 根據日誌級別分檔的實現
class LevelBasedFileSink implements LogSink {
  final Map<LogLevel, IOSink> _sinks = {};
  final String _basePath;

  LevelBasedFileSink(
    String basePath, {
    Set<LogLevel> levels = const {
      LogLevel.error,
      LogLevel.warning,
      LogLevel.info,
    },
    bool append = true,
  }) : _basePath = basePath {
    // 為每個指定的級別創建對應的文件輸出
    for (final level in levels) {
      final path = '${_basePath}.${level.name.toLowerCase()}.log';
      _sinks[level] =
          File(path).openWrite(mode: append ? FileMode.append : FileMode.write);
    }

    // 創建通用日誌文件
    _sinks[LogLevel.verbose] = File('${_basePath}.log')
        .openWrite(mode: append ? FileMode.append : FileMode.write);
  }

  @override
  Future<void> write(String message, LogLevel level) async {
    final bytes = utf8.encode('$message\n');

    // 寫入對應級別的專門日誌文件
    if (_sinks.containsKey(level)) {
      _sinks[level]!.add(bytes);
      await _sinks[level]!.flush();
    }

    // 同時寫入通用日誌文件
    _sinks[LogLevel.verbose]!.add(bytes);
    await _sinks[LogLevel.verbose]!.flush();
  }

  @override
  Future<void> dispose() async {
    for (final sink in _sinks.values) {
      await sink.flush();
      await sink.close();
    }
    _sinks.clear();
  }
}

/// 示例 1: 基本的控制台輸出
Future<void> example1_console() async {
  print('\n=== Example 1: Console Output ===');

  await Logger.init(LoggerConfig(
    sinks: [ConsoleSink()],
    environment: Environment.development,
  ));

  await Logger.info('Starting application...');
  await Logger.debug('Debug mode enabled');
  await Logger.warning('Low memory warning');
  await Logger.error('Failed to connect to service');

  await Logger.dispose();
}

/// 示例 2: 輸出到單一檔案
Future<void> example2_file() async {
  print('\n=== Example 2: File Output ===');

  final logFile = File('example_output/app.log');
  await logFile.parent.create(recursive: true);

  await Logger.init(LoggerConfig(
    sinks: [FileSink('example_output/app.log')],
    environment: Environment.development,
  ));

  await Logger.info('Application started');
  await Logger.error('Connection error occurred');

  await Logger.dispose();
  print('Logs written to: ${logFile.absolute.path}');
}

/// 示例 3: 同時輸出到控制台和檔案
Future<void> example3_console_and_file() async {
  print('\n=== Example 3: Console and File Output ===');

  final logFile = File('example_output/combined.log');
  await logFile.parent.create(recursive: true);

  await Logger.init(LoggerConfig(
    sinks: [
      ConsoleSink(),
      FileSink('example_output/combined.log'),
    ],
    environment: Environment.development,
  ));

  await Logger.info('Processing started');
  await Logger.warning('Process taking longer than expected');
  await Logger.error('Process failed');

  await Logger.dispose();
  print('Logs written to: ${logFile.absolute.path}');
}

/// 示例 4: 根據日誌級別輸出到不同檔案
Future<void> example4_level_based_files() async {
  print('\n=== Example 4: Level-based File Output ===');

  await Directory('example_output').create(recursive: true);

  final levelBasedSink = LevelBasedFileSink(
    'example_output/app',
    levels: {
      LogLevel.error,
      LogLevel.warning,
      LogLevel.info,
    },
  );

  await Logger.init(LoggerConfig(
    sinks: [
      ConsoleSink(), // 同時輸出到控制台以便查看
      levelBasedSink,
    ],
    environment: Environment.development,
  ));

  // 測試不同級別的日誌
  await Logger.info('User logged in');
  await Logger.warning('High CPU usage detected');
  await Logger.error('Database connection lost');
  try {
    throw Exception('Unexpected error occurred');
  } catch (e, stack) {
    await Logger.error('System error', e, stack);
  }

  await Logger.dispose();
  print('Logs written to example_output/ directory:');
  print('- app.log (all logs)');
  print('- app.error.log (error logs)');
  print('- app.warning.log (warning logs)');
  print('- app.info.log (info logs)');
}

Future<void> example5_console_without_init() async {
  print('\n=== Example 5: Console without init Output ===');

  await Logger.info('Starting application...');
  await Logger.debug('Debug mode enabled');
  await Logger.warning('Low memory warning');
  await Logger.error('Failed to connect to service');

  await Logger.dispose();
}

/// 主函數運行所有示例
void main() async {
  // 運行所有示例
  await example1_console();
  await example2_file();
  await example3_console_and_file();
  await example4_level_based_files();
  await example5_console_without_init();

  print(
      '\nAll examples completed. Check example_output/ directory for log files.');
}
