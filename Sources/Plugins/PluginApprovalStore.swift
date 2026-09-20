import Foundation

/// Where the pinned plugin approvals live.
///
/// Not in UserDefaults. The preferences plist is writable by any process
/// running as the user — the same adversary that can drop a manifest into the
/// plugins folder — so an approval kept there is forgeable with one
/// `defaults write`, and the consent step it exists to enforce could be
/// skipped end to end. The keychain item is ACL'd to this app's signing
/// identity: another process can list its attributes, and can even file a
/// second item under the same name, but cannot read or write *ours* without
/// macOS putting up a dialogue that names Codenotch.
protocol PluginApprovalStore: AnyObject {
    /// Plugin id → the approved content hash. Empty when nothing is approved,
    /// and empty — fail closed — whenever the store cannot vouch for what it
    /// finds.
    func load() -> [String: String]
    func save(_ approvals: [String: String])
}

/// Approvals that live and die with the process: tests, and the demo mode.
final class EphemeralPluginApprovalStore: PluginApprovalStore {
    private var approvals: [String: String]

    init(_ approvals: [String: String] = [:]) {
        self.approvals = approvals
    }

    func load() -> [String: String] { approvals }
    func save(_ approvals: [String: String]) { self.approvals = approvals }
}

/// The real store: one generic-password item holding the approvals as JSON.
final class KeychainPluginApprovalStore: PluginApprovalStore {
    static let service = "codenotch-plugin-approvals"
    static let account = "approvals"

    func load() -> [String: String] {
        // Two items under our name means something other than this app filed
        // one, and "the newest" could be the impostor's. Nothing is approved
        // until the duplicate is gone — a re-pend, never a bypass.
        let matches = KeychainItem.matches(service: Self.service, account: Self.account)
        guard matches.count <= 1 else {
            Log.usage.error("plugin approvals: \(matches.count) keychain items under one name, refusing all")
            return [:]
        }
        guard let text = KeychainItem.read(service: Self.service, account: Self.account) else { return [:] }
        return Self.decode(text)
    }

    func save(_ approvals: [String: String]) {
        guard KeychainItem.matches(service: Self.service, account: Self.account).count <= 1 else {
            Log.usage.error("plugin approvals: duplicate keychain items, not saving")
            return
        }
        if approvals.isEmpty {
            KeychainItem.delete(service: Self.service, account: Self.account)
            return
        }
        guard let text = Self.encode(approvals),
              KeychainItem.store(service: Self.service, account: Self.account, value: text)
        else {
            Log.usage.error("plugin approvals: keychain write failed")
            return
        }
    }

    /// The wire form, split out so the codec is testable without a keychain.
    static func encode(_ approvals: [String: String]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(approvals)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Anything that is not a flat `{id: hash}` object is treated as no
    /// approvals at all.
    static func decode(_ text: String) -> [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(text.utf8))) ?? [:]
    }
}
