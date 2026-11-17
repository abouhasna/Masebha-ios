import SwiftUI
import UniformTypeIdentifiers
import Observation

/// Settings → Backup (≈ the Android "Backup" category): export to a file through the share sheet,
/// import from a file after a confirmation. Free for everyone.
@Observable
final class BackupFlow {
    var isPickingFile = false
    var shareFile: ShareFile?
    /// A checked file waiting for the user's confirmation.
    var pendingImport: BackupFile?
    var message: String?

    func export(_ environment: AppEnvironment) {
        do {
            shareFile = ShareFile(url: try environment.exportBackup())
        } catch {
            message = tr("backup.export.failed")
        }
    }

    /// The file picker's result: read and check the whole file, then ask for confirmation.
    func picked(_ result: Result<URL, Error>, environment: AppEnvironment) {
        switch result {
        case .success(let url):
            do {
                pendingImport = try environment.readBackup(at: url)
            } catch {
                message = tr("backup.import.invalid")
            }
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled {
                message = tr("backup.import.failed")
            }
        }
    }

    func confirmImport(_ file: BackupFile, environment: AppEnvironment) {
        do {
            try environment.importBackup(file)
            message = tr("backup.import.success")
        } catch {
            message = tr("backup.import.failed")   // the database part rolled back: nothing changed
        }
    }
}

struct ShareFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// The two rows of the Backup section.
struct BackupSection: View {
    let flow: BackupFlow
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Section {
            Button {
                flow.export(environment)
            } label: {
                SettingsRowLabel(icon: "square.and.arrow.up", title: tr("settings.export"),
                                 subtitle: tr("settings.export.summary"))
            }
            .settingsRowBackground()
            .accessibilityIdentifier("settings.export")
            Button {
                flow.isPickingFile = true
            } label: {
                SettingsRowLabel(icon: "square.and.arrow.down", title: tr("settings.import"),
                                 subtitle: tr("settings.import.summary"))
            }
            .settingsRowBackground()
            .accessibilityIdentifier("settings.import")
        } header: {
            Text(tr("settings.section.backup"))
                .appFont(15, .bold)
                .foregroundStyle(.white)
                .textCase(nil)
        }
    }
}

/// The file picker, the share sheet and the alerts of the Backup section (attached to the whole
/// Settings list, which is always on screen).
struct BackupPresentation: ViewModifier {
    @Bindable var flow: BackupFlow
    @Environment(AppEnvironment.self) private var environment

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $flow.isPickingFile, allowedContentTypes: [.json, .data]) { result in
                flow.picked(result, environment: environment)
            }
            .sheet(item: $flow.shareFile) { file in
                ShareSheet(url: file.url)
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
            .alert(tr("settings.import"), isPresented: isPresented($flow.pendingImport),
                   presenting: flow.pendingImport) { file in
                Button(tr("backup.import.button"), role: .destructive) {
                    flow.confirmImport(file, environment: environment)
                }
                .accessibilityIdentifier("backup.confirmImport")
                Button(tr("common.cancel"), role: .cancel) {}
            } message: { _ in
                Text(tr("backup.import.confirm"))
            }
            .alert(tr("settings.section.backup"), isPresented: isPresented($flow.message)) {
                Button(tr("common.ok"), role: .cancel) {}
            } message: {
                Text(flow.message ?? "")
                    .accessibilityIdentifier("backup.message")
            }
    }
}

/// The system share sheet (AirDrop, Files, messengers…), like Android's share intent.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
