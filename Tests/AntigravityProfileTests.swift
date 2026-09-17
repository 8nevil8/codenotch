import XCTest
@testable import Codenotch

final class AntigravityProfileTests: XCTestCase {
    private func home(_ layout: [String: [String]] = [:]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AntigravityProfileTests.\(UUID().uuidString)")
        let geminiDir = root.appendingPathComponent(".gemini")
        try FileManager.default.createDirectory(at: geminiDir, withIntermediateDirectories: true)
        for (directory, files) in layout {
            let url = geminiDir.appendingPathComponent(directory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            for file in files {
                let path = url.appendingPathComponent(file)
                try FileManager.default.createDirectory(at: path.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try Data().write(to: path)
            }
        }
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    // MARK: - Identity & Paths

    func testDefaultIdentityAndPathsStayCompatible() {
        let profile = AntigravityProfile.default(home: URL(fileURLWithPath: "/Users/test"))
        XCTAssertNil(profile.slug)
        XCTAssertEqual(profile.id, "gemini")
        XCTAssertEqual(profile.displayName, "Antigravity")
        XCTAssertEqual(profile.configDirectory.path, "/Users/test/.gemini/antigravity")
        XCTAssertEqual(profile.authURL.path, "/Users/test/.gemini/antigravity/oauth_creds.json")
        XCTAssertEqual(profile.brainDirectory.path, "/Users/test/.gemini/antigravity/brain")
        XCTAssertEqual(profile.keychainService, "gemini")
        XCTAssertEqual(profile.keychainAccount, "antigravity")
        XCTAssertEqual(profile.sourceName, "Antigravity")
        XCTAssertEqual(AntigravityProvider(profile: profile).signInRoute,
                       .openApp(bundleID: "com.google.antigravity", name: "Antigravity"))
    }

    func testNamedProfileIdentityAndPaths() {
        let home = URL(fileURLWithPath: "/Users/test")
        let dir = home.appendingPathComponent(".gemini/antigravity-work")
        let profile = AntigravityProfile(slug: "work", configDirectory: dir)
        XCTAssertEqual(profile.slug, "work")
        XCTAssertEqual(profile.id, "gemini-work")
        XCTAssertEqual(profile.displayName, "Antigravity (work)")
        XCTAssertEqual(profile.authURL.path, "/Users/test/.gemini/antigravity-work/oauth_creds.json")
        XCTAssertEqual(profile.brainDirectory.path, "/Users/test/.gemini/antigravity-work/brain")
        XCTAssertEqual(profile.keychainService, "gemini")
        XCTAssertEqual(profile.keychainAccount, "antigravity-work")
        XCTAssertEqual(profile.sourceName, "Antigravity in \(profile.displayPath)")
        XCTAssertEqual(AntigravityProvider(profile: profile).signInRoute,
                       .guidance("Sign in to Antigravity in \(profile.displayPath) to read your usage."))
    }

    func testProviderIDsAreRecognised() {
        XCTAssertTrue(AntigravityProfile.isAntigravity(providerID: "gemini"))
        XCTAssertTrue(AntigravityProfile.isAntigravity(providerID: "gemini-work"))
        XCTAssertTrue(AntigravityProfile.isAntigravity(providerID: "gemini-alpha"))
        XCTAssertFalse(AntigravityProfile.isAntigravity(providerID: "geminiapi"))
        XCTAssertFalse(AntigravityProfile.isAntigravity(providerID: "claude"))
        XCTAssertFalse(AntigravityProfile.isAntigravity(providerID: "cursor"))

        XCTAssertEqual(AntigravityProfile.slug(fromProviderID: "gemini-work"), "work")
        XCTAssertEqual(AntigravityProfile.slug(fromProviderID: "gemini-client-a"), "client-a")
        XCTAssertNil(AntigravityProfile.slug(fromProviderID: "gemini"))
        XCTAssertNil(AntigravityProfile.slug(fromProviderID: "gemini-"))
        XCTAssertNil(AntigravityProfile.slug(fromProviderID: "cursor"))
    }

    func testDirectorySlugsIgnoreInternalFlavours() {
        XCTAssertEqual(AntigravityProfile.slug(fromDirectoryName: "antigravity-work"), "work")
        XCTAssertEqual(AntigravityProfile.slug(fromDirectoryName: "antigravity-client-1"), "client-1")
        XCTAssertNil(AntigravityProfile.slug(fromDirectoryName: "antigravity"), "default has no slug")
        XCTAssertNil(AntigravityProfile.slug(fromDirectoryName: "antigravity-"), "empty slug")
        XCTAssertNil(AntigravityProfile.slug(fromDirectoryName: "antigravity-ide"), "ide is internal flavour")
        XCTAssertNil(AntigravityProfile.slug(fromDirectoryName: "antigravity-cli"), "cli is internal flavour")
        XCTAssertNil(AntigravityProfile.slug(fromDirectoryName: "antigravity-backup"), "backup is internal flavour")
        XCTAssertNil(AntigravityProfile.slug(fromDirectoryName: "not-antigravity-work"))
    }

    // MARK: - Discovery

    func testDiscoveryFindsProfilesInStableOrder() throws {
        let root = try home([
            "antigravity": ["oauth_creds.json"],
            "antigravity-work": ["oauth_creds.json"],
            "antigravity-alpha": ["brain/uuid/.system_generated/logs/transcript.jsonl"],
            "antigravity-ide": ["oauth_creds.json"],
            "antigravity-cli": ["oauth_creds.json"],
            "antigravity-backup": ["agent.db"],
            "antigravity-empty": [],
            "other-tool": ["oauth_creds.json"]
        ])

        let found = AntigravityProfile.discover(home: root)
        XCTAssertEqual(found.map(\.id), ["gemini", "gemini-alpha", "gemini-work"])
        XCTAssertEqual(found.map(\.displayName), ["Antigravity", "Antigravity (alpha)", "Antigravity (work)"])
        XCTAssertEqual(found[0].configDirectory, root.appendingPathComponent(".gemini/antigravity"))
        XCTAssertEqual(found[1].configDirectory, root.appendingPathComponent(".gemini/antigravity-alpha"))
        XCTAssertEqual(found[2].configDirectory, root.appendingPathComponent(".gemini/antigravity-work"))
    }

    func testDiscoveryRespectsCredentialFilter() throws {
        let root = try home([
            "antigravity-work": ["oauth_creds.json"],
            "antigravity-test": ["settings.json"]
        ])

        let found = AntigravityProfile.discover(home: root) { profile in
            profile.slug != "test"
        }
        XCTAssertEqual(found.map(\.id), ["gemini", "gemini-work"])
    }

    // MARK: - Activity Monitor Roots

    @MainActor
    func testActivityMonitorRoots() {
        let defaultProfile = AntigravityProfile.default(home: URL(fileURLWithPath: "/Users/test"))
        let workProfile = AntigravityProfile(slug: "work",
                                             configDirectory: URL(fileURLWithPath: "/Users/test/.gemini/antigravity-work"))

        let defaultMonitor = AntigravityActivityMonitor(profile: defaultProfile)
        XCTAssertNotNil(defaultMonitor)

        let workMonitor = AntigravityActivityMonitor(profile: workProfile)
        XCTAssertNotNil(workMonitor)
    }

    // MARK: - Account Details and Isolation

    func testAccountResolutionFromOAuthCreds() throws {
        let root = try home([
            "antigravity": [],
            "antigravity-work": []
        ])
        let workProfile = AntigravityProfile(slug: "work", configDirectory: root.appendingPathComponent(".gemini/antigravity-work"))

        let credsJSON = """
        {
            "access_token": "ya29.work-test-token",
            "expiry_date": 1893456000000,
            "email": "work@example.com",
            "project_id": "work-project"
        }
        """
        try credsJSON.data(using: .utf8)!.write(to: workProfile.authURL)

        XCTAssertTrue(AntigravityCredentials.isSignedIn(for: workProfile))
        let loaded = try AntigravityCredentials.load(for: workProfile)
        XCTAssertEqual(loaded.accessToken, "ya29.work-test-token")
        XCTAssertEqual(loaded.email, "work@example.com")
        XCTAssertEqual(loaded.projectId, "work-project")

        let provider = AntigravityProvider(profile: workProfile)
        let account = provider.account()
        XCTAssertEqual(account?.label, "work@example.com")
        XCTAssertEqual(account?.plan, "Personal")
        XCTAssertTrue(account?.source.contains("antigravity-work") ?? false)

        AntigravityCredentials.forgetCached(for: workProfile)
        XCTAssertNil(AntigravityCredentials.held(for: workProfile))
    }
}
