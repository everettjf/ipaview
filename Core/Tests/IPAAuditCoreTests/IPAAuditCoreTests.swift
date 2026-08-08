import Foundation
import Testing
@testable import IPAAuditCore

@Suite("IPA audit")
struct IPAAuditCoreTests {
    @Test("Extracted app metadata and risks are reported")
    func completeAudit() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.makeApp(info: [
            "CFBundleDisplayName": "Example",
            "CFBundleIdentifier": "com.example.app",
            "CFBundleShortVersionString": "2.1",
            "CFBundleVersion": "42",
            "CFBundleExecutable": "Example",
            "MinimumOSVersion": "17.0",
            "NSCameraUsageDescription": "camera"
        ])
        try fixture.write("Frameworks/Kit.framework/Kit", bytes: 64)
        try fixture.write("PlugIns/Share.appex/Info.plist", bytes: 12)
        try fixture.directory("en.lproj")
        try fixture.write("Example", data: Data([0xcf, 0xfa, 0xed, 0xfe, 0x0c, 0x00, 0x00, 0x01]))

        let report = try IPAAuditor().audit(extractedArchive: fixture.root)

        #expect(report.metadata.name == "Example")
        #expect(report.metadata.bundleIdentifier == "com.example.app")
        #expect(report.frameworks == ["Frameworks/Kit.framework"])
        #expect(report.extensions == ["PlugIns/Share.appex"])
        #expect(report.localizations == ["en"])
        #expect(report.architectures == ["arm64"])
        #expect(report.findings.map(\.code).contains("missing-privacy-manifest"))
        #expect(report.findings.map(\.code).contains("weak-NSCameraUsageDescription"))
        #expect(report.totalBytes > 0)
    }

    @Test("Provisioning profile entitlements are extracted")
    func signingProfile() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.makeApp(info: [
            "CFBundleIdentifier": "com.example.signed",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "CFBundleExecutable": "Signed"
        ])
        try fixture.write("Signed", data: Data([0xcf, 0xfa, 0xed, 0xfe, 0x0c, 0x00, 0x00, 0x01]))
        try fixture.makeProvisioningProfile([
            "TeamIdentifier": ["TEAM123"],
            "ExpirationDate": Date(timeIntervalSince1970: 2_000_000_000),
            "Entitlements": [
                "application-identifier": "TEAM123.com.example.signed",
                "aps-environment": "production"
            ]
        ])

        let report = try IPAAuditor().audit(extractedArchive: fixture.root)

        #expect(report.signing?.teamIdentifier == "TEAM123")
        #expect(report.signing?.applicationIdentifier == "TEAM123.com.example.signed")
        #expect(report.signing?.entitlements["aps-environment"] == "production")
        #expect(!report.findings.map(\.code).contains("missing-provisioning-profile"))
    }

    @Test("Malformed archives fail with a useful reason")
    func validationErrors() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        #expect(throws: IPAAuditError.payloadMissing) {
            try IPAAuditor().audit(extractedArchive: fixture.root)
        }
        try fixture.archiveDirectory("Payload")
        #expect(throws: IPAAuditError.appMissing) {
            try IPAAuditor().audit(extractedArchive: fixture.root)
        }
    }
}

private struct Fixture {
    let root: URL
    let app: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        app = root.appendingPathComponent("Payload/Example.app", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func makeApp(info: [String: Any]) throws {
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .binary, options: 0)
        try data.write(to: app.appendingPathComponent("Info.plist"))
    }

    func directory(_ path: String) throws {
        try FileManager.default.createDirectory(at: app.appendingPathComponent(path), withIntermediateDirectories: true)
    }

    func archiveDirectory(_ path: String) throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
    }

    func write(_ path: String, bytes: Int) throws {
        try write(path, data: Data(repeating: 0x2A, count: bytes))
    }

    func write(_ path: String, data: Data) throws {
        let url = app.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    func makeProvisioningProfile(_ profile: [String: Any]) throws {
        let plist = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
        var container = Data([0x30, 0x82, 0x00, 0x01])
        container.append(plist)
        container.append(Data([0x00, 0x01]))
        try write("embedded.mobileprovision", data: container)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
