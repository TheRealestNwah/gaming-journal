import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Backup, export and app info.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var sessions: [PlaySession]
    @State private var exportDocument: ExportDocument?
    @State private var isImporting = false
    @State private var message: Message?

    private struct Message: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Export Backup (JSON)", systemImage: "square.and.arrow.up") { exportJSON() }
                    Button("Export Spreadsheet (CSV)", systemImage: "tablecells") { exportCSV() }
                    Button("Import Backup", systemImage: "square.and.arrow.down") { isImporting = true }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("A JSON backup holds every session and photo. Importing merges by session, so nothing is duplicated. CSV is for spreadsheets and leaves out photos.")
                }

                Section("About") {
                    LabeledContent("Sessions", value: "\(sessions.count)")
                    LabeledContent("Version", value: Self.appVersion)
                }
            }
            .navigationTitle("Settings")
            .fileExporter(
                isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
                document: exportDocument,
                contentType: exportDocument?.contentType ?? .json,
                defaultFilename: exportDocument?.filename
            ) { result in
                if case .failure(let error) = result {
                    message = Message(title: "Export failed", body: error.localizedDescription)
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url): importBackup(from: url)
                case .failure(let error): message = Message(title: "Import failed", body: error.localizedDescription)
                }
            }
            .alert(item: $message) { message in
                Alert(title: Text(message.title), message: Text(message.body))
            }
        }
        .sessionOverlays()
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private static func filename(_ suffix: String) -> String {
        "GamingJournal-\(Date.now.formatted(.iso8601.year().month().day()))\(suffix)"
    }

    private func exportJSON() {
        do {
            let data = try JournalBackup(exporting: sessions).encoded()
            exportDocument = ExportDocument(data: data, contentType: .json, filename: Self.filename(""))
        } catch {
            message = Message(title: "Export failed", body: error.localizedDescription)
        }
    }

    private func exportCSV() {
        let csv = SessionCSV.export(sessions.map(JournalBackup.Session.init(session:)))
        exportDocument = ExportDocument(data: Data(csv.utf8), contentType: .commaSeparatedText, filename: Self.filename(""))
    }

    private func importBackup(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let backup = try JournalBackup.decode(Data(contentsOf: url))
            let plan = backup.mergePlan(existingIDs: Set(sessions.map(\.id)))
            for session in plan.newSessions {
                context.insert(session.makeSession())
            }
            try context.save()
            message = Message(
                title: "Import complete",
                body: "Added \(plan.newSessions.count) session\(plan.newSessions.count == 1 ? "" : "s")."
                    + (plan.skippedCount > 0 ? " Skipped \(plan.skippedCount) already in your journal." : "")
            )
        } catch {
            message = Message(title: "Import failed", body: error.localizedDescription)
        }
    }
}

/// Bytes handed to the system file exporter.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }

    var data: Data
    var contentType: UTType
    var filename: String

    init(data: Data, contentType: UTType, filename: String) {
        self.data = data
        self.contentType = contentType
        self.filename = filename
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        contentType = configuration.contentType
        filename = configuration.file.filename ?? "GamingJournal"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
