import 'dart:async';
import 'package:test/test.dart';
import 'package:logcraft/logcraft.dart';

void main() {
  group('Logger tests', () {
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
      await Logger.init(LoggerConfig(
        sinks: [ConsoleSink()],
        environment: Environment.development,
      ));
    });

    tearDown(() async {
      await Logger.dispose();
    });

    test('should respect log levels', () async {
      // 測試 VERBOSE 級別（最低級別，應該顯示所有日誌）
      Logger.setLogLevel(LogLevel.verbose);
      final output1 = await collectOutput(() async {
        await Logger.error('Error message');
        await Logger.warning('Warning message');
        await Logger.info('Info message');
        await Logger.verbose('Verbose message');
      });

      expect(output1, contains('[ERROR] Error message'));
      expect(output1, contains('[WARNING] Warning message'));
      expect(output1, contains('[INFO] Info message'));
      expect(output1, contains('[VERBOSE] Verbose message'));

      // 測試 WARNING 級別（中等級別，只顯示 warning 及更高級別）
      Logger.setLogLevel(LogLevel.warning);
      final output2 = await collectOutput(() async {
        await Logger.error('Error message');
        await Logger.warning('Warning message');
        await Logger.info('Info message');
      });

      expect(output2, contains('[ERROR] Error message'));
      expect(output2, contains('[WARNING] Warning message'));
      expect(output2, isNot(contains('[INFO] Info message')));
    });

    test('should format timestamp correctly', () async {
      Logger.setLogLevel(LogLevel.error);
      final output = await collectOutput(() async {
        await Logger.error('Test message');
      });

      expect(
          output,
          matches(
              r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\]\[ERROR\].*\n$'));
    });

    test('should handle error with stack trace', () async {
      Logger.setLogLevel(LogLevel.error);
      final output = await collectOutput(() async {
        try {
          throw Exception('Test error');
        } catch (e, stack) {
          await Logger.error('Error occurred', e, stack);
        }
      });

      expect(output, contains('[ERROR] Error occurred'));
      expect(output, contains('Error details: Exception: Test error'));
      expect(output, contains('Stack trace:'));
    });

    test('should respect environment settings', () async {
      // 測試開發環境（最詳細的日誌級別）
      Logger.setEnvironment(Environment.development);
      var output = await collectOutput(() async {
        await Logger.verbose('Verbose log');
        await Logger.debug('Debug log');
        await Logger.info('Info log');
      });
      expect(output, contains('[VERBOSE]'));
      expect(output, contains('[DEBUG]'));
      expect(output, contains('[INFO]'));

      // 測試測試環境（警告及以上）
      Logger.setEnvironment(Environment.testing);
      output = await collectOutput(() async {
        await Logger.info('Info log');
        await Logger.warning('Warning log');
        await Logger.error('Error log');
      });
      expect(output, isNot(contains('[INFO]')));
      expect(output, contains('[WARNING]'));
      expect(output, contains('[ERROR]'));

      // 測試生產環境（只有錯誤）
      Logger.setEnvironment(Environment.production);
      output = await collectOutput(() async {
        await Logger.warning('Warning log');
        await Logger.error('Error log');
        await Logger.critical('Critical log');
      });
      expect(output, isNot(contains('[WARNING]')));
      expect(output, contains('[ERROR]'));
      expect(output, contains('[CRITICAL]'));
    });
  });
}
