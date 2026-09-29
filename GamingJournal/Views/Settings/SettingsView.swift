import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Backup, export and app info.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var sessions: [PlaySession]
    @Query private var notebooks: [Notebook]
    @State private var exportDocument: ExportDocument?
    @State private var isImporting = false
    @State private var message: Message?
    @AppStorage(SyncSettings.enabledKey) private var syncEnabled = false
    @AppStorage(WritingPrompts.enabledKey) private var promptsEnabled = true
    /// Sync state the store was opened with at launch.
    @State private var syncAtLaunch = SyncSettings().isEnabled
    @State private var syncFellBack = SyncSettings().lastLaunchFellBack

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
                    Text("A JSON backup holds every notebook, entry, session and photo. Importing only adds what's missing, so nothing is duplicated. CSV lists play sessions for spreadsheets.")
                }
                .listRowBackground(Theme.vellum)

                Section {
                    Toggle("Writing prompts", systemImage: "flame", isOn: $promptsEnabled)
                } header: {
                    Text("Writing")
                } footer: {
                    Text("Suggest an in-character question when you start a new entry.")
                }
                .listRowBackground(Theme.vellum)

                Section {
                    Toggle("iCloud Sync", systemImage: "icloud", isOn: $syncEnabled)
                } header: {
                    Text("Sync")
                } footer: {
                    Text(syncFooter)
                }
                .listRowBackground(Theme.vellum)

                Section("About") {
                    LabeledContent("Notebooks", value: "\(notebooks.count)")
                    LabeledContent("Sessions", value: "\(sessions.count)")
                    LabeledContent("Version", value: Self.appVersion)
                }
                .listRowBackground(Theme.vellum)
            }
            .parchmentBackground()
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

    private var syncFooter: String {
        if syncEnabled != syncAtLaunch {
            return "Quit and reopen Gaming Journal to \(syncEnabled ? "start" : "stop") syncing."
        }
        if syncEnabled && syncFellBack {
            return "iCloud isn't available right now (check you're signed in to iCloud), so your journal is only on this device."
        }
        return syncEnabled
            ? "Your journal syncs across devices signed in to the same iCloud account."
            : "Keep your journal in step across your devices using your iCloud account."
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
            let data = try JournalBackup(exporting: sessions, notebooks: notebooks).encoded()
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
            let report = try JournalImporter.importBackup(backup, into: context)
            message = Message(title: "Import complete", body: report.summary)
        } catch {
            message = Message(title: "Import failed", body: error.localizedDescription)
        }
    }
}

/// Bytes handed to the system file exporter.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .markdownText, .plainText] }

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

extension UTType {
    /// Markdown, for exported notebook "books".
    static let markdownText = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}
