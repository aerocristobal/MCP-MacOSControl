import Foundation

public enum LogLevel: Int, Comparable {
    case error = 0
    case warn = 1
    case info = 2
    case debug = 3
    case trace = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .error: return "ERROR"
        case .warn: return "WARN"
        case .info: return "INFO"
        case .debug: return "DEBUG"
        case .trace: return "TRACE"
        }
    }
}

public enum MCPLogger {
    /// Current log level. Configurable via MCP_MACOS_CONTROL_LOG_LEVEL.
    public static var level: LogLevel {
        guard let env = ProcessInfo.processInfo.environment["MCP_MACOS_CONTROL_LOG_LEVEL"] else {
            return .warn
        }
        switch env.lowercased() {
        case "error": return .error
        case "warn", "warning": return .warn
        case "info": return .info
        case "debug": return .debug
        case "trace": return .trace
        default: return .warn
        }
    }

    /// Log a message at the specified level. Only outputs if level is at or below current threshold.
    public static func log(_ logLevel: LogLevel, _ message: String) {
        guard logLevel <= level else { return }
        fputs("[\(logLevel.label)] \(message)\n", stderr)
    }

    public static func error(_ message: String) { log(.error, message) }
    public static func warn(_ message: String) { log(.warn, message) }
    public static func info(_ message: String) { log(.info, message) }
    public static func debug(_ message: String) { log(.debug, message) }
    public static func trace(_ message: String) { log(.trace, message) }
}
