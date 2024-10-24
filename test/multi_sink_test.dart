import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:logcraft/logcraft.dart';

/// 測試用的文件輸出實現
class FileSink implements LogSink {
  final IOSink _sink;

  /// 創建一個文件輸出實例
  /// [path] 文件路徑
  /// [append] 是否追加模式，預設為 true
  FileSink(String path, {bool append = true})
      : _sink = File(path)
            .openWrite(mode: append ? FileMode.append : FileMode.write);

  @override
  Future<void> write(String message, LogLevel level) async {
    _sink.add(utf8.encode('$message\n'));
    await _sink.flush();
  }

  @override
  Future<void> dispose() async {
    await _sink.flush();
    await _sink.close();
  }
}

void main() {
  group('Multi-sink Logger tests', () {
    late Directory tempDir;
    late String logPath;
    late File logFile;

    Future<String> collectOutput(Future<void> Function() fn) async {
      final output = StringBuffer();
      await runZoned(
        fn,
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, String message) {
            output.writeln(message);
          },
        ),
      );
      return output.toString();
    }

    setUp(() async {
      // 創建臨時目錄用於測試
      tempDir = await Directory.systemTemp.createTemp('logcraft_test_');
      logPath = '${tempDir.path}/test.log';
      logFile = File(logPath);

      // 初始化 Logger，同時使用控制台和文件輸出
      await Logger.init(LoggerConfig(
        sinks: [
          ConsoleSink(),
          FileSink(logPath),
        ],
        environment: Environment.development,
      ));
    });

    tearDown(() async {
      await Logger.dispose();
      // 清理臨時文件和目錄
      if (await logFile.exists()) {
        await logFile.delete();
      }
      if (await tempDir.exists()) {
        await tempDir.delete();
      }
    });

    test('should write to both console and file', () async {
      // 寫入一些日誌
      final consoleOutput = await collectOutput(() async {
        await Logger.info('Test message 1');
        await Logger.error('Test error', Exception('Some error'));
        await Logger.debug('Test debug message');
      });

      // 等待一小段時間確保文件寫入完成
      await Future.delayed(Duration(milliseconds: 100));

      // 讀取文件內容
      final fileContent = await logFile.readAsString();

      // 驗證控制台輸出
      expect(consoleOutput, contains('Test message 1'));
      expect(consoleOutput, contains('Test error'));
      expect(consoleOutput, contains('Some error'));
      expect(consoleOutput, contains('Test debug message'));

      // 驗證文件輸出
      expect(fileContent, contains('Test message 1'));
      expect(fileContent, contains('Test error'));
      expect(fileContent, contains('Some error'));
      expect(fileContent, contains('Test debug message'));
    });

    test('should respect log levels in all outputs', () async {
      Logger.setLogLevel(LogLevel.error);

      final consoleOutput = await collectOutput(() async {
        await Logger.info('Should not appear');
        await Logger.error('Should appear');
      });

      await Future.delayed(Duration(milliseconds: 100));
      final fileContent = await logFile.readAsString();

      // 驗證控制台輸出
      expect(consoleOutput, isNot(contains('Should not appear')));
      expect(consoleOutput, contains('Should appear'));

      // 驗證文件輸出
      expect(fileContent, isNot(contains('Should not appear')));
      expect(fileContent, contains('Should appear'));
    });

    test('should handle errors and stack traces in all outputs', () async {
      final consoleOutput = await collectOutput(() async {
        try {
          throw Exception('Test error');
        } catch (e, stack) {
          await Logger.error('Error occurred', e, stack);
        }
      });

      await Future.delayed(Duration(milliseconds: 100));
      final fileContent = await logFile.readAsString();

      // 驗證錯誤信息和堆疊追蹤在兩個輸出中都存在
      expect(consoleOutput, contains('Error occurred'));
      expect(consoleOutput, contains('Test error'));
      expect(consoleOutput, contains('Stack trace:'));

      expect(fileContent, contains('Error occurred'));
      expect(fileContent, contains('Test error'));
      expect(fileContent, contains('Stack trace:'));
    });

    test('should append to existing file', () async {
      // 第一次寫入
      await Logger.info('First message');
      await Future.delayed(Duration(milliseconds: 100));
      final firstContent = await logFile.readAsString();

      // 重新初始化 Logger（使用相同的文件）
      await Logger.dispose();
      await Logger.init(LoggerConfig(
        sinks: [
          ConsoleSink(),
          FileSink(logPath), // 預設 append = true
        ],
        environment: Environment.development,
      ));

      // 第二次寫入
      await Logger.info('Second message');
      await Future.delayed(Duration(milliseconds: 100));
      final finalContent = await logFile.readAsString();

      // 驗證兩條消息都在文件中
      expect(finalContent, contains('First message'));
      expect(finalContent, contains('Second message'));
      expect(finalContent.length, greaterThan(firstContent.length));
    });

    test('should create new file if not exists', () async {
      final newLogPath = '${tempDir.path}/new_test.log';

      // 確保文件不存在
      final newLogFile = File(newLogPath);
      if (await newLogFile.exists()) {
        await newLogFile.delete();
      }

      // 使用新文件路徑初始化 Logger
      await Logger.dispose();
      await Logger.init(LoggerConfig(
        sinks: [
          ConsoleSink(),
          FileSink(newLogPath),
        ],
        environment: Environment.development,
      ));

      await Logger.info('Test message');
      await Future.delayed(Duration(milliseconds: 100));

      // 驗證文件被創建並包含日誌消息
      expect(await newLogFile.exists(), isTrue);
      final content = await newLogFile.readAsString();
      expect(content, contains('Test message'));

      // 清理新建的文件
      await newLogFile.delete();
    });
  });
}
