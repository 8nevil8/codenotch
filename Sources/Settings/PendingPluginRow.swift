import AppKit
import SwiftUI

/// A plugin that asked to run but has not been approved. Shows exactly what
/// would execute — path, arguments, and the SHA-256 the approval will pin —
/// because "Enable" is a trust decision, not a toggle.
struct PendingPluginRow: View {
    let plugin: PluginCoordinator.PendingPlugin
    let approve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                ProviderGlyphView(glyph: .external, size: 16, providerID: plugin.id)
                    .foregroundStyle(.tertiary)
                Text(plugin.displayName)
                    .foregroundStyle(.secondary)
                PluginBadge()
                Spacer(minLength: 8)
                Button(L10n.t("Enable…"), action: approve)
                    .controlSize(.small)
                    .help(L10n.t("Trust this exact build of the plugin and connect it. Any change to its manifest or executable asks again."))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.commandLine)
                    .textSelection(.enabled)
                HStack(spacing: 6) {
                    Text("SHA-256 \(plugin.shortHash)…")
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(plugin.contentHash, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(SettingsIconButtonStyle())
                    .help(L10n.t("Copy the full hash."))
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.leading, 48)
        }
    }
}
