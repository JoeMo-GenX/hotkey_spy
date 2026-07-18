import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch HotkeySpy at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        launchAtLogin = LaunchAtLogin.setEnabled(newValue)
                    }
                Text("For reliable startup, move HotkeySpy to your Applications folder. "
                     + "On unsigned builds the login item may not persist until the app is signed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Show a popup for each detected combo", isOn: $settings.notificationsEnabled)
            }

            Section("Log") {
                Stepper("Keep last \(settings.maxLogEntries) events",
                        value: $settings.maxLogEntries, in: 25...500, step: 25)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 320)
        .navigationTitle("HotkeySpy Settings")
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}
