import SwiftUI
import IPAAuditCore
import UniformTypeIdentifiers

struct AuditReportView: View {
    let report: IPAAuditReport
    @State private var selection = AuditSection.overview
    @State private var isExporting = false

    private enum AuditSection: Hashable { case overview, findings, files }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Audit section", selection: $selection) {
                    Text("Overview").tag(AuditSection.overview)
                    Text("Findings").tag(AuditSection.findings)
                    Text("Files").tag(AuditSection.files)
                }
                .pickerStyle(.segmented)
                Button("Export", systemImage: "square.and.arrow.up") { isExporting = true }
                    .labelStyle(.iconOnly)
            }
            .padding()
            switch selection {
            case .overview: overview
            case .findings: findings
            case .files: files
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: AuditReportDocument(report: report),
            contentType: .json,
            defaultFilename: "\(report.metadata.name)-audit.json"
        ) { _ in }
    }

    private var overview: some View {
        Form {
            Section("Identity") {
                LabeledContent("Name", value: report.metadata.name)
                LabeledContent("Bundle ID", value: report.metadata.bundleIdentifier)
                LabeledContent("Version", value: "\(report.metadata.version) (\(report.metadata.build))")
                if let minimum = report.metadata.minimumOSVersion { LabeledContent("Minimum OS", value: minimum) }
            }
            Section("Contents") {
                LabeledContent("Installed size", value: ByteCountFormatter.string(fromByteCount: report.totalBytes, countStyle: .file))
                LabeledContent("Frameworks", value: report.frameworks.count.formatted())
                LabeledContent("Extensions", value: report.extensions.count.formatted())
                LabeledContent("Localizations", value: report.localizations.formatted())
                LabeledContent("Privacy manifest", value: report.hasPrivacyManifest ? "Present" : "Not found")
                LabeledContent("Architectures", value: report.architectures.formatted())
            }
            if let signing = report.signing {
                Section("Signing") {
                    if let team = signing.teamIdentifier { LabeledContent("Team", value: team) }
                    if let appID = signing.applicationIdentifier { LabeledContent("Application ID", value: appID) }
                    if let expiration = signing.expirationDate { LabeledContent("Expires", value: expiration.formatted(date: .abbreviated, time: .omitted)) }
                    LabeledContent("Entitlements", value: signing.entitlements.count.formatted())
                }
            }
        }
        .formStyle(.grouped)
    }

    private var findings: some View {
        List(report.findings) { finding in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol(for: finding.severity))
                    .foregroundStyle(color(for: finding.severity))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(finding.title).font(.headline)
                    Text(finding.detail).foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .overlay {
            if report.findings.isEmpty {
                ContentUnavailableView("No findings", systemImage: "checkmark.seal", description: Text("No issues were detected by the current audit rules."))
            }
        }
    }

    private var files: some View {
        Table(report.files.filter { !$0.isDirectory }) {
            TableColumn("Path", value: \.path)
            TableColumn("Size") { entry in
                Text(ByteCountFormatter.string(fromByteCount: entry.bytes, countStyle: .file)).monospacedDigit()
            }.width(min: 80, ideal: 100)
        }
    }

    private func symbol(for severity: IPAFindingSeverity) -> String {
        switch severity { case .info: "info.circle"; case .warning: "exclamationmark.triangle"; case .error: "xmark.octagon" }
    }

    private func color(for severity: IPAFindingSeverity) -> Color {
        switch severity { case .info: .blue; case .warning: .orange; case .error: .red }
    }
}

private struct AuditReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let report: IPAAuditReport

    init(report: IPAAuditReport) { self.report = report }

    init(configuration: ReadConfiguration) throws {
        report = try JSONDecoder().decode(IPAAuditReport.self, from: configuration.file.regularFileContents ?? Data())
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return FileWrapper(regularFileWithContents: try encoder.encode(report))
    }
}
