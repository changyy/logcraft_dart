import 'dart:async';
import 'package:test/test.dart';
import 'package:logcraft/logcraft.dart';

class TestSink implements LogSink {
  final List<String> messages = [];
  final List<LogLevel> levels = [];
  bool disposed = false;

  @override
  Future<void> write(String message, LogLevel level) async {
    await Future.delayed(
        Duration(milliseconds: DateTime.now().millisecond % 10));
    messages.add(message);
    levels.add(level);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  group('Logger Thread Safety Tests', () {
    late TestSink testSink;

    setUp(() {
      testSink = TestSink();
    });

    tearDown(() async {
      await Logger.dispose();
    });

    test('並發初始化測試', () async {
      final futures = List<Future<void>>.generate(5, (_) {
        return Logger.init(LoggerConfig(
          sinks: [testSink],
          environment: Environment.development,
        ));
      });

      await Future.wait(futures);

      expect(testSink.disposed, true);
      await Logger.info('test message');
      expect(testSink.messages.length, 1);
    });

    test('並發日誌寫入測試', () async {
      await Logger.init(LoggerConfig(
        sinks: [testSink],
        environment: Environment.development,
      ));

      final messageFutures = List<Future<void>>.generate(100, (index) {
        return Logger.info('Message $index');
      });

      await Future.wait(messageFutures);

      expect(testSink.messages.length, 100);
      expect(testSink.levels.every((level) => level == LogLevel.info), true);
    });

    test('並發環境切換測試', () async {
      await Logger.init(LoggerConfig(
        sinks: [testSink],
        environment: Environment.development,
      ));

      // 先確保在 development 環境下可以寫入 debug 日誌
      await Logger.debug('Initial debug message');
      expect(testSink.messages.length, 1,
          reason: 'Development 環境應該可以寫入 debug 日誌');

      // 切換到 production 環境
      Logger.setEnvironment(Environment.production);

      // 清空之前的消息
      testSink.messages.clear();
      testSink.levels.clear();

      // 嘗試寫入不同級別的日誌
      await Future.wait([
        Logger.error('Error message'),
        Logger.debug('Debug message 1'),
        Logger.debug('Debug message 2'),
        Logger.info('Info message'),
        Logger.warning('Warning message'),
      ]);

      // 在 production 環境下，只有 error 級別以上的日誌應該被寫入
      expect(testSink.messages.length, 1,
          reason: 'Production 環境應該只寫入 error 級別的日誌');
      expect(
          testSink.levels.every((level) => level.value <= LogLevel.error.value),
          true,
          reason: '所有寫入的日誌級別應該小於或等於 error');
    });

    test('並發 dispose 測試', () async {
      await Logger.init(LoggerConfig(
        sinks: [testSink],
        environment: Environment.development,
      ));

      final disposeFutures =
          List<Future<void>>.generate(5, (_) => Logger.dispose());
      final logFutures = List<Future<void>>.generate(
          10, (i) => Logger.info('Message during dispose $i'));

      await Future.wait([
        ...disposeFutures,
        ...logFutures,
      ]);

      expect(testSink.disposed, true);
    });

    test('日誌順序測試', () async {
      await Logger.init(LoggerConfig(
        sinks: [testSink],
        environment: Environment.development,
      ));

      final expectedOrder = <String>[];
      final futures = <Future<void>>[];

      for (var i = 0; i < 10; i++) {
        final message = 'Ordered message $i';
        expectedOrder.add(message);
        futures.add(Logger.info(message));
      }

      await Future.wait(futures);

      for (var i = 0; i < expectedOrder.length; i++) {
        expect(testSink.messages[i].contains(expectedOrder[i]), true);
      }
    });
  });
}
