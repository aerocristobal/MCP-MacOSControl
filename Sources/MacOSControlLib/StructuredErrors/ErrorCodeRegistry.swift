import Foundation

public final class ErrorCodeRegistry: @unchecked Sendable {

    /// Lazily bootstrapped singleton. First access triggers ErrorCodeBootstrap.register,
    /// so production callers and tests get the full known-codes set without ceremony.
    /// Collision errors here would mean a coding bug in ErrorCodeBootstrap itself —
    /// surface them via fatalError so the process refuses to start with a broken registry.
    public static let shared: ErrorCodeRegistry = {
        let r = ErrorCodeRegistry()
        do {
            try ErrorCodeBootstrap.register(into: r)
        } catch {
            fatalError("ErrorCodeBootstrap failed during lazy init of ErrorCodeRegistry.shared: \(error)")
        }
        return r
    }()

    public static let codeRegex = "^[a-z][a-z0-9_]*$"
    public static let maxCodeLength = 64

    public struct Registration: Sendable {
        public let code: String
        public let description: String
        public let detailsSchema: [String: String]
        public let registrationCallSite: String
    }

    public struct InvalidCodeError: Error, CustomStringConvertible {
        public let code: String
        public let reason: String
        public var description: String {
            "invalid error code \"\(code)\": \(reason)"
        }
    }

    public struct CollisionError: Error, CustomStringConvertible {
        public let code: String
        public let firstRegistrationCallSite: String
        public let secondRegistrationCallSite: String
        public var description: String {
            "duplicate registration of error code \"\(code)\" — first at \(firstRegistrationCallSite), second at \(secondRegistrationCallSite)"
        }
    }

    private let lock = NSLock()
    private var entries: [String: Registration] = [:]

    public init() {}

    public func register(
        code: String,
        description: String,
        detailsSchema: [String: String] = [:],
        callSite: String = "\(#fileID):\(#line)"
    ) throws {
        try validateFormat(code)

        lock.lock()
        defer { lock.unlock() }

        if let existing = entries[code] {
            throw CollisionError(
                code: code,
                firstRegistrationCallSite: existing.registrationCallSite,
                secondRegistrationCallSite: callSite
            )
        }

        entries[code] = Registration(
            code: code,
            description: description,
            detailsSchema: detailsSchema,
            registrationCallSite: callSite
        )
    }

    public func isRegistered(_ code: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return entries[code] != nil
    }

    public func registration(for code: String) -> Registration? {
        lock.lock()
        defer { lock.unlock() }
        return entries[code]
    }

    public func allRegistrations() -> [Registration] {
        lock.lock()
        defer { lock.unlock() }
        return entries.values.sorted { $0.code < $1.code }
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    private func validateFormat(_ code: String) throws {
        if code.isEmpty {
            throw InvalidCodeError(code: code, reason: "code must not be empty")
        }
        if code.count > Self.maxCodeLength {
            throw InvalidCodeError(
                code: code,
                reason: "code length \(code.count) exceeds max \(Self.maxCodeLength)"
            )
        }
        guard let regex = try? NSRegularExpression(pattern: Self.codeRegex, options: []) else {
            throw InvalidCodeError(code: code, reason: "registry regex failed to compile")
        }
        let range = NSRange(code.startIndex..<code.endIndex, in: code)
        if regex.firstMatch(in: code, options: [], range: range) == nil {
            throw InvalidCodeError(
                code: code,
                reason: "code must match \(Self.codeRegex) (lowercase letters, digits, underscores; must start with a letter)"
            )
        }
    }
}
