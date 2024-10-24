## 1.1.0

### Major Changes
- Implemented thread safety using `synchronized` package
  - Added `Lock` mechanism for critical sections
  - Thread-safe logging operations with synchronized blocks
  - Protected shared resources including sinks list and logger state
  - Safe initialization and disposal process

### Technical Implementations
- Synchronized operations:
  - Logger initialization and disposal
  - Log message writing across all sinks
  - Environment and log level changes
- Error handling improvements:
  - Safe cleanup on initialization failures
  - Individual sink error isolation
  - Proper resource disposal

### Example
```dart
// Thread-safe initialization
await Logger.init(config);  // Protected by Lock

// Safe concurrent logging from multiple isolates
await Future.wait([
  Logger.error("Error message"),
  Logger.info("Info message"),
  Logger.warning("Warning message")
]); // All operations protected by Lock

// Safe re-initialization
await Logger.init(newConfig);  // Automatic cleanup and Lock protection
```

## 1.0.1

### Enhancements
- Improved initialization handling
  - Added automatic resource cleanup when re-initializing Logger
  - No longer requires manual `dispose()` call before re-initialization
  - More user-friendly initialization process

### Example
```dart
// Before (1.0.0):
await Logger.dispose();  // Manual dispose required
await Logger.init(newConfig);

// Now (1.0.1):
await Logger.init(newConfig);  // Automatic cleanup and re-initialization
```

## 1.0.0

Initial release with the following features:
- Cross-platform core logging system
  - Platform-agnostic design
  - Extensible output sink interface
  - Support for multiple simultaneous output destinations
  - Asynchronous logging operations

- Logging Levels
  - CRITICAL: System crash, fatal errors
  - ERROR: Errors that need attention
  - WARNING: Potential issues
  - INFO: General information
  - DEBUG: Debug information
  - VERBOSE: Detailed debug information

- Environment-based Configuration
  - Development: Full logging
  - Testing: Warning and above
  - Production: Error and above

- Built-in Features
  - Timestamp support
  - Error and stack trace handling
  - Console output sink
  - Customizable log formatting

- Example Implementations
  - Basic file logging
  - Level-based file logging
  - Multiple output destinations

- Documentation
  - Basic usage examples
  - Custom sink implementation guide
  - Testing utilities
