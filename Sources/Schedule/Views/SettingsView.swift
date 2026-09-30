import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Habit.sortIndex)]) private var habits: [Habit]

    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private let expiry = BuildExpiry.current()

    var body: some View {
        List {
            Section("Appearance") {
                Picker("Theme", selection: $theme) {
                    ForEach(AppTheme.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("Reminders") {
                LabeledContent("Notifications", value: notificationStatusText)
                switch notificationStatus {
                case .notDetermined:
                    Button("Allow notifications") {
                        Task {
                            await NotificationService.shared.requestAuthorization()
                            await refreshStatus()
                            await NotificationService.shared.refreshAll(for: habits)
                        }
                    }
                case .denied:
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                default:
                    Button("Rebuild reminders") {
                        Task { await NotificationService.shared.refreshAll(for: habits) }
                    }
                }
            }

            buildSection

            Section {
                Button("Export backup") { export() }
                if let exportError {
                    Text(exportError).font(.caption).foregroundStyle(.red)
                }
            } footer: {
                Text("A JSON file with every habit and tick. Re-installing keeps your data, but a backup is worth having.")
            }

            Section("About") {
                LabeledContent("Version", value: versionString)
                LabeledContent("Habits", value: "\(habits.count)")
                LabeledContent("Ticks", value: "\(habits.reduce(0) { $0 + $1.checkIns.count })")
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task { await refreshStatus() }
        .sheet(item: $exportFile) { file in
            ShareSheet(url: file.url)
        }
    }

    /// Surfaces the free-team 7-day signature clock, so a build about to die is
    /// visible before it stops launching.
    @ViewBuilder
    private var buildSection: some View {
        if let expiry {
            let days = expiry.daysRemaining()
            Section {
                LabeledContent("Signature expires") {
                    Text(expiry.expirationDate, format: .dateTime.day().month().year())
                }
                LabeledContent("Days left") {
                    Text("\(days)")
                        .monospacedDigit()
                        .foregroundStyle(days <= 2 ? .red : (days <= 4 ? .orange : .secondary))
                }
            } header: {
                Text("This build")
            } footer: {
                Text(days <= 2
                     ? "This build stops launching soon. Run scripts/resign.sh on your Mac, or wait for the daily job to reinstall it."
                     : "Free Apple ID builds are signed for 7 days. The launchd job on your Mac reinstalls it over Wi-Fi before this runs out.")
            }
        }
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized: "On"
        case .denied: "Off"
        case .provisional: "Quiet"
        case .ephemeral: "Temporary"
        default: "Not asked"
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func refreshStatus() async {
        notificationStatus = await NotificationService.shared.authorizationStatus()
    }

    private func export() {
        exportError = nil
        do {
            exportFile = ExportFile(url: try ExportService.writeTemporaryFile(habits: habits))
        } catch {
            exportError = "Could not create the backup: \(error.localizedDescription)"
        }
    }
}

/// `UIActivityViewController` wrapper — `ShareLink` cannot share a file URL
/// that is created on demand.
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Wrapper so the share sheet can be driven by `sheet(item:)` without
/// retroactively conforming `URL` to `Identifiable`.
private struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
