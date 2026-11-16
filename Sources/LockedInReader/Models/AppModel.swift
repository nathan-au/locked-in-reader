import Foundation
import Combine

struct SessionSummary {
    enum Outcome { case completed, exitedEarly }
    var outcome: Outcome
    var pdfName: String
    var elapsed: TimeInterval
    var pagesVisited: Int
    var totalPages: Int
}

/// Single source of truth for the app: which screen we're on, the running
/// timer, and the passphrase/escape-hatch state.
@MainActor
final class AppModel: ObservableObject {
    enum Phase { case setup, reading, done }

    // Setup inputs
    @Published var pdfURL: URL?
    @Published var durationMinutes = 45
    @Published var passphrase = ""

    // Runtime state
    @Published private(set) var phase: Phase = .setup
    @Published private(set) var remaining: TimeInterval = 0
    @Published var showUnlockPrompt = false
    @Published private(set) var summary: SessionSummary?

    private(set) var session: ActiveSession?
    private var visitedPages = Set<Int>()
    private var totalPages = 0
    private var currentPage = 0
    private var ticker: Timer?

    static let minPassphraseLength = 12

    var canStart: Bool {
        pdfURL != nil && durationMinutes > 0 && passphrase.count >= Self.minPassphraseLength
    }

    var startPage: Int {
        guard let url = session?.pdfURL else { return 0 }
        return SessionStore.lastPage(for: url)
    }

    // MARK: Lifecycle

    /// Resume a persisted session if one is still running; discard it if it has expired.
    func restoreIfNeeded() {
        guard let saved = SessionStore.loadActive() else { return }
        if saved.isExpired || !FileManager.default.fileExists(atPath: saved.pdfPath) {
            SessionStore.clearActive()
            return
        }
        session = saved
        beginReading()
    }

    func startSession() {
        guard canStart, let url = pdfURL else { return }
        let salt = PassphraseHasher.makeSalt()
        let now = Date()
        let new = ActiveSession(
            pdfPath: url.path,
            startDate: now,
            endDate: now.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            passphraseSalt: salt,
            passphraseHash: PassphraseHasher.hash(passphrase, salt: salt)
        )
        SessionStore.saveActive(new)
        session = new
        passphrase = ""
        beginReading()
    }

    private func beginReading() {
        visitedPages = []
        showUnlockPrompt = false
        summary = nil
        phase = .reading
        tick()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let session else { return }
        remaining = max(0, session.endDate.timeIntervalSinceNow)
        if remaining <= 0 { finish(.completed) }
    }

    /// Checks the emergency passphrase. Returns true and ends the session if it matches.
    func tryEmergencyExit(with attempt: String) -> Bool {
        guard let session,
              PassphraseHasher.matches(attempt, salt: session.passphraseSalt, hash: session.passphraseHash)
        else { return false }
        finish(.exitedEarly)
        return true
    }

    private func finish(_ outcome: SessionSummary.Outcome) {
        guard phase == .reading, let session else { return }
        ticker?.invalidate()
        ticker = nil
        SessionStore.saveLastPage(currentPage, for: session.pdfURL)
        SessionStore.clearActive()
        summary = SessionSummary(
            outcome: outcome,
            pdfName: session.pdfURL.lastPathComponent,
            elapsed: min(Date().timeIntervalSince(session.startDate), session.endDate.timeIntervalSince(session.startDate)),
            pagesVisited: visitedPages.count,
            totalPages: totalPages
        )
        self.session = nil
        showUnlockPrompt = false
        phase = .done
    }

    func newSession() {
        summary = nil
        phase = .setup
    }

    // MARK: Reader callbacks

    func documentLoaded(pageCount: Int) {
        totalPages = pageCount
    }

    func pageChanged(to index: Int) {
        currentPage = index
        visitedPages.insert(index)
        if let url = session?.pdfURL { SessionStore.saveLastPage(index, for: url) }
    }
}
