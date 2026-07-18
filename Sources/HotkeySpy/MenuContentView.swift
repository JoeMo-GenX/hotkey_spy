import SwiftUI
import HotkeySpyCore

struct MenuContentView: View {
    @EnvironmentObject var log: EventLog
    @EnvironmentObject var permissions: PermissionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusLine
            Divider()
            if log.events.isEmpty {
                Text("No modifier-combo key presses yet.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(log.events) { event in
                            EventRow(event: event)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
            Divider()
            HStack {
                Button("Clear log") { log.clear() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 340)
    }

    @ViewBuilder private var statusLine: some View {
        if permissions.isTrusted {
            Label("Monitoring", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("Needs Accessibility permission", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("Grant Accessibility…") {
                    permissions.promptIfNeeded()
                    permissions.openSettings()
                }
            }
        }
    }
}

private struct EventRow: View {
    let event: KeyEvent

    var body: some View {
        HStack(spacing: 8) {
            Text(event.combo)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 60, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.source.label)
                    .foregroundStyle(event.source.isSuspicious ? .red : .primary)
                if let front = event.frontmostApp {
                    Text("front: \(front)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(event.timestamp, style: .time)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
