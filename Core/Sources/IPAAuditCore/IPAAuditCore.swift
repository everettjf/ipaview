import Foundation

public struct IPAAppMetadata: Codable, Equatable, Sendable {
    public let name: String
    public let bundleIdentifier: String
    public let version: String
    public let build: String
    public let minimumOSVersion: String?
    public let executable: String?
}

public struct IPASizeEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String { path }
    public let path: String
    public let bytes: Int64
    public let isDirectory: Bool
}

public enum IPAFindingSeverity: String, Codable, Sendable { case info, warning, error }

public struct IPAFinding: Codable, Equatable, Sendable, Identifiable {
    public var id: String { code }
    public let code: String
    public let severity: IPAFindingSeverity
    public let title: String
    public let detail: String
}

public struct IPASigningInfo: Codable, Equatable, Sendable {
    public let teamIdentifier: String?
    public let applicationIdentifier: String?
    public let expirationDate: Date?
    public let entitlements: [String: String]
}

public struct IPAAuditReport: Codable, Equatable, Sendable {
    public let metadata: IPAAppMetadata
    public let totalBytes: Int64
    public let files: [IPASizeEntry]
    public let frameworks: [String]
    public let extensions: [String]
    public let localizations: [String]
    public let privacyUsageDescriptions: [String: String]
    public let hasPrivacyManifest: Bool
    public let architectures: [String]
    public let signing: IPASigningInfo?
    public let findings: [IPAFinding]
}

public enum IPAAuditError: LocalizedError, Equatable {
    case payloadMissing
    case appMissing
    case infoPlistMissing
    case invalidInfoPlist

    public var errorDescription: String? {
        switch self {
        case .payloadMissing: "The archive does not contain a Payload directory."
        case .appMissing: "No .app bundle was found in Payload."
        case .infoPlistMissing: "The app bundle does not contain Info.plist."
        case .invalidInfoPlist: "Info.plist could not be decoded."
        }
    }
}

public struct IPAAuditor: Sendable {
    public init() {}

    public func audit(extractedArchive root: URL) throws -> IPAAuditReport {
        let payload = root.appendingPathComponent("Payload", isDirectory: true)
        guard isDirectory(payload) else { throw IPAAuditError.payloadMissing }
        guard let app = try FileManager.default.contentsOfDirectory(
            at: payload,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).first(where: { $0.pathExtension.lowercased() == "app" && isDirectory($0) }) else {
            throw IPAAuditError.appMissing
        }

        let infoURL = app.appendingPathComponent("Info.plist")
        guard FileManager.default.fileExists(atPath: infoURL.path) else { throw IPAAuditError.infoPlistMissing }
        guard let data = try? Data(contentsOf: infoURL),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { throw IPAAuditError.invalidInfoPlist }

        let metadata = IPAAppMetadata(
            name: string(info, "CFBundleDisplayName") ?? string(info, "CFBundleName") ?? app.deletingPathExtension().lastPathComponent,
            bundleIdentifier: string(info, "CFBundleIdentifier") ?? "",
            version: string(info, "CFBundleShortVersionString") ?? "",
            build: string(info, "CFBundleVersion") ?? "",
            minimumOSVersion: string(info, "MinimumOSVersion"),
            executable: string(info, "CFBundleExecutable")
        )

        let entries = enumerate(app: app)
        let relativePaths = Set(entries.map(\.path))
        let frameworks = relativePaths.filter { $0.hasPrefix("Frameworks/") && $0.hasSuffix(".framework") }.sorted()
        let appExtensions = relativePaths.filter { $0.hasPrefix("PlugIns/") && $0.hasSuffix(".appex") }.sorted()
        let localizations = relativePaths.compactMap { path -> String? in
            guard path.hasSuffix(".lproj") else { return nil }
            return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        }.sorted()
        let usage = info.compactMapValues { $0 as? String }.filter { $0.key.hasPrefix("NS") && $0.key.hasSuffix("UsageDescription") }
        let hasPrivacyManifest = relativePaths.contains { $0.hasSuffix("PrivacyInfo.xcprivacy") }
        let appArchitectures = metadata.executable.map { architectures(at: app.appendingPathComponent($0)) } ?? []
        let signing = signingInfo(at: app.appendingPathComponent("embedded.mobileprovision"))
        let findings = makeFindings(metadata: metadata, usage: usage, hasPrivacyManifest: hasPrivacyManifest, architectures: appArchitectures, signing: signing)

        return IPAAuditReport(
            metadata: metadata,
            totalBytes: entries.filter { !$0.isDirectory }.reduce(0) { $0 + $1.bytes },
            files: entries,
            frameworks: frameworks,
            extensions: appExtensions,
            localizations: localizations,
            privacyUsageDescriptions: usage,
            hasPrivacyManifest: hasPrivacyManifest,
            architectures: appArchitectures,
            signing: signing,
            findings: findings
        )
    }

