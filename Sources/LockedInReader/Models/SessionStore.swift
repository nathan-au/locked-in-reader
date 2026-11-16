import Foundation
import CryptoKit

/// A reading session that is currently in progress. Persisted to disk so that
/// relaunching the app (or killing it) drops you straight back into the lock.
struct ActiveSession: Codable {
    var pdfPath: String
    var startDate: Date
    var endDate: Date
    var passphraseSalt: String
    var passphraseHash: String

    var pdfURL: URL { URL(fileURLWithPath: pdfPath) }
    var isExpired: Bool { endDate <= Date() }
}

enum PassphraseHasher {
    static func makeSalt() -> String {
        (0..<16).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
    }

    static func hash(_ passphrase: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + passphrase).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func matches(_ attempt: String, salt: String, hash expected: String) -> Bool {
        hash(attempt, salt: salt) == expected
    }
}

/// Reads and writes the active session and per-PDF reading progress.
enum SessionStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("LockedInReader", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var sessionFile: URL { directory.appendingPathComponent("session.json") }

    static func loadActive() -> ActiveSession? {
        guard let data = try? Data(contentsOf: sessionFile),
              let session = try? JSONDecoder().decode(ActiveSession.self, from: data)
        else { return nil }
        return session
    }

    static func saveActive(_ session: ActiveSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: sessionFile, options: .atomic)
    }

    static func clearActive() {
        try? FileManager.default.removeItem(at: sessionFile)
    }

    // MARK: Last-read page per PDF

    private static let progressKey = "lastPageByPath"

    static func lastPage(for url: URL) -> Int {
        let map = UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int]
        return map?[url.path] ?? 0
    }

    static func saveLastPage(_ page: Int, for url: URL) {
        var map = (UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int]) ?? [:]
        map[url.path] = page
        UserDefaults.standard.set(map, forKey: progressKey)
    }
}
