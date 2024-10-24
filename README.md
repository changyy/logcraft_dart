# LogCraft

[![pub package](https://img.shields.io/pub/v/logcraft.svg)](https://pub.dev/packages/logcraft)
[![Build Status](https://github.com/changyy/logcraft_dart/workflows/Dart/badge.svg)](https://github.com/changyy/logcraft_dart/actions)

A flexible, cross-platform logging solution for Dart applications with async operations and environment-based configuration.

## Features

- Cross-platform core logging system
  - Platform-agnostic design
  - Extensible output sink interface
  - Multiple output destinations support
  - Asynchronous logging operations

- Environment-based configuration
  - Development: Full logging
  - Testing: Warning and above
  - Production: Error and above

- Multiple log levels
  - CRITICAL: System crash, fatal errors
  - ERROR: Errors that need attention
  - WARNING: Potential issues
  - INFO: General information
  - DEBUG: Debug information
  - VERBOSE: Detailed debug information

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  logcraft: ^1.0.0
```

Then run:
```bash
dart pub get
```

## Usage

### Basic Console Logging

```dart
import 'package:logcraft/logcraft.dart';

void main() async {
  // Initialize with console output
  await Logger.init(LoggerConfig(
    sinks: [ConsoleSink()],
    environment: Environment.development,
  ));

  // Log messages
  await Logger.info('Application started');
  await Logger.debug('Test message');
  await Logger.error('Error occurred');

  // Clean up
  await Logger.dispose();
}
```

### Error Handling with Stack Traces

```dart
try {
  throw Exception('Database connection failed');
} catch (e, stack) {
  await Logger.error('Failed to connect', e, stack);
}
```

### Environment-based Configuration

```dart
// Development environment (all logs)
await Logger.init(LoggerConfig(
  sinks: [ConsoleSink()],
  environment: Environment.development,
));

// Testing environment (warning and above)
await Logger.init(LoggerConfig(
  sinks: [ConsoleSink()],
  environment: Environment.testing,
));

// Production environment (error and above)
await Logger.init(LoggerConfig(
  sinks: [ConsoleSink()],
  environment: Environment.production,
));
```

### Custom Output Implementation

```dart
class CustomSink implements LogSink {
  @override
  Future<void> write(String message, LogLevel level) async {
    // Implement your custom logging logic
  }

  @override
  Future<void> dispose() async {
    // Clean up resources
  }
}

// Use your custom sink
await Logger.init(LoggerConfig(
  sinks: [CustomSink()],
  environment: Environment.development,
));
```

### Multiple Output Destinations

```dart
await Logger.init(LoggerConfig(
  sinks: [
    ConsoleSink(),
    CustomSink(),
    AnotherCustomSink(),
  ],
  environment: Environment.development,
));
```

### Log Output Format

Each log message includes a timestamp and level indicator:
```
[2024-10-24 00:00:00.123][INFO] Application started
[2024-10-24 00:00:00.124][ERROR] Failed to connect
[2024-10-24 00:00:00.124][ERROR] Error details: Database connection failed
[2024-10-24 00:00:00.124][ERROR] Stack trace: ...
```

## Development

Requirements:
- Dart SDK >=2.17.0 <4.0.0

### Running Tests

```bash
# Run all tests
dart test

# Run specific test file
dart test test/logcraft_test.dart
```

### Examples

Check the `example` directory for more usage examples:
- Console output
- File output
- Multiple output destinations
- Level-based file logging

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Created and maintained by [changyy](https://github.com/changyy).