    private func enumerate(app: URL) -> [IPASizeEntry] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey]
        guard let iterator = FileManager.default.enumerator(at: app, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else { return [] }
        return iterator.compactMap { item in
            guard let url = item as? URL, let values = try? url.resourceValues(forKeys: keys) else { return nil }
            let prefix = app.path.hasSuffix("/") ? app.path : app.path + "/"
            return IPASizeEntry(
                path: url.path.replacingOccurrences(of: prefix, with: ""),
                bytes: Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0),
                isDirectory: values.isDirectory ?? false
            )
        }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func makeFindings(metadata: IPAAppMetadata, usage: [String: String], hasPrivacyManifest: Bool, architectures: [String], signing: IPASigningInfo?) -> [IPAFinding] {
        var result: [IPAFinding] = []
        if metadata.bundleIdentifier.isEmpty {
            result.append(.init(code: "missing-bundle-id", severity: .error, title: "Missing bundle identifier", detail: "CFBundleIdentifier is empty."))
        }
        if metadata.version.isEmpty || metadata.build.isEmpty {
            result.append(.init(code: "missing-version", severity: .error, title: "Missing version", detail: "Both marketing version and build number are required."))
        }
        if !hasPrivacyManifest {
            result.append(.init(code: "missing-privacy-manifest", severity: .warning, title: "No privacy manifest found", detail: "Review whether the app or embedded SDKs require PrivacyInfo.xcprivacy."))
        }
        if metadata.executable == nil || architectures.isEmpty {
            result.append(.init(code: "missing-executable", severity: .error, title: "Executable could not be inspected", detail: "Verify CFBundleExecutable and the Mach-O binary inside the app bundle."))
        }
        if architectures.contains("i386") || architectures.contains("x86_64") {
            result.append(.init(code: "simulator-architecture", severity: .error, title: "Simulator architecture included", detail: "App Store IPA files should not contain i386 or x86_64 executable slices."))
        }
        if signing == nil {
            result.append(.init(code: "missing-provisioning-profile", severity: .info, title: "Provisioning profile not found", detail: "App Store distributions may omit embedded.mobileprovision; development and ad hoc builds normally include it."))
        }
        for (key, value) in usage where value.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
            result.append(.init(code: "weak-\(key)", severity: .warning, title: "Weak privacy explanation", detail: "\(key) should clearly explain why the data or capability is needed."))
        }
        return result.sorted { $0.code < $1.code }
    }

    private func string(_ dictionary: [String: Any], _ key: String) -> String? { dictionary[key] as? String }
    private func isDirectory(_ url: URL) -> Bool { (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }

    private func architectures(at url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count >= 8 else { return [] }
        let magic = uint32(data, 0, bigEndian: true)
        switch magic {
        case 0xfeedface, 0xfeedfacf:
            return [architectureName(uint32(data, 4, bigEndian: true))]
        case 0xcefaedfe, 0xcffaedfe:
            return [architectureName(uint32(data, 4, bigEndian: false))]
        case 0xcafebabe, 0xcafebabf:
            let count = min(Int(uint32(data, 4, bigEndian: true)), 64)
            let stride = magic == 0xcafebabf ? 32 : 20
            return (0..<count).compactMap { index in
                let offset = 8 + index * stride
                guard data.count >= offset + 4 else { return nil }
                return architectureName(uint32(data, offset, bigEndian: true))
            }.sorted()
        default:
            return []
        }
    }

    private func architectureName(_ cpuType: UInt32) -> String {
        switch cpuType {
        case 7: "i386"
        case 12: "arm"
        case 0x01000007: "x86_64"
        case 0x0100000c: "arm64"
        case 0x0200000c: "arm64_32"
        default: String(format: "unknown-0x%08x", cpuType)
        }
    }

    private func uint32(_ data: Data, _ offset: Int, bigEndian: Bool) -> UInt32 {
        guard data.count >= offset + 4 else { return 0 }
        let bytes = data[offset..<(offset + 4)]
        return bytes.reduce(UInt32(0)) { value, byte in
            bigEndian ? (value << 8) | UInt32(byte) : (value >> 8) | (UInt32(byte) << 24)
        }
    }

    private func signingInfo(at url: URL) -> IPASigningInfo? {
        guard let data = try? Data(contentsOf: url),
              let xmlStart = data.range(of: Data("<?xml".utf8))?.lowerBound,
              let plistEndRange = data.range(of: Data("</plist>".utf8), options: [], in: xmlStart..<data.endIndex)
        else { return nil }
        let plistData = data[xmlStart..<plistEndRange.upperBound]
        guard let profile = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else { return nil }
        let rawEntitlements = profile["Entitlements"] as? [String: Any] ?? [:]
        let entitlements = rawEntitlements.mapValues { value in
            if let strings = value as? [String] { return strings.joined(separator: ", ") }
            return String(describing: value)
        }
        let teams = profile["TeamIdentifier"] as? [String]
        return IPASigningInfo(
            teamIdentifier: teams?.first ?? profile["TeamName"] as? String,
            applicationIdentifier: rawEntitlements["application-identifier"] as? String,
            expirationDate: profile["ExpirationDate"] as? Date,
            entitlements: entitlements
        )
    }
}
