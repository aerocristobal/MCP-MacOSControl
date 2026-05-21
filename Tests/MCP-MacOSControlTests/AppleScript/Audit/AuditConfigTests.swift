// STORY-024 — AuditConfig env-var parsing and validation.

import XCTest
@testable import MacOSControlLib

final class AuditConfigTests: XCTestCase {

    func test_load_picksDefaults_whenNoEnvVarsSet() {
        let c = AuditConfig.load(env: [:])
        XCTAssertEqual(c.retentionDays, AuditConfig.defaultRetentionDays)
        XCTAssertEqual(c.remoteSinkKind, .oslog)
        XCTAssertEqual(c.ackTimeoutMs, AuditConfig.defaultAckTimeoutMs)
        XCTAssertFalse(c.adminToolsEnabled)
    }

    func test_load_setsRetentionDaysFromEnv() {
        let c = AuditConfig.load(env: ["MCP_MACOS_CONTROL_AUDIT_RETENTION_DAYS": "90"])
        XCTAssertEqual(c.retentionDays, 90)
    }

    func test_load_setsRemoteFromEnv() {
        let c = AuditConfig.load(env: ["MCP_MACOS_CONTROL_AUDIT_REMOTE": "syslog"])
        XCTAssertEqual(c.remoteSinkKind, .syslog)
    }

    func test_load_setsRemoteUrlFromEnv() {
        let c = AuditConfig.load(env: [
            "MCP_MACOS_CONTROL_AUDIT_REMOTE": "http",
            "MCP_MACOS_CONTROL_AUDIT_REMOTE_URL": "https://siem.example.com/ingest"
        ])
        XCTAssertEqual(c.remoteSinkKind, .http)
        XCTAssertEqual(c.remoteSinkURL?.absoluteString, "https://siem.example.com/ingest")
    }

    func test_load_setsAdminToolsEnabledFromEnv() {
        let c = AuditConfig.load(env: ["MCP_MACOS_CONTROL_AUDIT_ADMIN_ENABLED": "true"])
        XCTAssertTrue(c.adminToolsEnabled)
    }

    func test_load_setsTestOverrides() {
        let c = AuditConfig.load(env: [
            "MCP_MACOS_CONTROL_AUDIT_HOST_IDENTIFIER": "ci-host",
            "MCP_MACOS_CONTROL_AUDIT_INSTALL_UUID": "ci-uuid"
        ])
        XCTAssertEqual(c.hostIdentifierOverride, "ci-host")
        XCTAssertEqual(c.installUuidOverride, "ci-uuid")
    }

    // MARK: - validate()

    func test_validate_throwsConfigInvalid_whenHttpWithoutUrl() {
        let c = AuditConfig.load(env: ["MCP_MACOS_CONTROL_AUDIT_REMOTE": "http"])
        XCTAssertThrowsError(try c.validate()) { error in
            guard let e = error as? AuditConfigInvalid else {
                XCTFail("expected AuditConfigInvalid, got \(error)")
                return
            }
            XCTAssertEqual(e.missingVariable, "MCP_MACOS_CONTROL_AUDIT_REMOTE_URL")
        }
    }

    func test_validate_throwsConfigInvalid_whenHttpUrlIsNotHttp() {
        let c = AuditConfig.load(env: [
            "MCP_MACOS_CONTROL_AUDIT_REMOTE": "http",
            "MCP_MACOS_CONTROL_AUDIT_REMOTE_URL": "file:///tmp/audit"
        ])
        XCTAssertThrowsError(try c.validate())
    }

    func test_validate_throwsConfigInvalid_whenRetentionIsZero() {
        let c = AuditConfig.load(env: ["MCP_MACOS_CONTROL_AUDIT_RETENTION_DAYS": "0"])
        XCTAssertThrowsError(try c.validate()) { error in
            guard let e = error as? AuditConfigInvalid else {
                XCTFail("expected AuditConfigInvalid, got \(error)")
                return
            }
            XCTAssertEqual(e.missingVariable, "MCP_MACOS_CONTROL_AUDIT_RETENTION_DAYS")
        }
    }

    func test_validate_accepts_oslog_default_withNoUrl() throws {
        let c = AuditConfig.load(env: [:])
        try c.validate()
    }
}
